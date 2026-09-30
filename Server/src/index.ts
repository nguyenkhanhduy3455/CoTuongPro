/**
 * Real-time Chinese Chess (Xiangqi / Cờ Tướng) Game Server.
 * Built with Fastify, @fastify/websocket, TypeScript, and Clean Architecture.
 */

import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
import { randomUUID } from 'crypto';
import Fastify, { FastifyInstance } from 'fastify';
import { MatchmakingQueue } from './matchmaking/queue.js';
import { RoomManager } from './rooms/room-manager.js';
import { WebSocketHandler } from './ws/handler.js';

export function buildServer(): {
  server: FastifyInstance;
  roomManager: RoomManager;
  queue: MatchmakingQueue;
  wsHandler: WebSocketHandler;
} {
  const server = Fastify({
    logger: {
      level: process.env.LOG_LEVEL || 'info',
    },
  });

  const roomManager = new RoomManager();
  const queue = new MatchmakingQueue(roomManager);
  const wsHandler = new WebSocketHandler(roomManager, queue);

  // Register plugins
  server.register(cors, {
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
  });

  server.register(websocket);

  // Health check endpoint
  server.get('/health', async () => {
    return {
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    };
  });

  // Server stats endpoint
  server.get('/api/stats', async () => {
    return {
      matchmakingQueueSize: queue.getQueueSize(),
      timestamp: Date.now(),
    };
  });

  // WebSocket connection endpoint
  server.register(async (app) => {
    app.get('/ws', { websocket: true }, (socket, req) => {
      const query = (req.query as Record<string, string>) || {};
      const playerId = query.playerId || query.id || randomUUID();
      const name = query.name || `Player_${playerId.slice(0, 5)}`;

      console.log(`[WS-SERVER] Incoming connection: playerId=${playerId}, name=${name}, IP=${req.ip}`);
      wsHandler.handleConnection(socket, playerId, name);

      socket.on('message', async (data: Buffer | string) => {
        console.log(`[WS-SERVER] Message from ${playerId}: ${data.toString()}`);
        await wsHandler.handleMessage(socket, data);
      });

      socket.on('close', (code, reason) => {
        console.log(`[WS-SERVER] Disconnected: playerId=${playerId}, code=${code}, reason=${reason}`);
        wsHandler.handleDisconnection(socket);
      });

      socket.on('error', (err) => {
        console.error(`[WS-SERVER] Error for ${playerId}:`, err);
        req.log.error({ err, playerId }, 'WebSocket client error');
        wsHandler.handleDisconnection(socket);
      });
    });
  });

  return { server, roomManager, queue, wsHandler };
}

async function start() {
  const { server, roomManager } = buildServer();
  const port = parseInt(process.env.PORT || '8080', 10);
  const host = process.env.HOST || '0.0.0.0';

  const gracefulShutdown = async (signal: string) => {
    server.log.info(`Received ${signal}, shutting down gracefully...`);
    roomManager.cleanUp();
    await server.close();
    process.exit(0);
  };

  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

  try {
    await server.listen({ port, host });
    server.log.info(`Xiangqi Real-time Game Server listening at http://${host}:${port}`);
    server.log.info(`WebSocket endpoint available at ws://${host}:${port}/ws`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
}

// Start if executed directly
if (process.env.NODE_ENV !== 'test' && !process.env.VITEST) {
  start();
}
