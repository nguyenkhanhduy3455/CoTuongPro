/**
 * Xiangqi Board and Rule Validation Engine.
 * Clean architecture, immutable methods where beneficial, high-performance rule validator.
 */

import {
  BOARD_COLS,
  BOARD_ROWS,
  INITIAL_FEN,
  FEN_PIECE_MAP,
  PIECE_FEN_MAP,
  isInsideBoard,
  isInPalace,
  hasCrossedRiver,
} from './constants.js';
import {
  DetailedMove,
  GameStatus,
  Move,
  MoveValidationResult,
  Piece,
  PieceColor,
  PieceType,
  Position,
} from './types.js';
import { moveToUCI, uciToMove } from './uci.js';

export class XiangqiBoard {
  // Grid indexed by [y][x] where y: 0..9 (rank), x: 0..8 (file)
  private grid: (Piece | null)[][];
  private turn: PieceColor;
  private moveHistory: DetailedMove[];

  constructor() {
    this.grid = Array.from({ length: BOARD_ROWS }, () =>
      Array.from({ length: BOARD_COLS }, () => null)
    );
    this.turn = 'RED';
    this.moveHistory = [];
    this.setupInitialPosition();
  }

  /**
   * Initializes standard starting setup for Xiangqi.
   */
  public setupInitialPosition(): void {
    this.loadFEN(INITIAL_FEN);
  }

  /**
   * Clears the board.
   */
  public clear(): void {
    for (let y = 0; y < BOARD_ROWS; y++) {
      for (let x = 0; x < BOARD_COLS; x++) {
        this.grid[y][x] = null;
      }
    }
    this.turn = 'RED';
    this.moveHistory = [];
  }

  /**
   * Gets the piece at a given coordinate [x, y].
   */
  public getPiece(pos: Position): Piece | null {
    const [x, y] = pos;
    if (!isInsideBoard(x, y)) return null;
    return this.grid[y][x];
  }

  /**
   * Sets a piece at a given coordinate [x, y].
   */
  public setPiece(pos: Position, piece: Piece | null): void {
    const [x, y] = pos;
    if (!isInsideBoard(x, y)) {
      throw new Error(`Position [${x}, ${y}] outside board limits`);
    }
    this.grid[y][x] = piece ? { ...piece } : null;
  }

  public getTurn(): PieceColor {
    return this.turn;
  }

  public setTurn(color: PieceColor): void {
    this.turn = color;
  }

  public getMoveHistory(): ReadonlyArray<DetailedMove> {
    return this.moveHistory;
  }

  public getGrid(): ReadonlyArray<ReadonlyArray<Piece | null>> {
    return this.grid;
  }

  /**
   * Creates a deep clone of the board.
   */
  public clone(): XiangqiBoard {
    const cloned = new XiangqiBoard();
    for (let y = 0; y < BOARD_ROWS; y++) {
      for (let x = 0; x < BOARD_COLS; x++) {
        const p = this.grid[y][x];
        cloned.grid[y][x] = p ? { ...p } : null;
      }
    }
    cloned.turn = this.turn;
    cloned.moveHistory = this.moveHistory.map((m) => ({ ...m }));
    return cloned;
  }

  /**
   * Finds the King position for a given color.
   */
  public findKing(color: PieceColor): Position | null {
    for (let y = 0; y < BOARD_ROWS; y++) {
      for (let x = 0; x < BOARD_COLS; x++) {
        const piece = this.grid[y][x];
        if (piece && piece.type === 'KING' && piece.color === color) {
          return [x, y];
        }
      }
    }
    return null;
  }

  /**
   * Checks the Flying General rule (Tướng đối mặt / Lộ mặt tướng).
   * Returns true if both kings are on the same column with no intervening pieces.
   */
  public areKingsFacing(): boolean {
    const redKing = this.findKing('RED');
    const blackKing = this.findKing('BLACK');

    if (!redKing || !blackKing) return false;
    if (redKing[0] !== blackKing[0]) return false;

    const col = redKing[0];
    const minY = Math.min(redKing[1], blackKing[1]);
    const maxY = Math.max(redKing[1], blackKing[1]);

    for (let y = minY + 1; y < maxY; y++) {
      if (this.grid[y][col] !== null) {
        return false; // Intervening piece found
      }
    }

    return true; // No pieces between them -> Kings are facing each other!
  }

  /**
   * Counts pieces strictly between two orthogonal positions on the board.
   */
  public countInterveningPieces(from: Position, to: Position): number {
    const [fromX, fromY] = from;
    const [toX, toY] = to;

    let count = 0;
    if (fromX === toX) {
      const step = fromY < toY ? 1 : -1;
      for (let y = fromY + step; y !== toY; y += step) {
        if (this.grid[y][fromX] !== null) {
          count++;
        }
      }
    } else if (fromY === toY) {
      const step = fromX < toX ? 1 : -1;
      for (let x = fromX + step; x !== toX; x += step) {
        if (this.grid[fromY][x] !== null) {
          count++;
        }
      }
    }
    return count;
  }

  /**
   * Validates if a piece-level move geometry is valid (ignoring king safety / self-check).
   */
  public isPseudoLegalMove(move: Move): { valid: boolean; reason?: string } {
    const { from, to } = move;
    const [fromX, fromY] = from;
    const [toX, toY] = to;

    if (!isInsideBoard(fromX, fromY) || !isInsideBoard(toX, toY)) {
      return { valid: false, reason: 'Coordinates outside board' };
    }

    if (fromX === toX && fromY === toY) {
      return { valid: false, reason: 'Origin and destination are the same' };
    }

    const piece = this.grid[fromY][fromX];
    if (!piece) {
      return { valid: false, reason: 'No piece at source position' };
    }

    const destPiece = this.grid[toY][toX];
    if (destPiece && destPiece.color === piece.color) {
      return { valid: false, reason: 'Cannot capture friendly piece' };
    }

    const dx = toX - fromX;
    const dy = toY - fromY;
    const absDx = Math.abs(dx);
    const absDy = Math.abs(dy);

    switch (piece.type) {
      case 'KING': {
        // King moves 1 step orthogonally within the palace
        if ((absDx === 1 && absDy === 0) || (absDx === 0 && absDy === 1)) {
          if (!isInPalace(toX, toY, piece.color)) {
            return { valid: false, reason: 'King cannot leave the palace' };
          }
          return { valid: true };
        }
        return { valid: false, reason: 'Invalid move geometry for King' };
      }

      case 'ADVISOR': {
        // Advisor moves 1 step diagonally within the palace
        if (absDx === 1 && absDy === 1) {
          if (!isInPalace(toX, toY, piece.color)) {
            return { valid: false, reason: 'Advisor cannot leave the palace' };
          }
          return { valid: true };
        }
        return { valid: false, reason: 'Invalid move geometry for Advisor' };
      }

      case 'ELEPHANT': {
        // Elephant moves 2 steps diagonally, cannot cross river, blocked if eye is occupied
        if (absDx === 2 && absDy === 2) {
          // Check river boundary
          if (piece.color === 'RED' && toY > 4) {
            return { valid: false, reason: 'Red Elephant cannot cross the river' };
          }
          if (piece.color === 'BLACK' && toY < 5) {
            return { valid: false, reason: 'Black Elephant cannot cross the river' };
          }
          // Check elephant eye (cản tượng)
          const eyeX = fromX + dx / 2;
          const eyeY = fromY + dy / 2;
          if (this.grid[eyeY][eyeX] !== null) {
            return { valid: false, reason: 'Elephant eye is blocked (cản tượng)' };
          }
          return { valid: true };
        }
        return { valid: false, reason: 'Invalid move geometry for Elephant' };
      }

      case 'HORSE': {
        // Horse moves L-shape (1 orthogonal + 1 diagonal outward)
        if ((absDx === 1 && absDy === 2) || (absDx === 2 && absDy === 1)) {
          // Check hobbling foot (cản chân mã)
          let footX = fromX;
          let footY = fromY;
          if (absDy === 2) {
            footY = fromY + dy / 2;
          } else {
            footX = fromX + dx / 2;
          }

          if (this.grid[footY][footX] !== null) {
            return { valid: false, reason: 'Horse foot is hobbled (cản chân mã)' };
          }
          return { valid: true };
        }
        return { valid: false, reason: 'Invalid move geometry for Horse' };
      }

      case 'ROOK': {
        // Moves orthogonal any distance with no intervening pieces
        if (fromX === toX || fromY === toY) {
          const count = this.countInterveningPieces(from, to);
          if (count === 0) {
            return { valid: true };
          }
          return { valid: false, reason: 'Rook path is blocked' };
        }
        return { valid: false, reason: 'Rook must move orthogonally' };
      }

      case 'CANNON': {
        // Moves like Rook when moving, jumps over exactly 1 screen to capture
        if (fromX === toX || fromY === toY) {
          const count = this.countInterveningPieces(from, to);
          if (destPiece === null) {
            // Non-capturing move: requires 0 pieces in between
            if (count === 0) return { valid: true };
            return { valid: false, reason: 'Cannon path is blocked' };
          } else {
            // Capturing move: requires exactly 1 intervening piece (the screen / ngòi)
            if (count === 1) return { valid: true };
            return { valid: false, reason: 'Cannon requires exactly 1 screen piece to capture' };
          }
        }
        return { valid: false, reason: 'Cannon must move orthogonally' };
      }

      case 'PAWN': {
        // Moves 1 step forward; after river can also move 1 step left/right. Never backwards.
        const forwardStep = piece.color === 'RED' ? 1 : -1;
        const crossed = hasCrossedRiver(fromY, piece.color);

        // Forward move
        if (dx === 0 && dy === forwardStep) {
          return { valid: true };
        }

        // Sideways move (only allowed after crossing river)
        if (crossed && absDx === 1 && dy === 0) {
          return { valid: true };
        }

        return { valid: false, reason: 'Invalid move geometry for Pawn' };
      }
    }

    return { valid: false, reason: 'Unknown piece type' };
  }

  /**
   * Checks whether the King of `color` is currently under attack (in check).
   */
  public isKingInCheck(color: PieceColor): boolean {
    const kingPos = this.findKing(color);
    if (!kingPos) return true; // Missing king is considered in check/lost

    // Flying general rule check: if kings are facing, current king is threatened
    if (this.areKingsFacing()) {
      return true;
    }

    const opponentColor: PieceColor = color === 'RED' ? 'BLACK' : 'RED';

    // Scan all opponent pieces and check if any can attack the king
    for (let y = 0; y < BOARD_ROWS; y++) {
      for (let x = 0; x < BOARD_COLS; x++) {
        const piece = this.grid[y][x];
        if (piece && piece.color === opponentColor) {
          const res = this.isPseudoLegalMove({ from: [x, y], to: kingPos });
          if (res.valid) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /**
   * Generates all pseudo-legal moves for a color.
   */
  public generatePseudoLegalMoves(color: PieceColor): Move[] {
    const moves: Move[] = [];

    for (let fromY = 0; fromY < BOARD_ROWS; fromY++) {
      for (let fromX = 0; fromX < BOARD_COLS; fromX++) {
        const piece = this.grid[fromY][fromX];
        if (!piece || piece.color !== color) continue;

        const from: Position = [fromX, fromY];

        // Specific targeted target generation for faster performance
        switch (piece.type) {
          case 'KING': {
            const offsets = [[0, 1], [0, -1], [1, 0], [-1, 0]];
            for (const [ox, oy] of offsets) {
              const to: Position = [fromX + ox, fromY + oy];
              if (this.isPseudoLegalMove({ from, to }).valid) {
                moves.push({ from, to });
              }
            }
            break;
          }
          case 'ADVISOR': {
            const offsets = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
            for (const [ox, oy] of offsets) {
              const to: Position = [fromX + ox, fromY + oy];
              if (this.isPseudoLegalMove({ from, to }).valid) {
                moves.push({ from, to });
              }
            }
            break;
          }
          case 'ELEPHANT': {
            const offsets = [[2, 2], [2, -2], [-2, 2], [-2, -2]];
            for (const [ox, oy] of offsets) {
              const to: Position = [fromX + ox, fromY + oy];
              if (this.isPseudoLegalMove({ from, to }).valid) {
                moves.push({ from, to });
              }
            }
            break;
          }
          case 'HORSE': {
            const offsets = [
              [1, 2], [-1, 2], [1, -2], [-1, -2],
              [2, 1], [-2, 1], [2, -1], [-2, -1]
            ];
            for (const [ox, oy] of offsets) {
              const to: Position = [fromX + ox, fromY + oy];
              if (this.isPseudoLegalMove({ from, to }).valid) {
                moves.push({ from, to });
              }
            }
            break;
          }
          case 'ROOK':
          case 'CANNON': {
            // Straight lines in 4 directions
            const dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];
            for (const [dx, dy] of dirs) {
              let nx = fromX + dx;
              let ny = fromY + dy;
              while (isInsideBoard(nx, ny)) {
                const to: Position = [nx, ny];
                if (this.isPseudoLegalMove({ from, to }).valid) {
                  moves.push({ from, to });
                }
                // If there's a piece, stop ray for rook, but cannon might jump past first screen
                if (piece.type === 'ROOK' && this.grid[ny][nx] !== null) {
                  break;
                }
                nx += dx;
                ny += dy;
              }
            }
            break;
          }
          case 'PAWN': {
            const forward = piece.color === 'RED' ? 1 : -1;
            const offsets = [[0, forward], [1, 0], [-1, 0]];
            for (const [ox, oy] of offsets) {
              const to: Position = [fromX + ox, fromY + oy];
              if (this.isPseudoLegalMove({ from, to }).valid) {
                moves.push({ from, to });
              }
            }
            break;
          }
        }
      }
    }

    return moves;
  }

  /**
   * Generates all strictly legal moves for `color` (moves that don't leave own King in check).
   */
  public generateLegalMoves(color: PieceColor): Move[] {
    const pseudoMoves = this.generatePseudoLegalMoves(color);
    const legalMoves: Move[] = [];

    for (const move of pseudoMoves) {
      if (this.isMoveLegalWithoutModifying(move, color)) {
        legalMoves.push(move);
      }
    }

    return legalMoves;
  }

  /**
   * Tests if a move is legal without permanently modifying board state.
   */
  private isMoveLegalWithoutModifying(move: Move, color: PieceColor): boolean {
    const { from, to } = move;
    const [fromX, fromY] = from;
    const [toX, toY] = to;

    const savedFromPiece = this.grid[fromY][fromX];
    const savedToPiece = this.grid[toY][toX];

    // Make speculative move
    this.grid[toY][toX] = savedFromPiece;
    this.grid[fromY][fromX] = null;

    const inCheck = this.isKingInCheck(color);

    // Rollback
    this.grid[fromY][fromX] = savedFromPiece;
    this.grid[toY][toX] = savedToPiece;

    return !inCheck;
  }

  /**
   * Validates and applies a move on the board.
   * Returns validation result, check/checkmate/stalemate status, and UCI notation.
   */
  public makeMove(move: Move | string): MoveValidationResult {
    const parsedMove: Move = typeof move === 'string' ? uciToMove(move) : move;
    const { from, to } = parsedMove;
    const [fromX, fromY] = from;
    const [toX, toY] = to;

    const piece = this.getPiece(from);
    if (!piece) {
      return { valid: false, error: 'No piece at origin position' };
    }

    if (piece.color !== this.turn) {
      return {
        valid: false,
        error: `It is ${this.turn}'s turn, but move is for ${piece.color}`,
      };
    }

    // Check pseudo-legality
    const pseudo = this.isPseudoLegalMove(parsedMove);
    if (!pseudo.valid) {
      return { valid: false, error: pseudo.reason || 'Illegal move geometry' };
    }

    // Check if player was previously in check
    const wasInCheck = this.isKingInCheck(this.turn);

    // Test legality (king safety)
    const targetPiece = this.getPiece(to);
    this.grid[toY][toX] = piece;
    this.grid[fromY][fromX] = null;

    if (this.isKingInCheck(this.turn)) {
      // Revert
      this.grid[fromY][fromX] = piece;
      this.grid[toY][toX] = targetPiece;
      return {
        valid: false,
        error: 'Move leaves or places own King in check (or violates Flying General rule)',
      };
    }

    const uci = moveToUCI(parsedMove);

    // Record detailed move
    this.moveHistory.push({
      from,
      to,
      piece: { ...piece },
      captured: targetPiece ? { ...targetPiece } : null,
      uci,
    });

    const nextTurn: PieceColor = this.turn === 'RED' ? 'BLACK' : 'RED';
    this.turn = nextTurn;

    // Check game state for opponent
    const isCheck = this.isKingInCheck(nextTurn);
    const opponentLegalMoves = this.generateLegalMoves(nextTurn);

    let isCheckmate = false;
    let isStalemate = false;

    if (opponentLegalMoves.length === 0) {
      if (isCheck) {
        isCheckmate = true;
      } else {
        isStalemate = true;
      }
    }

    const isBlockCheck = wasInCheck && !this.isKingInCheck(piece.color);

    return {
      valid: true,
      captured: targetPiece,
      isCheck,
      isCheckmate,
      isStalemate,
      isBlockCheck,
      nextTurn,
      uci,
    };
  }

  /**
   * Returns current game status.
   */
  public getGameStatus(): GameStatus {
    const inCheck = this.isKingInCheck(this.turn);
    const legalMoves = this.generateLegalMoves(this.turn);

    if (legalMoves.length === 0) {
      return inCheck ? 'CHECKMATE' : 'STALEMATE';
    }

    return inCheck ? 'CHECK' : 'PLAYING';
  }

  /**
   * Loads board state from a FEN string.
   */
  public loadFEN(fen: string): void {
    this.clear();
    const parts = fen.trim().split(/\s+/);
    const boardPart = parts[0];
    const turnPart = parts[1] || 'w';

    const rows = boardPart.split('/');
    if (rows.length !== BOARD_ROWS) {
      throw new Error(`Invalid Xiangqi FEN: expected 10 rows, got ${rows.length}`);
    }

    // FEN ranks are typically written top-to-bottom (Black side y=9 down to Red side y=0)
    for (let r = 0; r < BOARD_ROWS; r++) {
      const y = 9 - r; // row index in our 0..9 grid
      const rowStr = rows[r];
      let x = 0;

      for (let i = 0; i < rowStr.length; i++) {
        const char = rowStr[i];
        if (char >= '1' && char <= '9') {
          x += parseInt(char, 10);
        } else {
          const piece = FEN_PIECE_MAP[char];
          if (piece) {
            this.grid[y][x] = { ...piece };
            x++;
          }
        }
      }
    }

    this.turn = turnPart.toLowerCase() === 'b' ? 'BLACK' : 'RED';
  }

  /**
   * Exports current board state to FEN string.
   */
  public toFEN(): string {
    const rowStrings: string[] = [];

    for (let r = 0; r < BOARD_ROWS; r++) {
      const y = 9 - r;
      let emptyCount = 0;
      let rowStr = '';

      for (let x = 0; x < BOARD_COLS; x++) {
        const piece = this.grid[y][x];
        if (piece === null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rowStr += emptyCount.toString();
            emptyCount = 0;
          }
          const key = `${piece.color}_${piece.type}`;
          rowStr += PIECE_FEN_MAP[key] || '?';
        }
      }

      if (emptyCount > 0) {
        rowStr += emptyCount.toString();
      }
      rowStrings.push(rowStr);
    }

    const turnStr = this.turn === 'RED' ? 'w' : 'b';
    return `${rowStrings.join('/')} ${turnStr} - - 0 1`;
  }
}
