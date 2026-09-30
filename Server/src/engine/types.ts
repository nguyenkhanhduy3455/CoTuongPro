/**
 * Domain types for Xiangqi (Chinese Chess / Cờ Tướng) Game Engine.
 */

export type PieceColor = 'RED' | 'BLACK';

export type PieceType =
  | 'KING' // Tướng / Soái (帅/将)
  | 'ADVISOR' // Sĩ (仕/士)
  | 'ELEPHANT' // Tượng / Tượng (相/象)
  | 'HORSE' // Mã (傌/馬)
  | 'ROOK' // Xe (俥/車)
  | 'CANNON' // Pháo (炮/砲)
  | 'PAWN'; // Tốt / Binh (兵/卒)

export interface Piece {
  type: PieceType;
  color: PieceColor;
}

/**
 * Coordinate position on the 9x10 Xiangqi board.
 * x: File (column index, 0..8 from left 'a' to right 'i')
 * y: Rank (row index, 0..9 from Red baseline 0 to Black baseline 9)
 */
export type Position = [number, number];

export interface Move {
  from: Position;
  to: Position;
}

export interface DetailedMove extends Move {
  piece: Piece;
  captured?: Piece | null;
  uci: string;
}

export type GameStatus =
  | 'PLAYING'
  | 'CHECK'
  | 'CHECKMATE'
  | 'STALEMATE'
  | 'DRAW'
  | 'RESIGNED'
  | 'TIMEOUT';

export interface MoveValidationResult {
  valid: boolean;
  error?: string;
  captured?: Piece | null;
  isCheck?: boolean;
  isCheckmate?: boolean;
  isStalemate?: boolean;
  isBlockCheck?: boolean;
  nextTurn?: PieceColor;
  uci?: string;
}

export interface BoardDimensions {
  cols: 9;
  rows: 10;
}
