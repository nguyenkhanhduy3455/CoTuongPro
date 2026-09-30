import { describe, it, expect, beforeEach } from 'vitest';
import { XiangqiBoard } from '../src/engine/board.js';
import { moveToUCI, uciToMove, uciToPos, posToUCI } from '../src/engine/uci.js';

describe('Xiangqi Game Engine', () => {
  let board: XiangqiBoard;

  beforeEach(() => {
    board = new XiangqiBoard();
  });

  describe('UCI Utilities', () => {
    it('converts between coordinates and UCI strings accurately', () => {
      expect(posToUCI([0, 0])).toBe('a0');
      expect(posToUCI([8, 9])).toBe('i9');
      expect(posToUCI([1, 2])).toBe('b2');
      expect(posToUCI([4, 0])).toBe('e0');

      expect(uciToPos('a0')).toEqual([0, 0]);
      expect(uciToPos('i9')).toEqual([8, 9]);
      expect(uciToPos('b2')).toEqual([1, 2]);
      expect(uciToPos('e0')).toEqual([4, 0]);

      const move = { from: [1, 2] as [number, number], to: [4, 2] as [number, number] };
      const uci = moveToUCI(move);
      expect(uci).toBe('b2e2');
      expect(uciToMove(uci)).toEqual(move);
    });
  });

  describe('Initial Setup & FEN', () => {
    it('initializes default 9x10 Xiangqi board correctly', () => {
      // Red King at e0 (4, 0)
      expect(board.getPiece([4, 0])).toEqual({ type: 'KING', color: 'RED' });
      // Black King at e9 (4, 9)
      expect(board.getPiece([4, 9])).toEqual({ type: 'KING', color: 'BLACK' });
      // Red Cannons at b2 (1, 2) and h2 (7, 2)
      expect(board.getPiece([1, 2])).toEqual({ type: 'CANNON', color: 'RED' });
      expect(board.getPiece([7, 2])).toEqual({ type: 'CANNON', color: 'RED' });
      // Black Cannons at b7 (1, 7) and h7 (7, 7)
      expect(board.getPiece([1, 7])).toEqual({ type: 'CANNON', color: 'BLACK' });
      expect(board.getPiece([7, 7])).toEqual({ type: 'CANNON', color: 'BLACK' });

      expect(board.getTurn()).toBe('RED');
    });

    it('exports and imports FEN string accurately', () => {
      const initialFEN = board.toFEN();
      const newBoard = new XiangqiBoard();
      newBoard.loadFEN(initialFEN);
      expect(newBoard.toFEN()).toBe(initialFEN);
    });
  });

  describe('Horse Movement & Hobbling (Cản chân mã)', () => {
    it('allows valid L-shaped move when foot is free', () => {
      // Clear board and place Red Horse at c3 (2, 3)
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([2, 3], { type: 'HORSE', color: 'RED' });

      // Horse at (2,3) can move to (3,5) with foot at (2,4)
      const res = board.makeMove({ from: [2, 3], to: [3, 5] });
      expect(res.valid).toBe(true);
    });

    it('blocks horse movement when foot is obstructed (cản chân mã)', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([2, 3], { type: 'HORSE', color: 'RED' });

      // Place blocking piece at foot (2, 4)
      board.setPiece([2, 4], { type: 'PAWN', color: 'RED' });

      // Moving to (1, 5) or (3, 5) requires foot (2, 4) -> should fail
      const res1 = board.makeMove({ from: [2, 3], to: [3, 5] });
      expect(res1.valid).toBe(false);
      expect(res1.error).toContain('cản chân mã');

      const res2 = board.makeMove({ from: [2, 3], to: [1, 5] });
      expect(res2.valid).toBe(false);

      // But moving to (4, 4) requires foot (3, 3), which is clear -> should succeed
      const res3 = board.makeMove({ from: [2, 3], to: [4, 4] });
      expect(res3.valid).toBe(true);
    });
  });

  describe('Elephant Movement & Eye Blocking (Cản tượng & Sông)', () => {
    it('allows 2-step diagonal move on own side of river', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([2, 0], { type: 'ELEPHANT', color: 'RED' });

      const res = board.makeMove({ from: [2, 0], to: [4, 2] });
      expect(res.valid).toBe(true);
    });

    it('blocks elephant when eye is obstructed (cản mắt tượng)', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([2, 0], { type: 'ELEPHANT', color: 'RED' });

      // Obstruct eye at (3, 1)
      board.setPiece([3, 1], { type: 'PAWN', color: 'BLACK' });

      const res = board.makeMove({ from: [2, 0], to: [4, 2] });
      expect(res.valid).toBe(false);
      expect(res.error).toContain('cản tượng');
    });

    it('prevents Elephant from crossing the river', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([4, 4], { type: 'ELEPHANT', color: 'RED' });

      // Attempt to cross river to (2, 6) or (6, 6)
      const res = board.makeMove({ from: [4, 4], to: [6, 6] });
      expect(res.valid).toBe(false);
      expect(res.error).toContain('cross the river');
    });
  });

  describe('Cannon Rules (Ngòi & Nhảy bắt quân)', () => {
    it('moves like a Rook when not capturing (0 screen pieces)', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([1, 2], { type: 'CANNON', color: 'RED' });

      // Move along empty file
      const res = board.makeMove({ from: [1, 2], to: [1, 6] });
      expect(res.valid).toBe(true);
    });

    it('cannot capture without a screen piece', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([1, 2], { type: 'CANNON', color: 'RED' });
      board.setPiece([1, 6], { type: 'ROOK', color: 'BLACK' });

      // Direct capture with 0 screens is illegal for Cannon
      const res = board.makeMove({ from: [1, 2], to: [1, 6] });
      expect(res.valid).toBe(false);
      expect(res.error).toContain('screen piece');
    });

    it('captures an enemy piece by jumping over exactly 1 screen piece', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([1, 2], { type: 'CANNON', color: 'RED' });
      board.setPiece([1, 4], { type: 'PAWN', color: 'RED' }); // screen
      board.setPiece([1, 7], { type: 'ROOK', color: 'BLACK' }); // target

      const res = board.makeMove({ from: [1, 2], to: [1, 7] });
      expect(res.valid).toBe(true);
      expect(res.captured?.type).toBe('ROOK');
      expect(board.getPiece([1, 7])?.type).toBe('CANNON');
    });

    it('cannot jump over 2 screen pieces to capture', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([1, 2], { type: 'CANNON', color: 'RED' });
      board.setPiece([1, 4], { type: 'PAWN', color: 'RED' }); // screen 1
      board.setPiece([1, 5], { type: 'PAWN', color: 'BLACK' }); // screen 2
      board.setPiece([1, 7], { type: 'ROOK', color: 'BLACK' }); // target

      const res = board.makeMove({ from: [1, 2], to: [1, 7] });
      expect(res.valid).toBe(false);
    });
  });

  describe('Palace Boundaries (Tướng & Sĩ)', () => {
    it('restricts King to the 3x3 palace', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });

      // Move within palace: (4,0) -> (4,1)
      const res1 = board.makeMove({ from: [4, 0], to: [4, 1] });
      expect(res1.valid).toBe(true);

      // Attempt to move outside palace: (4,1) -> (3,1) then (2,1)
      board.setPiece([3, 1], { type: 'KING', color: 'RED' });
      board.setTurn('RED');
      const res2 = board.makeMove({ from: [3, 1], to: [2, 1] });
      expect(res2.valid).toBe(false);
      expect(res2.error).toContain('palace');
    });

    it('restricts Advisor to diagonal moves inside palace', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([3, 0], { type: 'ADVISOR', color: 'RED' });

      // (3,0) -> (4,1) is valid
      const res = board.makeMove({ from: [3, 0], to: [4, 1] });
      expect(res.valid).toBe(true);
    });
  });

  describe('Pawn Crossing River Rules (Tốt qua sông)', () => {
    it('allows only forward movement before crossing river', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([0, 3], { type: 'PAWN', color: 'RED' });

      // Forward (0,3) -> (0,4)
      const res1 = board.makeMove({ from: [0, 3], to: [0, 4] });
      expect(res1.valid).toBe(true);

      // Sideways before river is illegal
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([0, 3], { type: 'PAWN', color: 'RED' });
      const res2 = board.makeMove({ from: [0, 3], to: [1, 3] });
      expect(res2.valid).toBe(false);
    });

    it('allows forward and sideways movement after crossing river', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([4, 5], { type: 'PAWN', color: 'RED' }); // already across river

      // Sideways (4,5) -> (3,5)
      const res = board.makeMove({ from: [4, 5], to: [3, 5] });
      expect(res.valid).toBe(true);
    });
  });

  describe('Flying General Rule (Lộ mặt tướng)', () => {
    it('prevents Kings from facing each other on the same column', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([4, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([4, 5], { type: 'ROOK', color: 'RED' }); // shield

      // Red moves Rook away from column 4 -> Kings face each other!
      const res = board.makeMove({ from: [4, 5], to: [2, 5] });
      expect(res.valid).toBe(false);
      expect(res.error).toContain('Flying General');
    });
  });

  describe('Check & Checkmate Detection', () => {
    it('detects check when King is attacked', () => {
      board.clear();
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      board.setPiece([5, 9], { type: 'KING', color: 'BLACK' });
      board.setPiece([0, 8], { type: 'ROOK', color: 'RED' });

      // Move Rook to (5, 8) to check Black King at (5, 9)
      const res = board.makeMove({ from: [0, 8], to: [5, 8] });
      expect(res.valid).toBe(true);
      expect(res.isCheck).toBe(true);
    });

    it('detects checkmate when King has no escape or defense', () => {
      board.clear();
      // Red King at (4, 0)
      board.setPiece([4, 0], { type: 'KING', color: 'RED' });
      // Black King at corner of palace (3, 9)
      board.setPiece([3, 9], { type: 'KING', color: 'BLACK' });

      // Red Rook 1 at (3, 0) blocks column 3 escape (3, 8)
      board.setPiece([3, 0], { type: 'ROOK', color: 'RED' });
      // Red Rook 2 at (4, 5)
      board.setPiece([4, 5], { type: 'ROOK', color: 'RED' });

      // Red moves Rook 2 to (4, 9) delivering check along rank 9
      const res = board.makeMove({ from: [4, 5], to: [4, 9] });
      expect(res.valid).toBe(true);
      expect(res.isCheck).toBe(true);
      expect(res.isCheckmate).toBe(true);
    });
  });
});
