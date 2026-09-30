/**
 * Constants & board boundaries for Xiangqi Game Engine.
 */

import { Piece, PieceColor, Position } from './types.js';

export const BOARD_COLS = 9;
export const BOARD_ROWS = 10;

export const PALACE_X_MIN = 3;
export const PALACE_X_MAX = 5;

export const RED_PALACE_Y_MIN = 0;
export const RED_PALACE_Y_MAX = 2;

export const BLACK_PALACE_Y_MIN = 7;
export const BLACK_PALACE_Y_MAX = 9;

export const RED_RIVER_Y_MAX = 4;
export const BLACK_RIVER_Y_MIN = 5;

export const INITIAL_FEN = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

export const FEN_PIECE_MAP: Record<string, Piece> = {
  K: { type: 'KING', color: 'RED' },
  A: { type: 'ADVISOR', color: 'RED' },
  B: { type: 'ELEPHANT', color: 'RED' }, // Elephant is 'B' (Bishop) or 'E' in FEN
  E: { type: 'ELEPHANT', color: 'RED' },
  N: { type: 'HORSE', color: 'RED' },    // Horse is 'N' or 'H'
  H: { type: 'HORSE', color: 'RED' },
  R: { type: 'ROOK', color: 'RED' },
  C: { type: 'CANNON', color: 'RED' },
  P: { type: 'PAWN', color: 'RED' },
  k: { type: 'KING', color: 'BLACK' },
  a: { type: 'ADVISOR', color: 'BLACK' },
  b: { type: 'ELEPHANT', color: 'BLACK' },
  e: { type: 'ELEPHANT', color: 'BLACK' },
  n: { type: 'HORSE', color: 'BLACK' },
  h: { type: 'HORSE', color: 'BLACK' },
  r: { type: 'ROOK', color: 'BLACK' },
  c: { type: 'CANNON', color: 'BLACK' },
  p: { type: 'PAWN', color: 'BLACK' },
};

export const PIECE_FEN_MAP: Record<string, string> = {
  'RED_KING': 'K',
  'RED_ADVISOR': 'A',
  'RED_ELEPHANT': 'B',
  'RED_HORSE': 'N',
  'RED_ROOK': 'R',
  'RED_CANNON': 'C',
  'RED_PAWN': 'P',
  'BLACK_KING': 'k',
  'BLACK_ADVISOR': 'a',
  'BLACK_ELEPHANT': 'b',
  'BLACK_HORSE': 'n',
  'BLACK_ROOK': 'r',
  'BLACK_CANNON': 'c',
  'BLACK_PAWN': 'p',
};

/**
 * Returns whether a coordinate position is inside the board.
 */
export function isInsideBoard(x: number, y: number): boolean {
  return x >= 0 && x < BOARD_COLS && y >= 0 && y < BOARD_ROWS;
}

/**
 * Returns whether a coordinate is inside the palace for a given player color.
 */
export function isInPalace(x: number, y: number, color: PieceColor): boolean {
  if (x < PALACE_X_MIN || x > PALACE_X_MAX) return false;
  if (color === 'RED') {
    return y >= RED_PALACE_Y_MIN && y <= RED_PALACE_Y_MAX;
  } else {
    return y >= BLACK_PALACE_Y_MIN && y <= BLACK_PALACE_Y_MAX;
  }
}

/**
 * Returns whether a coordinate has crossed the river for a given player color.
 */
export function hasCrossedRiver(y: number, color: PieceColor): boolean {
  if (color === 'RED') {
    return y > RED_RIVER_Y_MAX; // y >= 5
  } else {
    return y < BLACK_RIVER_Y_MIN; // y <= 4
  }
}
