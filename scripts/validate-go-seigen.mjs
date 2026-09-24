import fs from 'node:fs';
import path from 'node:path';
import { emptyBoard, hash, play } from '../src/go.js';

const directory = process.argv[2];
if (!directory) throw new Error('Usage: node scripts/validate-go-seigen.mjs DATA_DIRECTORY');
const manifest = JSON.parse(fs.readFileSync(path.join(directory, 'manifest.json'), 'utf8'));
const reports = [];
for (const game of manifest.games) {
  if (!game.moves) continue;
  let board = emptyBoard(19), previousColor = null, positions = [hash(board)];
  const failures = [];
  const index = point => {
    if (!/^[a-s]{2}$/.test(point)) throw new Error(`Invalid coordinate ${point}`);
    return (point.charCodeAt(1) - 97) * 19 + point.charCodeAt(0) - 97;
  };
  for (const [property, color] of [['AB', 1], ['AW', 2]]) {
    for (const point of game.properties[property] || []) board[index(point)] = color;
  }
  positions = [hash(board)];
  for (const [offset, move] of game.moves.entries()) {
    try {
      if (move.color === previousColor) failures.push({ move: offset + 1, error: 'Consecutive moves of one color' });
      previousColor = move.color;
      if (!move.point || move.point === 'tt') { positions.push(hash(board)); continue; }
      // Historical Japanese records use simple ko, not positional superko.
      const forbidden = positions.length >= 2 ? [positions.at(-2)] : [];
      const next = play(board, index(move.point), move.color === 'B' ? 1 : 2, 19, forbidden);
      if (next.error) throw new Error(next.error);
      board = next.board;
      positions.push(hash(board));
    } catch (error) {
      failures.push({ move: offset + 1, error: error.message });
      break;
    }
  }
  reports.push({ id: game.id, moves: game.moves.length, valid: failures.length === 0, failures });
}
const result = { checked: reports.length, passed: reports.filter(r => r.valid).length,
  scope: 'Coordinates, alternating colors, occupancy, captures, suicide and simple ko. Not book membership, scoring or historical accuracy.', games: reports };
fs.writeFileSync(path.join(directory, 'validation.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ checked: result.checked, passed: result.passed, failures: reports.filter(r => !r.valid) }, null, 2));
if (result.checked !== result.passed) process.exitCode = 1;
