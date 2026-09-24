import test from 'node:test';
import assert from 'node:assert/strict';
import { emptyBoard, group, play, hash, area, chooseMove } from '../src/go.js';
import { lessons } from '../src/lessons.js';
const position = (n, black, white) => { const b=emptyBoard(n); black.forEach(i=>b[i]=1); white.forEach(i=>b[i]=2); return b; };

test('liberties count only orthogonal empty points and are shared without duplication',()=>{
  const b=position(5,[11,12],[]);
  assert.deepEqual(group(b,11,5).stones.sort((a,b)=>a-b),[11,12]);
  assert.deepEqual(group(b,11,5).liberties.sort((a,b)=>a-b),[6,7,10,13,16,17]);
  assert.equal(group(position(5,[0],[]),0,5).liberties.length,2);
});
test('captures a whole enemy group and preserves input',()=>{
  const b=position(5,[1,2,5,8,11],[6,7]); const original=[...b];
  const r=play(b,12,1,5);
  assert.deepEqual(r.captured.sort((a,b)=>a-b),[6,7]);
  assert.equal(r.board[6],0); assert.deepEqual(b,original);
});
test('captures two separate groups in one move',()=>{
  const b=position(5,[1,5,11,3,9,13],[6,8]);
  assert.deepEqual(play(b,7,1,5).captured.sort((a,b)=>a-b),[6,8]);
});
test('rejects occupied points, out-of-range moves and suicide',()=>{
  const b=position(3,[1,3,5,7],[]);
  assert.ok(play(b,4,2,3).error); assert.ok(play(b,1,2,3).error); assert.ok(play(b,-1,2,3).error);
});
test('a move with no initial liberties is legal when it captures first',()=>{
  const b=position(3,[0,2,6,8],[1,3,5,7]);
  const r=play(b,4,1,3);
  assert.equal(r.error,undefined); assert.equal(r.captured.length,4); assert.equal(r.liberties.length,4);
});
test('ko and all previous positional repetitions are rejected',()=>{
  const before=position(5,[16,18,22],[7,11,13,17]);
  const take=play(before,12,1,5,[hash(before)]);
  assert.deepEqual(take.captured,[17]);
  assert.ok(play(take.board,17,2,5,[hash(before),hash(take.board)]).error);
  assert.equal(play(take.board,17,2,5,[]).error,undefined);
  const unrelated=emptyBoard(5);
  assert.ok(play(take.board,17,2,5,[hash(before),hash(unrelated),hash(take.board)]).error);
});
test('area calculation leaves mixed-border regions neutral and counts stones',()=>{
  const b=position(3,[0,1,3,4],[2,5,8]);
  const s=area(b,3); assert.equal(s.black,4); assert.equal(s.white,3); assert.equal(s.neutral,2);
  assert.deepEqual(area(emptyBoard(3),3),{black:0,white:0,neutral:9,territory:emptyBoard(3)});
  assert.equal(area(position(3,[1,3,5,7],[]),3).black,9);
});
test('all move lessons have legal solutions; lesson outcomes match concepts',()=>{
  for(const l of lessons.filter(l=>l.type==='move')) for(const i of l.target) assert.equal(play(l.board,i,1,l.n).error,undefined,l.title);
  assert.deepEqual(group(lessons[1].board,12,5).liberties.sort((a,b)=>a-b),[...lessons[1].target].sort((a,b)=>a-b));
  assert.equal(play(lessons[2].board,13,1,5).captured.length,1);
  assert.equal(play(lessons[3].board,13,1,5).liberties.length,3);
  assert.equal(group(play(lessons[4].board,12,1,5).board,11,5).stones.length,3);
  assert.ok(play(lessons[5].board,11,2,5).error); assert.ok(play(lessons[5].board,13,2,5).error);
});
test('bot prioritizes capturing a stone in atari',()=>{
  const b=position(5,[12],[7,11,17]); const r=chooseMove(b,2,5,[hash(b)]);
  assert.equal(r.i,13); assert.equal(r.captured.length,1);
});
test('long bot games maintain liberties, legality and nonrepetition',()=>{
  let b=emptyBoard(9), history=[hash(b)], passes=0;
  for(let t=0;t<180;t++){
    const color=t%2+1, move=chooseMove(b,color,9,history);
    if(!move){ if(++passes===2) break; continue; }
    passes=0; assert.equal(play(b,move.i,color,9,history).error,undefined);
    b=move.board; assert.ok(!history.includes(hash(b))); history.push(hash(b));
    b.forEach((c,i)=>{ if(c) assert.ok(group(b,i,9).liberties.length>0); });
  }
});
