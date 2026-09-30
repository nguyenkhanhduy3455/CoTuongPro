/**
 * Types for Room, Match, and Clock management.
 */

import { PieceColor } from '../engine/types.js';
import { XiangqiBoard } from '../engine/board.js';

export interface TimeConfig {
  totalBankSeconds: number; // e.g. 600s (10 mins)
  turnLimitSeconds: number; // e.g. 30s per turn
}

export const DEFAULT_TIME_CONFIG: TimeConfig = {
  totalBankSeconds: 600,
  turnLimitSeconds: 30,
};

export interface Player {
  id: string;
  name: string;
  color?: PieceColor;
  isConnected: boolean;
  disconnectedAt?: number;
}

export interface Spectator {
  id: string;
  name: string;
}

export type WinReason =
  | 'CHECKMATE'
  | 'STALEMATE'
  | 'TIMEOUT'
  | 'RESIGN'
  | 'DISCONNECT_TIMEOUT'
  | 'DRAW_AGREED';

export interface TimeRemainingSnapshot {
  redTimeRemainingMs: number;
  blackTimeRemainingMs: number;
  currentTurnTimeRemainingMs: number;
}

export interface MatchClock {
  redBankRemainingMs: number;
  blackBankRemainingMs: number;
  turnLimitMs: number;
  turnStartTimeMs: number;
  currentTurn: PieceColor;
  isRunning: boolean;
}

export interface Match {
  id: string;
  roomCode: string;
  board: XiangqiBoard;
  redPlayer: Player;
  blackPlayer: Player;
  clock: MatchClock;
  status: 'PLAYING' | 'FINISHED';
  winner?: PieceColor | 'DRAW';
  winReason?: WinReason;
  drawOfferFrom?: PieceColor | null;
  createdAt: number;
}

export interface Room {
  roomCode: string;
  isCustom: boolean;
  timeConfig: TimeConfig;
  hostId: string;
  players: Map<string, Player>;
  spectators: Map<string, Spectator>;
  match: Match | null;
  status: 'WAITING' | 'PLAYING' | 'FINISHED';
  createdAt: number;
}
