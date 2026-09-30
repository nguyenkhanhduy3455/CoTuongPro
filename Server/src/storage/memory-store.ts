/**
 * In-memory implementation of IStateStore.
 * Provides async Map-based store with exact Redis-compatible signatures.
 */

import { IStateStore, PlayerSession, StoredMatch, StoredRoom } from './types.js';

export class MemoryStateStore implements IStateStore {
  private sessions = new Map<string, PlayerSession>();
  private rooms = new Map<string, StoredRoom>();
  private matches = new Map<string, StoredMatch>();

  async saveSession(session: PlayerSession): Promise<void> {
    this.sessions.set(session.id, { ...session });
  }

  async getSession(playerId: string): Promise<PlayerSession | null> {
    const s = this.sessions.get(playerId);
    return s ? { ...s } : null;
  }

  async deleteSession(playerId: string): Promise<void> {
    this.sessions.delete(playerId);
  }

  async saveRoom(room: StoredRoom): Promise<void> {
    this.rooms.set(room.code, {
      ...room,
      playerIds: [...room.playerIds],
      spectatorIds: [...room.spectatorIds],
    });
  }

  async getRoom(roomCode: string): Promise<StoredRoom | null> {
    const r = this.rooms.get(roomCode);
    if (!r) return null;
    return {
      ...r,
      playerIds: [...r.playerIds],
      spectatorIds: [...r.spectatorIds],
    };
  }

  async deleteRoom(roomCode: string): Promise<void> {
    this.rooms.delete(roomCode);
  }

  async saveMatch(match: StoredMatch): Promise<void> {
    this.matches.set(match.id, {
      ...match,
      history: match.history.map((m) => ({ ...m })),
    });
  }

  async getMatch(matchId: string): Promise<StoredMatch | null> {
    const m = this.matches.get(matchId);
    if (!m) return null;
    return {
      ...m,
      history: m.history.map((h) => ({ ...h })),
    };
  }

  async deleteMatch(matchId: string): Promise<void> {
    this.matches.delete(matchId);
  }
}
