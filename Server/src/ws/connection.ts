/**
 * WebSocket Connection and Broadcast Manager.
 */

import { WebSocket } from 'ws';
import { Match, Room } from '../rooms/types.js';
import { ServerEvent, ServerEventType } from './protocol.js';

export interface UserConnection {
  playerId: string;
  name: string;
  ws: WebSocket;
  isAlive: boolean;
  connectedAt: number;
}

export class ConnectionManager {
  private connectionsByPlayerId = new Map<string, UserConnection>();
  private playerIdsBySocket = new Map<WebSocket, string>();
  private heartbeatInterval?: NodeJS.Timeout;

  constructor() {
    this.startHeartbeat();
  }

  public register(ws: WebSocket, playerId: string, name: string): UserConnection {
    const existing = this.connectionsByPlayerId.get(playerId);
    if (existing && existing.ws !== ws) {
      try {
        existing.ws.close();
      } catch {}
      this.playerIdsBySocket.delete(existing.ws);
    }

    const conn: UserConnection = {
      playerId,
      name,
      ws,
      isAlive: true,
      connectedAt: Date.now(),
    };

    this.connectionsByPlayerId.set(playerId, conn);
    this.playerIdsBySocket.set(ws, playerId);

    return conn;
  }

  public unregister(ws: WebSocket): string | null {
    const playerId = this.playerIdsBySocket.get(ws);
    if (playerId) {
      this.playerIdsBySocket.delete(ws);
      const conn = this.connectionsByPlayerId.get(playerId);
      if (conn && conn.ws === ws) {
        this.connectionsByPlayerId.delete(playerId);
      }
      return playerId;
    }
    return null;
  }

  public getConnection(playerId: string): UserConnection | null {
    return this.connectionsByPlayerId.get(playerId) || null;
  }

  public getPlayerId(ws: WebSocket): string | null {
    return this.playerIdsBySocket.get(ws) || null;
  }

  /**
   * Sends a structured event to a specific player.
   */
  public send<T>(playerId: string, event: ServerEventType, payload: T): boolean {
    const conn = this.connectionsByPlayerId.get(playerId);
    if (!conn || conn.ws.readyState !== WebSocket.OPEN) {
      return false;
    }
    return this.sendSocket(conn.ws, event, payload);
  }

  /**
   * Sends a structured event directly to a WebSocket.
   */
  public sendSocket<T>(ws: WebSocket, event: ServerEventType, payload: T): boolean {
    if (ws.readyState !== WebSocket.OPEN) {
      return false;
    }
    const message: ServerEvent<T> = { event, payload };
    try {
      ws.send(JSON.stringify(message));
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Sends an error event to a player socket.
   */
  public sendError(ws: WebSocket, message: string, code?: string): void {
    this.sendSocket(ws, 'ERROR', { message, code });
  }

  /**
   * Broadcasts an event to all players in a match.
   */
  public broadcastToMatch<T>(
    match: Match,
    event: ServerEventType,
    payload: T,
    excludePlayerId?: string
  ): void {
    const playerIds = [match.redPlayer.id, match.blackPlayer.id];
    for (const pid of playerIds) {
      if (pid !== excludePlayerId) {
        this.send(pid, event, payload);
      }
    }
  }

  /**
   * Broadcasts an event to all players and spectators in a room.
   */
  public broadcastToRoom<T>(
    room: Room,
    event: ServerEventType,
    payload: T,
    excludePlayerId?: string
  ): void {
    for (const pid of room.players.keys()) {
      if (pid !== excludePlayerId) {
        this.send(pid, event, payload);
      }
    }
    for (const sid of room.spectators.keys()) {
      if (sid !== excludePlayerId) {
        this.send(sid, event, payload);
      }
    }
  }

  private startHeartbeat(): void {
    this.heartbeatInterval = setInterval(() => {
      for (const [ws, playerId] of this.playerIdsBySocket.entries()) {
        const conn = this.connectionsByPlayerId.get(playerId);
        if (!conn || !conn.isAlive) {
          try {
            ws.terminate();
          } catch {}
          this.unregister(ws);
        } else {
          conn.isAlive = false;
          try {
            ws.ping();
          } catch {
            this.unregister(ws);
          }
        }
      }
    }, 30000);
  }

  public setAlive(ws: WebSocket): void {
    const playerId = this.playerIdsBySocket.get(ws);
    if (playerId) {
      const conn = this.connectionsByPlayerId.get(playerId);
      if (conn) conn.isAlive = true;
    }
  }

  public closeAll(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
    for (const conn of this.connectionsByPlayerId.values()) {
      try {
        conn.ws.close();
      } catch {}
    }
    this.connectionsByPlayerId.clear();
    this.playerIdsBySocket.clear();
  }
}
