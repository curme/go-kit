export const emptyBoard = n => Array(n * n).fill(0);
export const hash = board => board.join('');
export function neighbors(i, n) {
  const x = i % n, y = Math.floor(i / n);
  return [x > 0 ? i - 1 : -1, x < n - 1 ? i + 1 : -1, y > 0 ? i - n : -1, y < n - 1 ? i + n : -1].filter(j => j >= 0);
}
export function group(board, i, n) {
  if (!board[i]) return { stones: [], liberties: [] };
  const seen = new Set([i]), liberties = new Set(), queue = [i];
  for (const p of queue) for (const q of neighbors(p, n)) {
    if (!board[q]) liberties.add(q);
    else if (board[q] === board[i] && !seen.has(q)) { seen.add(q); queue.push(q); }
  }
  return { stones: [...seen], liberties: [...liberties] };
}
// Teaching rules: no suicide, positional superko; passing is always allowed.
export function play(board, i, color, n, history = []) {
  if (!Number.isInteger(i) || i < 0 || i >= board.length) return { error: '请落在棋盘的交叉点上。' };
  if (board[i]) return { error: '这里已经有棋子了。棋子要落在空交叉点上。' };
  const next = [...board], captured = []; next[i] = color;
  for (const q of neighbors(i, n)) if (next[q] && next[q] !== color) {
    const g = group(next, q, n);
    if (!g.liberties.length) for (const s of g.stones) { next[s] = 0; captured.push(s); }
  }
  if (!group(next, i, n).liberties.length) return { error: '这手没有气，也不能提掉对方棋子，属于禁入点。' };
  if (history.includes(hash(next))) return { error: '这手会重复之前的局面。发生劫争时，要先在别处改变局面。' };
  return { board: next, captured, liberties: group(next, i, n).liberties };
}
export function area(board, n) {
  let black = board.filter(c => c === 1).length, white = board.filter(c => c === 2).length, neutral = 0;
  const territory = Array(board.length).fill(0), seen = new Set();
  board.forEach((c, i) => {
    if (c || seen.has(i)) return;
    const region = [i], boundary = new Set(); seen.add(i);
    for (const p of region) for (const q of neighbors(p, n)) {
      if (board[q]) boundary.add(board[q]);
      else if (!seen.has(q)) { seen.add(q); region.push(q); }
    }
    const owner = boundary.size === 1 ? [...boundary][0] : 0;
    region.forEach(p => territory[p] = owner);
    if (owner === 1) black += region.length; else if (owner === 2) white += region.length; else neutral += region.length;
  });
  return { black, white, neutral, territory };
}
export function chooseMove(board, color, n, history) {
  let best = null;
  const seen = new Set(), endangered = [];
  board.forEach((c, i) => { if (c === color && !seen.has(i)) { const g = group(board, i, n); g.stones.forEach(s => seen.add(s)); if (g.liberties.length === 1) endangered.push(g); } });
  board.forEach((c, i) => {
    if (c) return;
    const r = play(board, i, color, n, history); if (r.error) return;
    const adj = neighbors(i, n), friends = adj.filter(p => board[p] === color);
    // Do not fill an enclosed friendly point when it achieves nothing.
    if (adj.every(p => board[p] === color) && !r.captured.length) return;
    const rescue = endangered.filter(g => g.liberties[0] === i && r.liberties.length > 1).reduce((sum,g) => sum + g.stones.length, 0);
    const threats = new Set(); adj.forEach(p => { if (r.board[p] === 3 - color) { const g = group(r.board, p, n); if (g.liberties.length === 1) threats.add(Math.min(...g.stones)); } });
    const x = i % n, y = Math.floor(i / n), edge = Math.min(x, y, n - 1 - x, n - 1 - y);
    const distance = board.reduce((min, v, p) => v ? Math.min(min, Math.abs(p % n - x) + Math.abs(Math.floor(p / n) - y)) : min, n);
    const score = r.captured.length * 18 + rescue * 15 + threats.size * 5 + Math.min(r.liberties.length, 4) + (edge === 2 ? 3 : edge === 1 ? 1 : 0) + (distance === 2 ? 2 : 0) - (r.liberties.length === 1 ? 22 : 0) - friends.length * .7 + ((i * 17) % 13) / 100;
    if (!best || score > best.score) best = { i, score, ...r, reason: r.captured.length ? `白棋提掉了 ${r.captured.length} 颗黑子。看看刚才哪一块棋只剩最后一口气。` : rescue ? '白棋正在逃出打吃。棋只剩一口气时，先考虑延长气或提掉对方。' : threats.size ? '白棋形成了打吃。检查你的棋，找到只剩一口气的那一块。' : '白棋在拓展空间。轮到你：先检查双方的气，再考虑连接和围地。' };
  });
  return best && best.score > -5 ? best : null;
}
