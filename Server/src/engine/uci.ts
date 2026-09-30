/**
 * UCI (Universal Chess Interface) coordinate conversion utilities for Xiangqi.
 * Files: 0..8 -> 'a'..'i'
 * Ranks: 0..9 -> '0'..'9'
 */

import { Move, Position } from './types.js';
import { isInsideBoard } from './constants.js';

const FILES = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'];

export function posToUCI(pos: Position): string {
  const [x, y] = pos;
  if (!isInsideBoard(x, y)) {
    throw new Error(`Position (${x}, ${y}) is outside board`);
  }
  return `${FILES[x]}${y}`;
}

export function uciToPos(uciCoord: string): Position {
  if (uciCoord.length !== 2) {
    throw new Error(`Invalid UCI coordinate: ${uciCoord}`);
  }
  const fileChar = uciCoord[0].toLowerCase();
  const rankChar = uciCoord[1];

  const x = FILES.indexOf(fileChar);
  const y = parseInt(rankChar, 10);

  if (x === -1 || isNaN(y) || !isInsideBoard(x, y)) {
    throw new Error(`Invalid UCI coordinate: ${uciCoord}`);
  }
  return [x, y];
}

export function moveToUCI(move: Move): string {
  return `${posToUCI(move.from)}${posToUCI(move.to)}`;
}

export function uciToMove(uciStr: string): Move {
  if (uciStr.length !== 4) {
    throw new Error(`Invalid UCI move string: ${uciStr}`);
  }
  return {
    from: uciToPos(uciStr.slice(0, 2)),
    to: uciToPos(uciStr.slice(2, 4)),
  };
}
