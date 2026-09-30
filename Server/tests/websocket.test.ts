import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../src/index.js';
import WebSocket from 'ws';

describe('WebSocket Integration Tests', () => {
  let serverInstance: ReturnType<typeof buildServer>;
  let serverPort: number;

  beforeAll(async () => {
    serverInstance = buildServer();
    await serverInstance.server.listen({ port: 0, host: '127.0.0.1' });
    const addr = serverInstance.server.server.address();
    serverPort = typeof addr === 'object' && addr ? addr.port : 8080;
  });

  afterAll(async () => {
    serverInstance.roomManager.cleanUp();
    await serverInstance.server.close();
  });

  function createClient(playerId: string, name: string): Promise<{
    ws: WebSocket;
    messages: any[];
    waitForEvent: (eventName: string, timeoutMs?: number) => Promise<any>;
  }> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(
        `ws://127.0.0.1:${serverPort}/ws?playerId=${playerId}&name=${name}`
      );
      const messages: any[] = [];

      ws.on('message', (data) => {
        try {
          messages.push(JSON.parse(data.toString()));
        } catch {}
      });

      const waitForEvent = (eventName: string, timeoutMs = 2000): Promise<any> => {
        return new Promise((res, rej) => {
          const check = () => {
            const found = messages.find((m) => m.event === eventName);
            if (found) return res(found);
            return null;
          };

          if (check()) return;

          const interval = setInterval(() => {
            const found = check();
            if (found) {
              clearInterval(interval);
              clearTimeout(timer);
            }
          }, 20);

          const timer = setTimeout(() => {
            clearInterval(interval);
            rej(new Error(`Timeout waiting for event: ${eventName}`));
          }, timeoutMs);
        });
      };

      ws.on('open', () => {
        resolve({ ws, messages, waitForEvent });
      });

      ws.on('error', reject);
    });
  }

  it('connects to WebSocket and receives CONNECTED event', async () => {
    const client = await createClient('user_1', 'PlayerOne');
    const msg = await client.waitForEvent('CONNECTED');

    expect(msg.event).toBe('CONNECTED');
    expect(msg.payload.playerId).toBe('user_1');
    client.ws.close();
  });

  it('handles custom room creation and opponent joining via PIN code', async () => {
    const client1 = await createClient('user_p1', 'Alice');
    await client1.waitForEvent('CONNECTED');

    // Alice creates room
    client1.ws.send(JSON.stringify({ action: 'ROOM_CREATE', name: 'Alice' }));
    const createdMsg = await client1.waitForEvent('ROOM_CREATED');
    const roomCode = createdMsg.payload.roomCode;
    expect(roomCode).toHaveLength(6);

    // Bob joins room
    const client2 = await createClient('user_p2', 'Bob');
    await client2.waitForEvent('CONNECTED');

    client2.ws.send(JSON.stringify({ action: 'ROOM_JOIN', roomCode, name: 'Bob' }));
    const joinMsg = await client2.waitForEvent('ROOM_JOINED');
    expect(joinMsg.payload.role).toBe('PLAYER');

    // Both should receive MATCH_FOUND
    const matchFound1 = await client1.waitForEvent('MATCH_FOUND');
    const matchFound2 = await client2.waitForEvent('MATCH_FOUND');

    expect(matchFound1.payload.matchId).toBe(matchFound2.payload.matchId);
    expect(matchFound1.payload.roomCode).toBe(roomCode);

    // Test moving pieces: identify who is RED
    const redClient = matchFound1.payload.role === 'RED' ? client1 : client2;
    const matchId = matchFound1.payload.matchId;

    // Red moves Cannon b2 -> e2 (1,2 -> 4,2)
    redClient.ws.send(
      JSON.stringify({
        action: 'MAKE_MOVE',
        matchId,
        from: [1, 2],
        to: [4, 2],
      })
    );

    const moveMsg = await client1.waitForEvent('MOVE_APPLIED');
    expect(moveMsg.payload.uci).toBe('b2e2');
    expect(moveMsg.payload.nextTurn).toBe('BLACK');

    client1.ws.close();
    client2.ws.close();
  });
});
