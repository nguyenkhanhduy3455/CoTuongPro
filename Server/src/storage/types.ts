/**
 * Storage Abstraction Interfaces for Redis-ready distributed scaling.
 */

import { XiangqiBoard } from '../engine/board.js';
import { DetailedMove, PieceColor } from '../engine/types.js';

export interface PlayerSession {
  id: string;
  name: string;
  rating?: number;
  roomCode?: string;
  matchId?: string;
  role?: PieceColor | 'SPECTATOR';
  isConnected: boolean;
  disconnectedAt?: number;
}

export interface StoredMatch {
  id: string;
  roomCode: string;
  boardState: string; // FEN string
  turn: PieceColor;
  redPlayerId: string;
  blackPlayerId: string;
  redTimeRemainingMs: number;
  blackTimeRemainingMs: number;
  turnStartTimeMs: number;
  status: 'PLAYING' | 'FINISHED';
  winner?: PieceColor | 'DRAW';
  winReason?: string;
  drawOfferedBy?: PieceColor | null;
  history: DetailedMove[];
  createdAt: number;
  updatedAt: number;
}

export interface StoredRoom {
  code: string;
  isCustom: boolean;
  hostPlayerId: string;
  playerIds: string[];
  spectatorIds: string[];
  matchId?: string;
  status: 'WAITING' | 'PLAYING' | 'FINISHED';
  createdAt: number;
}

export interface IStateStore {
  // Session
  saveSession(session: PlayerSession): Promise<void>;
  getSession(playerId: string): Promise<PlayerSession | null>;
  deleteSession(playerId: string): Promise<void>;

  // Room
  saveRoom(room: StoredRoom): Promise<void>;
  getRoom(roomCode: string): Promise<StoredRoom | null>;
  deleteRoom(roomCode: string): Promise<void>;

  // Match
  saveMatch(match: StoredMatch): Promise<void>;
  getMatch(matchId: string): Promise<StoredMatch | null>;
  deleteMatch(matchId: string): Promise<void>;
}
