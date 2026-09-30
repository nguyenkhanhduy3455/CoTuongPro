/**
 * WebSocket Protocol Definition and Zod Schemas.
 */

import { z } from 'zod';
import { PieceColor, Position } from '../engine/types.js';
import { WinReason } from '../rooms/types.js';

export const TimeConfigSchema = z.object({
  totalBankSeconds: z.number().int().positive().default(600),
  turnLimitSeconds: z.number().int().positive().default(30),
});

// Position schema [x, y] where 0 <= x <= 8 and 0 <= y <= 9
export const PositionSchema = z.tuple([
  z.number().int().min(0).max(8),
  z.number().int().min(0).max(9),
]);

// Client Actions
export const QueueFindMatchActionSchema = z.object({
  action: z.literal('QUEUE_FIND_MATCH'),
  name: z.string().min(1).max(32).optional(),
  rating: z.number().optional(),
  timeConfig: TimeConfigSchema.optional(),
});

export const QueueCancelActionSchema = z.object({
  action: z.literal('QUEUE_CANCEL'),
});

export const RoomCreateActionSchema = z.object({
  action: z.literal('ROOM_CREATE'),
  name: z.string().min(1).max(32).optional(),
  timeConfig: TimeConfigSchema.optional(),
});

export const RoomJoinActionSchema = z.object({
  action: z.literal('ROOM_JOIN'),
  roomCode: z.string().min(4).max(10),
  name: z.string().min(1).max(32).optional(),
});

export const MakeMoveActionSchema = z.object({
  action: z.literal('MAKE_MOVE'),
  matchId: z.string(),
  from: PositionSchema,
  to: PositionSchema,
});

export const ResignActionSchema = z.object({
  action: z.literal('RESIGN'),
  matchId: z.string(),
});

export const OfferDrawActionSchema = z.object({
  action: z.literal('OFFER_DRAW'),
  matchId: z.string(),
});

export const RespondDrawActionSchema = z.object({
  action: z.literal('RESPOND_DRAW'),
  matchId: z.string(),
  accepted: z.boolean(),
});

export const ReconnectActionSchema = z.object({
  action: z.literal('RECONNECT'),
  playerId: z.string(),
});

export const PingActionSchema = z.object({
  action: z.literal('PING'),
});

export const ClientActionSchema = z.discriminatedUnion('action', [
  QueueFindMatchActionSchema,
  QueueCancelActionSchema,
  RoomCreateActionSchema,
  RoomJoinActionSchema,
  MakeMoveActionSchema,
  ResignActionSchema,
  OfferDrawActionSchema,
  RespondDrawActionSchema,
  ReconnectActionSchema,
  PingActionSchema,
]);

export type ClientAction = z.infer<typeof ClientActionSchema>;

// Server Events
export type ServerEventType =
  | 'CONNECTED'
  | 'QUEUE_JOINED'
  | 'QUEUE_CANCELLED'
  | 'ROOM_CREATED'
  | 'ROOM_JOINED'
  | 'SPECTATOR_JOINED'
  | 'MATCH_FOUND'
  | 'MOVE_APPLIED'
  | 'MATCH_OVER'
  | 'OPPONENT_STATUS'
  | 'DRAW_OFFERED'
  | 'DRAW_RESOLVED'
  | 'RECONNECTED'
  | 'PONG'
  | 'ERROR';

export interface ServerEvent<T = any> {
  event: ServerEventType;
  payload: T;
}

export interface MatchFoundPayload {
  matchId: string;
  roomCode: string;
  role: PieceColor;
  opponentName: string;
  opponentId: string;
  fen: string;
  timeConfig: {
    totalBankSeconds: number;
    turnLimitSeconds: number;
  };
}

export interface MoveAppliedPayload {
  matchId: string;
  from: Position;
  to: Position;
  capturedPiece: any;
  isCheck: boolean;
  isCheckmate: boolean;
  isBlockCheck: boolean;
  nextTurn: PieceColor;
  uci: string;
  timeRemaining: {
    redTimeRemainingMs: number;
    blackTimeRemainingMs: number;
    currentTurnTimeRemainingMs: number;
  };
}

export interface MatchOverPayload {
  matchId: string;
  winner: PieceColor | 'DRAW';
  reason: WinReason;
}

export interface OpponentStatusPayload {
  matchId: string;
  status: 'DISCONNECTED' | 'RECONNECTED';
  gracePeriodSeconds?: number;
}
