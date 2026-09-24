import { emptyBoard, hash, group, play, chooseMove, area } from './go.js';
import { lessons } from './lessons.js';

const $ = document.querySelector('#app');
const icons = {
  book: '<path d="M4 4h6a3 3 0 0 1 3 3v14a4 4 0 0 0-4-3H4zM20 4h-4a3 3 0 0 0-3 3v14a4 4 0 0 1 4-3h3z"/>',
  board: '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 10h16M4 15h16M10 4v16M15 4v16"/>',
  repeat: '<path d="M20 8a8 8 0 1 0 0 8M20 3v5h-5"/>',
  arrow: '<path d="M5 12h14m-6-6 6 6-6 6"/>',
  spark: '<path d="m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5z"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  bulb: '<path d="M9 18h6m-5 3h4M8 14a6 6 0 1 1 8 0l-1 2H9z"/>',
  leaf: '<path d="M5 19C2 8 9 4 21 3c0 11-6 16-13 13M5 21 16 10"/>',
};
const icon = name => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.spark}</svg>`;
const esc = text => String(text).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let saved = {};
try { saved = JSON.parse(localStorage.getItem('first-stone-v1') || '{}') || {}; } catch {}
const ids = a => Array.isArray(a) ? [...new Set(a.filter(i => Number.isInteger(i) && i >= 0 && i < lessons.length))] : [];
const progress = { done: ids(saved.done), mistakes: ids(saved.mistakes), last: Number.isInteger(saved.last) && lessons[saved.last] ? saved.last : 0 };
let mode = 'learn', lessonIndex = progress.last, board, selected = [], solved = false, hint = false, feedback = '', feedbackKind = '', inspect = null, showLiberties = false, chosenAnswer = null;
let game = null, botTimer = null, storageAvailable = true;
function persist() { try { localStorage.setItem('first-stone-v1', JSON.stringify(progress)); } catch { storageAvailable = false; } }
function loadLesson(i) { lessonIndex = i; progress.last = i; board = [...lessons[i].board]; selected = []; solved = false; hint = false; feedback = ''; feedbackKind = ''; inspect = null; chosenAnswer = null; persist(); }
loadLesson(lessonIndex);
function newGame() { clearTimeout(botTimer); game = { board: emptyBoard(9), history: [hash(emptyBoard(9))], moves: [], snapshots: [], captured: [0,0], passes: 0, thinking: false, ended: false, estimate: false, message: '你执黑，先行。先在三线附近试着落子，给棋子留出发展的空间。' }; inspect = null; }
function coordinate(i, n) { return 'ABCDEFGHJ'[i % n] + (n - Math.floor(i/n)); }
function boardHTML(b, n) {
  const step = 440 / (n-1), pos = i => 40 + i * step;
  const lesson = lessons[lessonIndex], last = mode === 'play' ? game.moves.at(-1)?.i : selected.at(-1);
  let liberties = [];
  if (inspect !== null && b[inspect]) liberties = group(b, inspect, n).liberties;
  else if (showLiberties) { const set = new Set(); b.forEach((c,i) => { if(c === 1) group(b,i,n).liberties.forEach(p => set.add(p)); }); liberties = [...set]; }
  const hinted = mode !== 'play' && (hint || lessonIndex === 0) && !solved ? lesson.target || [] : [];
  const score = mode === 'play' && game.estimate ? area(b,n) : null;
  let svg = '';
  for (let j=0;j<n;j++) svg += `<path d="M40 ${pos(j)}H480M${pos(j)} 40V480"/>`;
  const stars = n === 9 ? [2,4,6] : [2];
  svg += stars.flatMap(y => stars.filter(x => n !== 9 || (x===4 ? y===4 : y!==4)).map(x => `<circle cx="${pos(x)}" cy="${pos(y)}" r="3" fill="#81623a" stroke="none"/>`)).join('');
  return `<div class="board-wrap"><div class="wood-board" role="group" aria-label="${n} 路棋盘，${mode === 'play' ? '你执黑' : lesson.title}">
    <svg class="grid" viewBox="0 0 520 520" fill="none" stroke="#997b4e" stroke-width="1.1" aria-hidden="true">${svg}</svg>
    ${Array.from({length:n},(_,i) => `<span class="coord col" style="left:${pos(i)/5.2}%">${'ABCDEFGHJ'[i]}</span><span class="coord row" style="top:${pos(i)/5.2}%">${n-i}</span>`).join('')}
    ${b.map((c,i) => `<button class="point ${c ? 'stone ' + (c===1 ? 'black' : 'white') : ''} ${selected.includes(i) && !c ? 'selected' : ''} ${hinted.includes(i) && !c ? 'hinted' : ''} ${liberties.includes(i) ? 'liberty' : ''} ${last === i && c ? 'last' : ''} ${score?.territory[i] ? 'territory t' + score.territory[i] : ''}" style="left:${pos(i%n)/5.2}%;top:${pos(Math.floor(i/n))/5.2}%;--stone-size:${n===9 ? 8.6 : 14}%" data-point="${i}" aria-label="${coordinate(i,n)}，${c===1?'黑子':c===2?'白子':'空点'}${liberties.includes(i)?'，气':''}" ${mode==='play' && game.thinking ? 'disabled' : ''}>${selected.includes(i) && !c ? '·' : ''}</button>`).join('')}
    </div></div>`;
}
function sidebar() {
  return `<aside class="sidebar"><a href="/" class="brand" aria-label="九三棋社首页"><span class="brand-symbol"><i></i><i></i></span><span>九三棋社<span class="brand-sub">围棋入门与陪练</span></span></a>
    <div class="side-label">你的围棋之旅</div><nav aria-label="主导航">${[['learn','book','跟着学','从零开始，步步有解'],['play','board','下一盘','九路棋盘 · 轻松练习'],['review','repeat','温故知新','把每个难点变成进步']].map(([key,ic,label,desc]) => `<button class="nav-item ${mode===key?'active':''}" data-mode="${key}">${icon(ic)}<span>${label}<small>${desc}</small></span>${mode===key?'<b>·</b>':''}</button>`).join('')}</nav>
    <div class="side-note"><span class="tiny-board">○<br>● ○</span><p>每一手，<br>都是新的开始。</p><small>不急着赢，先读懂棋盘。</small></div>
    <div class="side-footer"><span class="status-dot"></span> ${storageAvailable?'进度保存在本机浏览器':'当前浏览器无法保存进度'}</div></aside>`;
}
function header() { return `<header class="topbar"><div>学习空间 <span>/</span> ${mode==='learn'?'入门之路':mode==='play'?'九路陪练':'温故知新'}</div><div class="profile"><span>零基础，也可以下好第一手</span><div class="avatar">棋</div></div></header>`; }
function progressCard() { const pct = Math.round(progress.done.length/lessons.length*100); return `<div class="progress-card"><div class="progress-icon">${icon('leaf')}</div><div><small>我的入门之路</small><div><strong>${progress.done.length}</strong><span> / 8 课完成</span></div></div><div class="progress-ring" style="--progress:${pct}%"><span>${pct}%</span></div></div>`; }
function lessonCards() { return `<section class="curriculum"><div class="section-label"><h2>你的入门之路 <small>一课一个小进步</small></h2><span>8 节互动课 · 按自己的节奏来</span></div><div class="lesson-grid">${lessons.map((l,i)=>`<button class="lesson-card ${lessonIndex===i?'current':''} ${progress.done.includes(i)?'completed':''}" data-lesson="${i}"><span class="lesson-number">${progress.done.includes(i)?icon('check'):String(i+1).padStart(2,'0')}</span><span><strong>${l.title}</strong><small>${l.tag} · ${l.time}</small></span>${lessonIndex===i?'<i class="status-dot"></i>':''}</button>`).join('')}</div></section>`; }
function learnHTML() {
  const l = lessons[lessonIndex];
  return `<section class="hero"><div><div class="eyebrow"><span></span> LEARN GO, ONE MOVE AT A TIME</div><h1>${l.headline}</h1><p>不用背棋谱。从一颗棋子开始，一起读懂黑白之间的乐趣。</p></div>${progressCard()}</section>
    <div class="workspace"><section class="board-panel"><div class="panel-heading"><div><span class="pill">第 ${String(lessonIndex+1).padStart(2,'0')} 课</span><h2>${l.title}</h2></div><span class="muted">${l.n} 路教学棋盘</span></div>
    ${boardHTML(board,l.n)}<div class="board-caption"><span class="black-dot"></span>${l.type==='quiz'?'观察棋形，在右侧回答问题':l.type==='select'?`已找到 ${selected.length} / ${l.target.length} 口气`:'你执黑 · 点击交叉点落子'}</div>
    <div class="board-toolbar"><button data-action="reset">${icon('repeat')}重新练习</button><button class="${showLiberties?'enabled':''}" data-action="liberties">${icon('spark')}${showLiberties?'隐藏气的标记':'显示黑棋的气'}</button></div>
    </section><aside class="coach-panel"><div class="coach-heading"><span class="coach-avatar">一</span><div><strong>一手教练</strong><small>陪你理解每一步</small></div><span class="coach-badge">入门课堂</span></div>
    <div class="lesson-copy"><span class="small-label">先理解</span><h2>${l.tag}</h2><p>${l.intro}</p><div class="rule-box">${icon('bulb')}<p>${l.rule}</p></div></div>
    <div class="challenge"><span class="small-label">再试一手</span><h3>${l.task}</h3>${l.type==='quiz'?`<div class="answers">${l.options.map((o,i)=>`<button data-answer="${i}" class="${chosenAnswer===i?(solved?'correct':'incorrect'):''}" ${solved?'disabled':''}><span>${'ABC'[i]}</span>${o}</button>`).join('')}</div>`:''}
    <div class="feedback ${feedbackKind}" role="status" aria-live="polite">${feedback ? `${icon(feedbackKind==='success'?'check':'bulb')}<p>${esc(feedback)}</p>` : '<p class="quiet">慢慢来，想清楚再落子。下错也没关系。</p>'}</div>
    ${solved?`<button class="primary" data-action="next">${lessonIndex===7?'去下一盘棋':'继续下一课'}${icon('arrow')}</button>`:`<button class="hint-button" data-action="hint">${icon('bulb')}给我一点提示<span>↗</span></button>`}</div>
    <div class="coach-footer">先观察 · 再思考 · 最后落子</div></aside></div>${lessonCards()}`;
}
function playHTML() {
  if (!game) newGame();
  const score = area(game.board,9);
  return `<section class="hero"><div><div class="eyebrow"><span></span> PUT YOUR FIRST MOVES INTO PRACTICE</div><h1>小小棋盘，大有天地。</h1><p>把刚学到的用起来。你执黑，一位耐心的入门陪练执白。</p></div><span class="practice-tag">9 × 9 <small>九路练习</small></span></section>
    <div class="workspace"><section class="board-panel"><div class="panel-heading"><div><span class="pill">自由练习</span><h2>${game.ended?'本轮练习已停下':game.thinking?'白棋思考中…':'轮到你落子'}</h2></div><span class="muted">第 ${game.moves.length+1} 手 · 黑先</span></div>${boardHTML(game.board,9)}<div class="board-caption"><span class="black-dot"></span>你 · 黑棋 <span class="vs">对</span><span class="white-dot"></span>入门陪练 · 白棋</div><div class="board-toolbar"><button data-action="undo" ${!game.snapshots.length||game.thinking?'disabled':''}>${icon('repeat')}悔棋一轮</button><button data-action="liberties" class="${showLiberties?'enabled':''}">${icon('spark')}显示气</button></div></section>
    <aside class="coach-panel"><div class="coach-heading"><span class="coach-avatar">一</span><div><strong>陪练小记</strong><small>读懂棋，比赢棋更重要</small></div></div><div class="practice-body"><div class="score-row"><div><small>黑棋提子</small><strong>${game.captured[0]}</strong></div><div><small>已下手数</small><strong>${game.moves.length}</strong></div><div><small>白棋提子</small><strong>${game.captured[1]}</strong></div></div>
    <div class="game-message" role="status" aria-live="polite">${icon('bulb')}<p>${esc(game.message)}</p></div><h3>落子前的三个问题</h3><ol class="checklist"><li><span>01</span>我有没有棋被打吃？</li><li><span>02</span>对手有没有弱棋？</li><li><span>03</span>这手能连接或围地吗？</li></ol>
    <div class="play-actions">${game.ended?'<button class="primary" data-action="continue">继续下棋</button>':`<button class="primary" data-action="pass" ${game.thinking?'disabled':''}>停一手</button>`}<button class="secondary" data-action="estimate">${game.estimate?'收起估算':'看看地盘'}</button><button class="text-button" data-action="new-game">重新开局</button></div>
    ${game.estimate?`<div class="estimate"><strong>当前盘面估算</strong><p>黑 ${score.black} 点 · 白 ${score.white} + 6.5 贴目<br>未归属 ${score.neutral} 点</p><small>小方块标出围住的空点。按盘上棋子和空地粗算，未判死活，不能作为最终胜负。</small></div>`:''}
    <p class="engine-note">本地规则陪练：会提子、逃子和打吃，尚不具备职业棋力。采用禁自杀、全局同形禁止；白贴 6.5 点用于教学估算。双方连续停一手后可继续练习。</p></div></aside></div>`;
}
function reviewHTML() {
  return `<section class="hero"><div><div class="eyebrow"><span></span> A LITTLE REFLECTION, A BETTER MOVE</div><h1>走过的弯路，也算进步。</h1><p>把没弄懂的一手，再想明白。答案背后的道理更重要。</p></div>${progressCard()}</section><section class="review-section"><div class="section-label"><h2>待巩固的课程</h2><span>${progress.mistakes.length} 项</span></div>${progress.mistakes.length?`<div class="review-grid">${progress.mistakes.map(i=>`<article class="review-card"><span class="pill">第 ${i+1} 课 · 再练一次</span><h2>${lessons[i].title}</h2><p>${lessons[i].takeaway}</p><button class="secondary" data-lesson="${i}">重新挑战 ${icon('arrow')}</button></article>`).join('')}</div>`:`<div class="empty-state">${icon('leaf')}<h2>${progress.done.length?'目前没有待复习的错题':'你的每一次尝试，都会留下收获'}</h2><p>答错的课程会出现在这里，重新独立答对后移出。</p><button class="primary" data-mode="learn">${progress.done.length?'继续学习':'开始第一课'}${icon('arrow')}</button></div>`}</section><section class="review-section"><div class="section-label"><h2>随身棋理卡</h2><span>随时回来看看</span></div><div class="knowledge-grid">${lessons.map((l,i)=>`<button data-lesson="${i}"><span>${String(i+1).padStart(2,'0')}</span><div><h3>${l.title}</h3><p>${l.takeaway}</p></div></button>`).join('')}</div></section>`;
}
function render() {
  $.innerHTML = `${sidebar()}<main>${header()}<div class="main-content">${mode==='learn'?learnHTML():mode==='play'?playHTML():reviewHTML()}<footer class="page-footer"><span>九三棋社 · 让围棋成为日常的小乐趣</span><a href="https://britgo.org/intro/intro2.html" target="_blank" rel="noopener noreferrer">规则参考 ↗</a></footer></div></main>`;
  $.querySelectorAll('.nav-item').forEach(button => {
    button.setAttribute('aria-label', { learn: '跟着学', play: '下一盘', review: '温故知新' }[button.dataset.mode]);
    if (button.dataset.mode === mode) button.setAttribute('aria-current', 'page');
  });
}
function wrong(message) { if (!progress.mistakes.includes(lessonIndex)) progress.mistakes.push(lessonIndex); persist(); feedback = message; feedbackKind = 'error'; }
function complete() { solved = true; if (!progress.done.includes(lessonIndex)) progress.done.push(lessonIndex); if (!hint) progress.mistakes = progress.mistakes.filter(i=>i!==lessonIndex); persist(); feedback = lessons[lessonIndex].success; feedbackKind = 'success'; }
function handleLessonPoint(i) {
  const l = lessons[lessonIndex];
  if (solved || l.type==='quiz') { if(board[i]) inspect = inspect===i?null:i; render(); return; }
  if (l.type==='select') {
    if (l.target.includes(i)) { selected = selected.includes(i)?selected.filter(p=>p!==i):[...selected,i]; feedback = `找到了 ${selected.length} 口气。${selected.length<l.target.length?'继续找出其余的气。':''}`; feedbackKind = 'info'; if(selected.length===l.target.length) complete(); }
    else wrong(board[i]?'棋子占着的点不算气。请找与黑棋沿线相邻的空点。':'再观察一下：气要与黑子沿线直接相邻，斜着的点不算。');
  } else {
    const r = play(board,i,1,l.n);
    if (r.error) wrong(r.error);
    else if (!l.target.includes(i)) wrong('这手可以落子，但还没完成本课任务。先看目标，再找关键交叉点。');
    else { board = r.board; selected = [i]; complete(); }
  }
  render();
}
function snapshot() { return { board:[...game.board], history:[...game.history], moves:[...game.moves], captured:[...game.captured], passes:game.passes }; }
function addMove(i,color,r) {
  game.moves.push({i,color});
  if(i===null) game.passes++; else { game.board=r.board; game.history.push(hash(r.board)); game.captured[color-1]+=r.captured.length; game.passes=0; }
}
function scheduleBot() {
  game.thinking = true; render();
  botTimer = setTimeout(()=> {
    let move = chooseMove(game.board,2,9,game.history);
    // Accept the learner's pass to allow a deliberate pause and inspect the board.
    if(game.passes) move = null;
    if(move) { addMove(move.i,2,move); game.message=move.reason; }
    else { addMove(null,2); game.message='白棋停一手。你可以继续落子，也可以停一手，检查地盘和棋子的死活。'; }
    game.thinking=false;
    if(game.passes>=2) { game.ended=true; game.estimate=true; game.message='双方连续停一手，本轮练习暂停。先检查死活和边界：估算尚未去除死子，不代表正式胜负。你也可以继续下棋。'; }
    render();
  },450);
}
function handlePlayPoint(i) {
  if(game.thinking) return;
  if(game.board[i]) { inspect = inspect===i?null:i; const g=group(game.board,i,9); game.message=`${coordinate(i,9)} 所在的${game.board[i]===1?'黑':'白'}棋有 ${g.stones.length} 颗子、${g.liberties.length} 口气。${g.liberties.length===1?'注意：这块棋正在被打吃！':'圈出的空点就是这块棋的气。'}`; render(); return; }
  if(game.ended) { game.message='本轮已经暂停。点击「继续下棋」后可以继续落子。'; render(); return; }
  const r=play(game.board,i,1,9,game.history);
  if(r.error) { game.message=r.error; render(); return; }
  game.snapshots.push(snapshot()); inspect=null; game.estimate=false; addMove(i,1,r); game.message=r.captured.length?`你提掉了 ${r.captured.length} 颗白子。白棋正在思考…`:r.liberties.length===1?'这手下完，你的棋只剩一口气。留意白棋的回应。':'已落子。白棋正在思考…'; scheduleBot();
}
$.addEventListener('click', e=> {
  const button = e.target.closest('button'); if(!button || button.disabled) return;
  if(button.dataset.mode) { mode=button.dataset.mode; inspect=null; render(); return; }
  if(button.dataset.lesson!==undefined) { mode='learn'; loadLesson(Number(button.dataset.lesson)); render(); window.scrollTo({top:0,behavior:'smooth'}); return; }
  if(button.dataset.point!==undefined) { const i=Number(button.dataset.point); mode==='play'?handlePlayPoint(i):handleLessonPoint(i); return; }
  if(button.dataset.answer!==undefined) { chosenAnswer=Number(button.dataset.answer); chosenAnswer===lessons[lessonIndex].answer?complete():wrong('再想一想。回到上面的规则，看看哪一个选项符合棋子的气和本课条件。'); render(); return; }
  switch(button.dataset.action) {
    case 'reset': loadLesson(lessonIndex); break;
    case 'hint': hint=true; feedback=lessons[lessonIndex].hint; feedbackKind='info'; break;
    case 'next': if(lessonIndex<7) loadLesson(lessonIndex+1); else mode='play'; break;
    case 'liberties': showLiberties=!showLiberties; inspect=null; break;
    case 'undo': if(game.snapshots.length && !game.thinking) { Object.assign(game,game.snapshots.pop()); game.ended=false; game.estimate=false; inspect=null; game.message='已经退回到你上一手之前。想一想，换个落点会发生什么？'; } break;
    case 'new-game': if(game.moves.length && !window.confirm('重新开局会清空这盘练习，学习进度仍会保留。确定重新开局吗？')) return; newGame(); break;
    case 'estimate': game.estimate=!game.estimate; break;
    case 'continue': game.ended=false; game.passes=0; game.estimate=false; game.message='继续练习。先看看哪些边界还没封住，哪些棋还需要补活。'; break;
    case 'pass': if(!game.thinking && !game.ended) { game.snapshots.push(snapshot()); addMove(null,1); scheduleBot(); return; } break;
  }
  render();
});
render();
