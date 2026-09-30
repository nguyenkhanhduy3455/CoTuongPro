/**
 * Matchmaking Queue System.
 * Atomic pairing of waiting players, customizable time configurations.
 */

import { RoomManager } from '../rooms/room-manager.js';
import { Match, TimeConfig, DEFAULT_TIME_CONFIG } from '../rooms/types.js';

export interface QueuedPlayer {
  id: string;
  name: string;
  rating?: number;
  timeConfig: TimeConfig;
  queuedAt: number;
}

export class MatchmakingQueue {
  private queue: QueuedPlayer[] = [];
  private playerMap = new Map<string, QueuedPlayer>();
  private roomManager: RoomManager;

  constructor(roomManager: RoomManager) {
    this.roomManager = roomManager;
  }

  /**
   * Enqueues a player for matchmaking. If an opponent is available, pairs them immediately.
   */
  public enqueue(
    player: { id: string; name: string; rating?: number },
    timeConfig: TimeConfig = DEFAULT_TIME_CONFIG
  ): { matched: boolean; match?: Match } {
    // Prevent duplicate queue entries
    if (this.playerMap.has(player.id)) {
      this.cancel(player.id);
    }

    // Try to find a match in the waiting queue with matching time config
    const matchIndex = this.queue.findIndex(
      (p) =>
        p.id !== player.id &&
        p.timeConfig.totalBankSeconds === timeConfig.totalBankSeconds &&
        p.timeConfig.turnLimitSeconds === timeConfig.turnLimitSeconds
    );

    if (matchIndex !== -1) {
      const opponent = this.queue.splice(matchIndex, 1)[0];
      this.playerMap.delete(opponent.id);

      const match = this.roomManager.createMatchFromQueue(
        { id: opponent.id, name: opponent.name },
        { id: player.id, name: player.name },
        timeConfig
      );

      return { matched: true, match };
    }

    // No opponent found yet -> add to queue
    const queuedPlayer: QueuedPlayer = {
      id: player.id,
      name: player.name,
      rating: player.rating,
      timeConfig,
      queuedAt: Date.now(),
    };

    this.queue.push(queuedPlayer);
    this.playerMap.set(player.id, queuedPlayer);

    return { matched: false };
  }

  /**
   * Cancels player's search in matchmaking queue.
   */
  public cancel(playerId: string): boolean {
    if (!this.playerMap.has(playerId)) {
      return false;
    }

    this.playerMap.delete(playerId);
    const idx = this.queue.findIndex((p) => p.id === playerId);
    if (idx !== -1) {
      this.queue.splice(idx, 1);
      return true;
    }
    return false;
  }

  public isInQueue(playerId: string): boolean {
    return this.playerMap.has(playerId);
  }

  public getQueueSize(): number {
    return this.queue.length;
  }

  public clear(): void {
    this.queue = [];
    this.playerMap.clear();
  }
}
