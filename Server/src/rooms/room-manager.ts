/**
 * Room and Match Manager.
 * Orchestrates room lifecycles, matchmaking matches, timeouts, disconnect grace periods, and spectators.
 */

import { randomBytes } from 'crypto';
import { XiangqiBoard } from '../engine/board.js';
import { Move, PieceColor } from '../engine/types.js';
import { ClockManager } from './clock-manager.js';
import {
  DEFAULT_TIME_CONFIG,
  Match,
  Player,
  Room,
  Spectator,
  TimeConfig,
  WinReason,
} from './types.js';

export interface RoomEvents {
  onMatchFound?: (match: Match) => void;
  onMoveApplied?: (
    match: Match,
    result: {
      from: [number, number];
      to: [number, number];
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
  ) => void;
  onMatchOver?: (match: Match, winner: PieceColor | 'DRAW', reason: WinReason) => void;
  onOpponentStatus?: (
    match: Match,
    playerId: string,
    status: 'DISCONNECTED' | 'RECONNECTED',
    gracePeriodSeconds?: number
  ) => void;
  onDrawOffered?: (match: Match, fromColor: PieceColor) => void;
  onDrawResolved?: (match: Match, accepted: boolean) => void;
  onSpectatorJoined?: (room: Room, spectator: Spectator) => void;
}

export class RoomManager {
  private rooms = new Map<string, Room>();
  private matches = new Map<string, Match>();
  private playerToRoom = new Map<string, string>();
  private playerToMatch = new Map<string, string>();
  private disconnectTimers = new Map<string, NodeJS.Timeout>();

  public readonly clockManager: ClockManager;
  private events: RoomEvents;

  constructor(events: RoomEvents = {}) {
    this.clockManager = new ClockManager();
    this.events = events;
  }

  public setEvents(events: RoomEvents): void {
    this.events = { ...this.events, ...events };
  }

  /**
   * Generates a unique 6-character uppercase alphanumeric room code.
   */
  public generateRoomCode(): string {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // excludes ambiguous chars 0, 1, I, O
    let code = '';
    do {
      code = '';
      const bytes = randomBytes(6);
      for (let i = 0; i < 6; i++) {
        code += chars[bytes[i] % chars.length];
      }
    } while (this.rooms.has(code));
    return code;
  }

  /**
   * Creates a custom room with a 6-character code.
   */
  public createCustomRoom(
    hostId: string,
    hostName: string,
    timeConfig: TimeConfig = DEFAULT_TIME_CONFIG
  ): Room {
    const roomCode = this.generateRoomCode();
    const hostPlayer: Player = {
      id: hostId,
      name: hostName,
      isConnected: true,
    };

    const room: Room = {
      roomCode,
      isCustom: true,
      timeConfig,
      hostId,
      players: new Map([[hostId, hostPlayer]]),
      spectators: new Map(),
      match: null,
      status: 'WAITING',
      createdAt: Date.now(),
    };

    this.rooms.set(roomCode, room);
    this.playerToRoom.set(hostId, roomCode);

    return room;
  }

  /**
   * Joins an existing room (as player 2 or as spectator if full).
   */
  public joinRoom(
    roomCode: string,
    playerId: string,
    playerName: string
  ): { room: Room; role: 'PLAYER' | 'SPECTATOR'; match?: Match | null } {
    const normalizedCode = roomCode.toUpperCase().trim();
    const room = this.rooms.get(normalizedCode);
    if (!room) {
      throw new Error(`Room '${roomCode}' not found`);
    }

    this.playerToRoom.set(playerId, normalizedCode);

    // If player is already in room, treat as reconnect
    if (room.players.has(playerId)) {
      const existing = room.players.get(playerId)!;
      existing.isConnected = true;
      existing.disconnectedAt = undefined;
      return { room, role: 'PLAYER', match: room.match };
    }

    if (room.spectators.has(playerId)) {
      return { room, role: 'SPECTATOR', match: room.match };
    }

    // If waiting for second player
    if (room.players.size < 2 && room.status === 'WAITING') {
      const newPlayer: Player = {
        id: playerId,
        name: playerName,
        isConnected: true,
      };
      room.players.set(playerId, newPlayer);

      // Start the match now that 2 players are present
      const match = this.startMatch(room);
      return { room, role: 'PLAYER', match };
    }

    // Room is full -> join as spectator
    const spectator: Spectator = { id: playerId, name: playerName };
    room.spectators.set(playerId, spectator);
    this.events.onSpectatorJoined?.(room, spectator);

    return { room, role: 'SPECTATOR', match: room.match };
  }

  /**
   * Starts a match inside a room with 2 players.
   */
  private startMatch(room: Room): Match {
    const players = Array.from(room.players.values());
    if (players.length < 2) {
      throw new Error('Cannot start match with less than 2 players');
    }

    // Randomize Red and Black
    const isFirstPlayerRed = Math.random() < 0.5;
    const redPlayer = isFirstPlayerRed ? players[0] : players[1];
    const blackPlayer = isFirstPlayerRed ? players[1] : players[0];

    redPlayer.color = 'RED';
    blackPlayer.color = 'BLACK';

    const matchId = `match_${room.roomCode}_${Date.now()}`;
    const board = new XiangqiBoard();
    const clock = this.clockManager.createClock(room.timeConfig);

    const match: Match = {
      id: matchId,
      roomCode: room.roomCode,
      board,
      redPlayer,
      blackPlayer,
      clock,
      status: 'PLAYING',
      createdAt: Date.now(),
    };

    room.match = match;
    room.status = 'PLAYING';

    this.matches.set(matchId, match);
    this.playerToMatch.set(redPlayer.id, matchId);
    this.playerToMatch.set(blackPlayer.id, matchId);

    // Start clock
    this.clockManager.startClock(matchId, clock, (mId, timedOutColor) => {
      this.handleTimeout(mId, timedOutColor);
    });

    this.events.onMatchFound?.(match);
    return match;
  }

  /**
   * Creates a match from matchmaking queue.
   */
  public createMatchFromQueue(
    p1: { id: string; name: string },
    p2: { id: string; name: string },
    timeConfig: TimeConfig = DEFAULT_TIME_CONFIG
  ): Match {
    const roomCode = this.generateRoomCode();
    const player1: Player = { id: p1.id, name: p1.name, isConnected: true };
    const player2: Player = { id: p2.id, name: p2.name, isConnected: true };

    const room: Room = {
      roomCode,
      isCustom: false,
      timeConfig,
      hostId: p1.id,
      players: new Map([
        [p1.id, player1],
        [p2.id, player2],
      ]),
      spectators: new Map(),
      match: null,
      status: 'WAITING',
      createdAt: Date.now(),
    };

    this.rooms.set(roomCode, room);
    this.playerToRoom.set(p1.id, roomCode);
    this.playerToRoom.set(p2.id, roomCode);

    return this.startMatch(room);
  }

  /**
   * Applies a player move in a match.
   */
  public makeMove(
    matchId: string,
    playerId: string,
    move: Move
  ): { success: boolean; error?: string } {
    const match = this.matches.get(matchId);
    if (!match) {
      return { success: false, error: 'Match not found' };
    }

    if (match.status !== 'PLAYING') {
      return { success: false, error: 'Match is already finished' };
    }

    const player =
      match.redPlayer.id === playerId
        ? match.redPlayer
        : match.blackPlayer.id === playerId
        ? match.blackPlayer
        : null;

    if (!player || !player.color) {
      return { success: false, error: 'Player not part of this match' };
    }

    if (match.board.getTurn() !== player.color) {
      return { success: false, error: `Not your turn (current turn: ${match.board.getTurn()})` };
    }

    // Validate and apply move
    const result = match.board.makeMove(move);
    if (!result.valid) {
      return { success: false, error: result.error || 'Invalid move' };
    }

    // Reset draw offers
    match.drawOfferFrom = null;

    // Check game termination (Checkmate or Stalemate)
    if (result.isCheckmate) {
      match.status = 'FINISHED';
      match.winner = player.color;
      match.winReason = 'CHECKMATE';
      this.clockManager.stopClock(matchId);

      const timeSnap = this.clockManager.getTimeRemainingSnapshot(match.clock);
      this.events.onMoveApplied?.(match, {
        from: move.from,
        to: move.to,
        capturedPiece: result.captured,
        isCheck: true,
        isCheckmate: true,
        isBlockCheck: !!result.isBlockCheck,
        nextTurn: result.nextTurn!,
        uci: result.uci!,
        timeRemaining: timeSnap,
      });

      this.events.onMatchOver?.(match, player.color, 'CHECKMATE');
      return { success: true };
    }

    if (result.isStalemate) {
      // In Xiangqi, stalemated player loses
      match.status = 'FINISHED';
      match.winner = player.color;
      match.winReason = 'STALEMATE';
      this.clockManager.stopClock(matchId);

      const timeSnap = this.clockManager.getTimeRemainingSnapshot(match.clock);
      this.events.onMoveApplied?.(match, {
        from: move.from,
        to: move.to,
        capturedPiece: result.captured,
        isCheck: false,
        isCheckmate: false,
        isBlockCheck: !!result.isBlockCheck,
        nextTurn: result.nextTurn!,
        uci: result.uci!,
        timeRemaining: timeSnap,
      });

      this.events.onMatchOver?.(match, player.color, 'STALEMATE');
      return { success: true };
    }

    // Normal move: switch turn clock
    this.clockManager.switchTurn(
      matchId,
      match.clock,
      result.nextTurn!,
      (mId, timedOutColor) => {
        this.handleTimeout(mId, timedOutColor);
      }
    );

    const timeSnap = this.clockManager.getTimeRemainingSnapshot(match.clock);

    this.events.onMoveApplied?.(match, {
      from: move.from,
      to: move.to,
      capturedPiece: result.captured,
      isCheck: !!result.isCheck,
      isCheckmate: false,
      isBlockCheck: !!result.isBlockCheck,
      nextTurn: result.nextTurn!,
      uci: result.uci!,
      timeRemaining: timeSnap,
    });

    return { success: true };
  }

  /**
   * Handles player resignation.
   */
  public resign(matchId: string, playerId: string): { success: boolean; error?: string } {
    const match = this.matches.get(matchId);
    if (!match || match.status !== 'PLAYING') {
      return { success: false, error: 'Match not found or already finished' };
    }

    let winner: PieceColor;
    if (match.redPlayer.id === playerId) {
      winner = 'BLACK';
    } else if (match.blackPlayer.id === playerId) {
      winner = 'RED';
    } else {
      return { success: false, error: 'Player not in this match' };
    }

    match.status = 'FINISHED';
    match.winner = winner;
    match.winReason = 'RESIGN';
    this.clockManager.stopClock(matchId);

    this.events.onMatchOver?.(match, winner, 'RESIGN');
    return { success: true };
  }

  /**
   * Offers a draw to the opponent.
   */
  public offerDraw(matchId: string, playerId: string): { success: boolean; error?: string } {
    const match = this.matches.get(matchId);
    if (!match || match.status !== 'PLAYING') {
      return { success: false, error: 'Match not found or already finished' };
    }

    const playerColor =
      match.redPlayer.id === playerId
        ? 'RED'
        : match.blackPlayer.id === playerId
        ? 'BLACK'
        : null;

    if (!playerColor) {
      return { success: false, error: 'Player not in match' };
    }

    match.drawOfferFrom = playerColor;
    this.events.onDrawOffered?.(match, playerColor);
    return { success: true };
  }

  /**
   * Responds to a draw offer.
   */
  public respondDraw(
    matchId: string,
    playerId: string,
    accepted: boolean
  ): { success: boolean; error?: string } {
    const match = this.matches.get(matchId);
    if (!match || match.status !== 'PLAYING') {
      return { success: false, error: 'Match not found or already finished' };
    }

    if (!match.drawOfferFrom) {
      return { success: false, error: 'No active draw offer' };
    }

    const playerColor =
      match.redPlayer.id === playerId
        ? 'RED'
        : match.blackPlayer.id === playerId
        ? 'BLACK'
        : null;

    if (!playerColor || playerColor === match.drawOfferFrom) {
      return { success: false, error: 'Cannot accept own draw offer' };
    }

    match.drawOfferFrom = null;

    if (accepted) {
      match.status = 'FINISHED';
      match.winner = 'DRAW';
      match.winReason = 'DRAW_AGREED';
      this.clockManager.stopClock(matchId);
      this.events.onDrawResolved?.(match, true);
      this.events.onMatchOver?.(match, 'DRAW', 'DRAW_AGREED');
    } else {
      this.events.onDrawResolved?.(match, false);
    }

    return { success: true };
  }

  /**
   * Handles player turn / time bank timeout.
   */
  private handleTimeout(matchId: string, timedOutColor: PieceColor): void {
    const match = this.matches.get(matchId);
    if (!match || match.status !== 'PLAYING') return;

    const winner: PieceColor = timedOutColor === 'RED' ? 'BLACK' : 'RED';
    match.status = 'FINISHED';
    match.winner = winner;
    match.winReason = 'TIMEOUT';
    this.clockManager.stopClock(matchId);

    this.events.onMatchOver?.(match, winner, 'TIMEOUT');
  }

  /**
   * Handles player disconnect with 60-second grace period.
   */
  public handlePlayerDisconnect(playerId: string): void {
    const matchId = this.playerToMatch.get(playerId);
    if (!matchId) return;

    const match = this.matches.get(matchId);
    if (!match || match.status !== 'PLAYING') return;

    const player =
      match.redPlayer.id === playerId
        ? match.redPlayer
        : match.blackPlayer.id === playerId
        ? match.blackPlayer
        : null;

    if (!player) return;

    player.isConnected = false;
    player.disconnectedAt = Date.now();

    this.events.onOpponentStatus?.(match, playerId, 'DISCONNECTED', 60);

    // Cancel existing timer if any
    const existing = this.disconnectTimers.get(playerId);
    if (existing) clearTimeout(existing);

    // 60-second grace period
    const timer = setTimeout(() => {
      this.disconnectTimers.delete(playerId);
      if (!player.isConnected && match.status === 'PLAYING') {
        const winner: PieceColor = player.color === 'RED' ? 'BLACK' : 'RED';
        match.status = 'FINISHED';
        match.winner = winner;
        match.winReason = 'DISCONNECT_TIMEOUT';
        this.clockManager.stopClock(matchId);
        this.events.onMatchOver?.(match, winner, 'DISCONNECT_TIMEOUT');
      }
    }, 60000);

    this.disconnectTimers.set(playerId, timer);
  }

  /**
   * Handles player reconnect within grace period.
   */
  public handlePlayerReconnect(playerId: string): Match | null {
    const timer = this.disconnectTimers.get(playerId);
    if (timer) {
      clearTimeout(timer);
      this.disconnectTimers.delete(playerId);
    }

    const matchId = this.playerToMatch.get(playerId);
    if (!matchId) return null;

    const match = this.matches.get(matchId);
    if (!match) return null;

    const player =
      match.redPlayer.id === playerId
        ? match.redPlayer
        : match.blackPlayer.id === playerId
        ? match.blackPlayer
        : null;

    if (player) {
      player.isConnected = true;
      player.disconnectedAt = undefined;
      this.events.onOpponentStatus?.(match, playerId, 'RECONNECTED');
    }

    return match;
  }

  public getRoom(roomCode: string): Room | null {
    return this.rooms.get(roomCode.toUpperCase().trim()) || null;
  }

  public getMatch(matchId: string): Match | null {
    return this.matches.get(matchId) || null;
  }

  public getPlayerMatch(playerId: string): Match | null {
    const matchId = this.playerToMatch.get(playerId);
    return matchId ? this.matches.get(matchId) || null : null;
  }

  public getPlayerRoom(playerId: string): Room | null {
    const roomCode = this.playerToRoom.get(playerId);
    return roomCode ? this.rooms.get(roomCode) || null : null;
  }

  public cleanUp(): void {
    this.clockManager.clearAll();
    for (const t of this.disconnectTimers.values()) {
      clearTimeout(t);
    }
    this.disconnectTimers.clear();
    this.rooms.clear();
    this.matches.clear();
    this.playerToRoom.clear();
    this.playerToMatch.clear();
  }
}
