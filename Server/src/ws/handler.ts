/**
 * WebSocket Action Handler and Dispatcher.
 */

import { WebSocket } from 'ws';
import { MatchmakingQueue } from '../matchmaking/queue.js';
import { RoomManager } from '../rooms/room-manager.js';
import { Match, Room } from '../rooms/types.js';
import { ConnectionManager } from './connection.js';
import { ClientAction, ClientActionSchema, ServerEvent } from './protocol.js';

export class WebSocketHandler {
  private roomManager: RoomManager;
  private queue: MatchmakingQueue;
  public readonly connectionManager: ConnectionManager;

  constructor(roomManager: RoomManager, queue: MatchmakingQueue) {
    this.roomManager = roomManager;
    this.queue = queue;
    this.connectionManager = new ConnectionManager();

    // Attach RoomManager lifecycle listeners to broadcast through WebSocket
    this.setupRoomEvents();
  }

  private setupRoomEvents(): void {
    this.roomManager.setEvents({
      onMatchFound: (match: Match) => {
        const timeConfig = {
          totalBankSeconds: match.clock.redBankRemainingMs / 1000,
          turnLimitSeconds: match.clock.turnLimitMs / 1000,
        };

        // Send Red player match notification
        this.connectionManager.send(match.redPlayer.id, 'MATCH_FOUND', {
          matchId: match.id,
          roomCode: match.roomCode,
          role: 'RED',
          opponentName: match.blackPlayer.name,
          opponentId: match.blackPlayer.id,
          fen: match.board.toFEN(),
          timeConfig,
        });

        // Send Black player match notification
        this.connectionManager.send(match.blackPlayer.id, 'MATCH_FOUND', {
          matchId: match.id,
          roomCode: match.roomCode,
          role: 'BLACK',
          opponentName: match.redPlayer.name,
          opponentId: match.redPlayer.id,
          fen: match.board.toFEN(),
          timeConfig,
        });
      },

      onMoveApplied: (match, result) => {
        const room = this.roomManager.getRoom(match.roomCode);
        const payload = {
          matchId: match.id,
          ...result,
        };
        if (room) {
          this.connectionManager.broadcastToRoom(room, 'MOVE_APPLIED', payload);
        } else {
          this.connectionManager.broadcastToMatch(match, 'MOVE_APPLIED', payload);
        }
      },

      onMatchOver: (match, winner, reason) => {
        const room = this.roomManager.getRoom(match.roomCode);
        const payload = {
          matchId: match.id,
          winner,
          reason,
        };
        if (room) {
          this.connectionManager.broadcastToRoom(room, 'MATCH_OVER', payload);
        } else {
          this.connectionManager.broadcastToMatch(match, 'MATCH_OVER', payload);
        }
      },

      onOpponentStatus: (match, playerId, status, gracePeriodSeconds) => {
        const opponentId =
          match.redPlayer.id === playerId ? match.blackPlayer.id : match.redPlayer.id;

        this.connectionManager.send(opponentId, 'OPPONENT_STATUS', {
          matchId: match.id,
          status,
          gracePeriodSeconds,
        });
      },

      onDrawOffered: (match, fromColor) => {
        const targetId =
          fromColor === 'RED' ? match.blackPlayer.id : match.redPlayer.id;

        this.connectionManager.send(targetId, 'DRAW_OFFERED', {
          matchId: match.id,
          fromColor,
        });
      },

      onDrawResolved: (match, accepted) => {
        this.connectionManager.broadcastToMatch(match, 'DRAW_RESOLVED', {
          matchId: match.id,
          accepted,
        });
      },

      onSpectatorJoined: (room, spectator) => {
        this.connectionManager.broadcastToRoom(
          room,
          'SPECTATOR_JOINED',
          {
            roomCode: room.roomCode,
            spectatorName: spectator.name,
          },
          spectator.id
        );
      },
    });
  }

  /**
   * Main entry point for processing incoming messages from a WebSocket.
   */
  public async handleMessage(ws: WebSocket, rawData: string | Buffer): Promise<void> {
    let parsedJson: any;
    try {
      parsedJson = JSON.parse(rawData.toString());
    } catch {
      this.connectionManager.sendError(ws, 'Invalid JSON payload');
      return;
    }

    const validationResult = ClientActionSchema.safeParse(parsedJson);
    if (!validationResult.success) {
      this.connectionManager.sendError(
        ws,
        `Invalid action format: ${validationResult.error.message}`
      );
      return;
    }

    const action = validationResult.data;
    const playerId = this.connectionManager.getPlayerId(ws);

    try {
      await this.dispatch(ws, playerId, action);
    } catch (err: any) {
      this.connectionManager.sendError(ws, err.message || 'Internal server error');
    }
  }

  private async dispatch(
    ws: WebSocket,
    playerId: string | null,
    action: ClientAction
  ): Promise<void> {
    switch (action.action) {
      case 'PING': {
        this.connectionManager.setAlive(ws);
        this.connectionManager.sendSocket(ws, 'PONG', { timestamp: Date.now() });
        return;
      }

      case 'RECONNECT': {
        const user = this.connectionManager.getConnection(action.playerId);
        const name = user ? user.name : `Player_${action.playerId.slice(0, 5)}`;
        this.connectionManager.register(ws, action.playerId, name);

        const match = this.roomManager.handlePlayerReconnect(action.playerId);
        if (match) {
          const role = match.redPlayer.id === action.playerId ? 'RED' : 'BLACK';
          const opponent = role === 'RED' ? match.blackPlayer : match.redPlayer;
          const timeSnap = this.roomManager.clockManager.getTimeRemainingSnapshot(match.clock);

          this.connectionManager.sendSocket(ws, 'RECONNECTED', {
            matchId: match.id,
            roomCode: match.roomCode,
            role,
            opponentName: opponent.name,
            fen: match.board.toFEN(),
            turn: match.board.getTurn(),
            history: match.board.getMoveHistory(),
            timeRemaining: timeSnap,
            status: match.status,
          });
        } else {
          this.connectionManager.sendSocket(ws, 'CONNECTED', {
            playerId: action.playerId,
          });
        }
        return;
      }

      case 'QUEUE_FIND_MATCH': {
        if (!playerId) {
          this.connectionManager.sendError(ws, 'Connection not registered');
          return;
        }

        const conn = this.connectionManager.getConnection(playerId);
        const name = action.name || conn?.name || `Player_${playerId.slice(0, 5)}`;
        if (conn && action.name) {
          conn.name = action.name;
        }

        const result = this.queue.enqueue(
          { id: playerId, name, rating: action.rating },
          action.timeConfig
        );

        if (!result.matched) {
          this.connectionManager.sendSocket(ws, 'QUEUE_JOINED', {
            queueSize: this.queue.getQueueSize(),
          });
        }
        return;
      }

      case 'QUEUE_CANCEL': {
        if (playerId) {
          this.queue.cancel(playerId);
          this.connectionManager.sendSocket(ws, 'QUEUE_CANCELLED', {});
        }
        return;
      }

      case 'ROOM_CREATE': {
        if (!playerId) {
          this.connectionManager.sendError(ws, 'Connection not registered');
          return;
        }

        const conn = this.connectionManager.getConnection(playerId);
        const hostName = action.name || conn?.name || `Host_${playerId.slice(0, 5)}`;
        if (conn && action.name) {
          conn.name = action.name;
        }

        const room = this.roomManager.createCustomRoom(
          playerId,
          hostName,
          action.timeConfig
        );

        this.connectionManager.sendSocket(ws, 'ROOM_CREATED', {
          roomCode: room.roomCode,
          isCustom: true,
          timeConfig: room.timeConfig,
        });
        return;
      }

      case 'ROOM_JOIN': {
        if (!playerId) {
          this.connectionManager.sendError(ws, 'Connection not registered');
          return;
        }

        const conn = this.connectionManager.getConnection(playerId);
        const playerName = action.name || conn?.name || `Player_${playerId.slice(0, 5)}`;
        if (conn && action.name) {
          conn.name = action.name;
        }

        const joinResult = this.roomManager.joinRoom(
          action.roomCode,
          playerId,
          playerName
        );

        this.connectionManager.sendSocket(ws, 'ROOM_JOINED', {
          roomCode: joinResult.room.roomCode,
          role: joinResult.role,
        });

        // If spectator joins an active match, send match snapshot
        if (joinResult.role === 'SPECTATOR' && joinResult.match) {
          const m = joinResult.match;
          const timeSnap = this.roomManager.clockManager.getTimeRemainingSnapshot(m.clock);
          this.connectionManager.sendSocket(ws, 'RECONNECTED', {
            matchId: m.id,
            roomCode: m.roomCode,
            role: 'SPECTATOR',
            redPlayerName: m.redPlayer.name,
            blackPlayerName: m.blackPlayer.name,
            fen: m.board.toFEN(),
            turn: m.board.getTurn(),
            history: m.board.getMoveHistory(),
            timeRemaining: timeSnap,
            status: m.status,
          });
        }
        return;
      }

      case 'MAKE_MOVE': {
        if (!playerId) {
          this.connectionManager.sendError(ws, 'Connection not registered');
          return;
        }

        const moveResult = this.roomManager.makeMove(action.matchId, playerId, {
          from: action.from,
          to: action.to,
        });

        if (!moveResult.success) {
          this.connectionManager.sendError(ws, moveResult.error || 'Move failed');
        }
        return;
      }

      case 'RESIGN': {
        if (!playerId) {
          this.connectionManager.sendError(ws, 'Connection not registered');
          return;
        }

        const resignResult = this.roomManager.resign(action.matchId, playerId);
        if (!resignResult.success) {
          this.connectionManager.sendError(ws, resignResult.error || 'Resign failed');
        }
        return;
      }

      case 'OFFER_DRAW': {
        if (!playerId) {
          this.connectionManager.sendError(ws, 'Connection not registered');
          return;
        }

        const drawResult = this.roomManager.offerDraw(action.matchId, playerId);
        if (!drawResult.success) {
          this.connectionManager.sendError(ws, drawResult.error || 'Offer draw failed');
        }
        return;
      }

      case 'RESPOND_DRAW': {
        if (!playerId) {
          this.connectionManager.sendError(ws, 'Connection not registered');
          return;
        }

        const respondResult = this.roomManager.respondDraw(
          action.matchId,
          playerId,
          action.accepted
        );
        if (!respondResult.success) {
          this.connectionManager.sendError(
            ws,
            respondResult.error || 'Respond draw failed'
          );
        }
        return;
      }
    }
  }

  /**
   * Handles newly established WebSocket connection.
   */
  public handleConnection(ws: WebSocket, playerId: string, name?: string): void {
    const assignedName = name || `Player_${playerId.slice(0, 5)}`;
    this.connectionManager.register(ws, playerId, assignedName);

    this.connectionManager.sendSocket(ws, 'CONNECTED', {
      playerId,
      name: assignedName,
    });
  }

  /**
   * Handles disconnected WebSocket.
   */
  public handleDisconnection(ws: WebSocket): void {
    const playerId = this.connectionManager.unregister(ws);
    if (playerId) {
      this.queue.cancel(playerId);
      this.roomManager.handlePlayerDisconnect(playerId);
    }
  }
}
