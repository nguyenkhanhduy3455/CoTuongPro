import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { MatchmakingQueue } from '../src/matchmaking/queue.js';
import { RoomManager } from '../src/rooms/room-manager.js';

describe('Matchmaking Queue', () => {
  let roomManager: RoomManager;
  let queue: MatchmakingQueue;

  beforeEach(() => {
    roomManager = new RoomManager();
    queue = new MatchmakingQueue(roomManager);
  });

  afterEach(() => {
    roomManager.cleanUp();
    queue.clear();
  });

  it('queues a player when no opponents are available', () => {
    const res = queue.enqueue({ id: 'p1', name: 'Alice' });
    expect(res.matched).toBe(false);
    expect(queue.getQueueSize()).toBe(1);
    expect(queue.isInQueue('p1')).toBe(true);
  });

  it('matches two waiting players atomically', () => {
    const res1 = queue.enqueue({ id: 'p1', name: 'Alice' });
    expect(res1.matched).toBe(false);

    const res2 = queue.enqueue({ id: 'p2', name: 'Bob' });
    expect(res2.matched).toBe(true);
    expect(res2.match).toBeDefined();
    expect(res2.match?.status).toBe('PLAYING');
    expect(queue.getQueueSize()).toBe(0);

    const playerIds = [res2.match?.redPlayer.id, res2.match?.blackPlayer.id];
    expect(playerIds).toContain('p1');
    expect(playerIds).toContain('p2');
  });

  it('cancels matchmaking search when requested', () => {
    queue.enqueue({ id: 'p1', name: 'Alice' });
    expect(queue.isInQueue('p1')).toBe(true);

    const cancelled = queue.cancel('p1');
    expect(cancelled).toBe(true);
    expect(queue.isInQueue('p1')).toBe(false);
    expect(queue.getQueueSize()).toBe(0);
  });
});
