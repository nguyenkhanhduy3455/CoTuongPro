import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { RoomManager } from '../src/rooms/room-manager.js';

describe('Room & Match Manager', () => {
  let roomManager: RoomManager;

  beforeEach(() => {
    vi.useFakeTimers();
    roomManager = new RoomManager();
  });

  afterEach(() => {
    roomManager.cleanUp();
    vi.useRealTimers();
  });

  describe('Custom Room PIN Workflow', () => {
    it('creates a custom room with a 6-character code', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice');
      expect(room.roomCode).toHaveLength(6);
      expect(room.isCustom).toBe(true);
      expect(room.status).toBe('WAITING');
      expect(room.players.size).toBe(1);
    });

    it('joins custom room and starts match when player 2 connects', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice');
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');

      expect(joinRes.role).toBe('PLAYER');
      expect(joinRes.room.status).toBe('PLAYING');
      expect(joinRes.match).toBeDefined();
      expect(joinRes.match?.status).toBe('PLAYING');
      expect(joinRes.match?.redPlayer).toBeDefined();
      expect(joinRes.match?.blackPlayer).toBeDefined();
    });

    it('adds extra joiners as spectators when room already has 2 players', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice');
      roomManager.joinRoom(room.roomCode, 'p2', 'Bob');

      const specJoin = roomManager.joinRoom(room.roomCode, 'p3', 'Charlie');
      expect(specJoin.role).toBe('SPECTATOR');
      expect(room.spectators.size).toBe(1);
      expect(room.spectators.get('p3')?.name).toBe('Charlie');
    });
  });

  describe('Move Application & Game State', () => {
    it('allows red player to make initial move', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice');
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');
      const match = joinRes.match!;

      const redPlayer = match.redPlayer;
      // Standard opening move: Red Cannon b2 -> e2 (from [1,2] to [4,2])
      const res = roomManager.makeMove(match.id, redPlayer.id, {
        from: [1, 2],
        to: [4, 2],
      });

      expect(res.success).toBe(true);
      expect(match.board.getTurn()).toBe('BLACK');
    });

    it('rejects move if made out of turn', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice');
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');
      const match = joinRes.match!;

      const blackPlayer = match.blackPlayer;
      // Black attempts to move first -> rejected
      const res = roomManager.makeMove(match.id, blackPlayer.id, {
        from: [1, 7],
        to: [4, 7],
      });

      expect(res.success).toBe(false);
      expect(res.error).toContain('Not your turn');
    });
  });

  describe('Turn Timers & Timeouts', () => {
    it('triggers timeout and awards win to opponent when turn clock expires', () => {
      let overWinner = '';
      let overReason = '';

      roomManager.setEvents({
        onMatchOver: (_m, winner, reason) => {
          overWinner = winner;
          overReason = reason;
        },
      });

      const room = roomManager.createCustomRoom('p1', 'Alice', {
        totalBankSeconds: 600,
        turnLimitSeconds: 30,
      });
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');
      const match = joinRes.match!;

      // Advance time by 30 seconds
      vi.advanceTimersByTime(30000);

      expect(match.status).toBe('FINISHED');
      expect(overReason).toBe('TIMEOUT');
      expect(overWinner).toBe('BLACK'); // Red timed out on move 1
    });
  });

  describe('Disconnection & Reconnection Grace Period', () => {
    it('starts 60s grace period and forfeits match if disconnected player does not return', () => {
      let overReason = '';
      roomManager.setEvents({
        onMatchOver: (_m, _w, reason) => {
          overReason = reason;
        },
      });

      const room = roomManager.createCustomRoom('p1', 'Alice', {
        totalBankSeconds: 600,
        turnLimitSeconds: 300,
      });
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');
      const match = joinRes.match!;

      // Alice disconnects
      roomManager.handlePlayerDisconnect('p1');
      expect(match.status).toBe('PLAYING');

      // Fast forward 61 seconds
      vi.advanceTimersByTime(61000);

      expect(match.status).toBe('FINISHED');
      expect(overReason).toBe('DISCONNECT_TIMEOUT');
    });

    it('cancels grace period when player reconnects within 60s', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice', {
        totalBankSeconds: 600,
        turnLimitSeconds: 300,
      });
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');
      const match = joinRes.match!;

      roomManager.handlePlayerDisconnect('p1');

      // 20 seconds later Alice reconnects
      vi.advanceTimersByTime(20000);
      const reconnectedMatch = roomManager.handlePlayerReconnect('p1');
      expect(reconnectedMatch).toBeDefined();
      expect(match.status).toBe('PLAYING');

      // Advance another 50s (total 70s since first disconnect) -> match should STILL be playing
      vi.advanceTimersByTime(50000);
      expect(match.status).toBe('PLAYING');
    });
  });

  describe('Resignation & Draw Offers', () => {
    it('handles player resignation cleanly', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice');
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');
      const match = joinRes.match!;

      const res = roomManager.resign(match.id, match.redPlayer.id);
      expect(res.success).toBe(true);
      expect(match.status).toBe('FINISHED');
      expect(match.winner).toBe('BLACK');
      expect(match.winReason).toBe('RESIGN');
    });

    it('handles draw offer and acceptance', () => {
      const room = roomManager.createCustomRoom('p1', 'Alice');
      const joinRes = roomManager.joinRoom(room.roomCode, 'p2', 'Bob');
      const match = joinRes.match!;

      roomManager.offerDraw(match.id, match.redPlayer.id);
      expect(match.drawOfferFrom).toBe('RED');

      const acceptRes = roomManager.respondDraw(match.id, match.blackPlayer.id, true);
      expect(acceptRes.success).toBe(true);
      expect(match.status).toBe('FINISHED');
      expect(match.winner).toBe('DRAW');
      expect(match.winReason).toBe('DRAW_AGREED');
    });
  });
});
