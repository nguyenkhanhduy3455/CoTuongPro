# Cờ Tướng Pro - Real-time Xiangqi Game Server

A production-ready, clean-architecture real-time Chinese Chess (Xiangqi / Cờ Tướng) server built with **Node.js (v20+)**, **Fastify**, **TypeScript**, and **WebSockets**.

---

## 🏗️ Architecture Overview

The system is organized following Clean Architecture principles:

```
server/
├── src/
│   ├── engine/           # Full Xiangqi rules, move generator, check/checkmate/stalemate engine
│   │   ├── types.ts      # Domain types (Piece, Move, Position, GameStatus)
│   │   ├── constants.ts  # Board boundaries, Palace, River, Initial FEN
│   │   ├── uci.ts        # UCI coordinate converter (e.g. b2e2 <-> [1,2] -> [4,2])
│   │   ├── board.ts      # Immutable XiangqiBoard, move validation & state
│   │   └── index.ts
│   ├── rooms/            # Room, Match & Clock state machine
│   │   ├── types.ts      # Match, Room, TimeConfig, Player, Spectator types
│   │   ├── clock-manager.ts # Dual timer: Total bank (e.g. 10m) + Turn timer (e.g. 30s)
│   │   ├── room-manager.ts  # PIN-based custom rooms, matches, 60s disconnect grace period
│   │   └── index.ts
│   ├── matchmaking/      # Matchmaking Queue
│   │   ├── queue.ts      # Atomic queueing, matching, color randomization
│   │   └── index.ts
│   ├── storage/          # Storage abstraction (Redis-ready)
│   │   ├── types.ts      # IStateStore interface
│   │   ├── memory-store.ts # In-memory Map implementation with async signature
│   │   └── index.ts
│   ├── ws/               # WebSocket Server & Protocol Handlers
│   │   ├── protocol.ts   # Zod validation schemas for all Client Actions & Server Events
│   │   ├── connection.ts # Socket manager, heartbeats, multicasting & broadcasting
│   │   ├── handler.ts    # Action dispatcher & event emitter
│   │   └── index.ts
│   └── index.ts          # Fastify bootstrap, WebSocket route mounting, graceful shutdown
├── tests/                # Comprehensive Vitest test suite
│   ├── engine.test.ts    # Xiangqi rules: Horse blocks, Cannon screens, Flying General, etc.
│   ├── rooms.test.ts     # Room lifecycle, Timers, Resignation, Disconnect grace period
│   ├── matchmaking.test.ts # Matchmaking queueing and pairing
│   └── websocket.test.ts # End-to-end WebSocket client-server flows
├── package.json
└── tsconfig.json
```

---

## 🎯 Xiangqi Rules Engine Features

1. **Board Representation**: 9x10 grid (columns 0..8 / a..i, rows 0..9 / 0..9).
2. **Piece-Level Validation**:
   - **King / General (Tướng/Soái)**: 1 orthogonal step, restricted to 3x3 palace (x: 3..5, y: 0..2 for Red, 7..9 for Black).
   - **Advisor (Sĩ)**: 1 diagonal step, restricted to 3x3 palace.
   - **Elephant (Tượng)**: 2 diagonal steps, cannot cross the River, eye obstruction (*cản tượng*) check.
   - **Horse (Mã)**: L-shaped moves with foot obstruction (*cản chân mã*) check.
   - **Rook (Xe)**: Orthogonal line movement with 0 intervening pieces.
   - **Cannon (Pháo)**: Moves like Rook with 0 pieces; captures only by jumping over **exactly 1 screen piece** (*ngòi*).
   - **Pawn (Tốt/Chốt)**: Moves 1 step forward before River; gains 1-step sideways moves after crossing the River. Never moves backward.
3. **Flying General Rule (Lộ mặt tướng)**: Kings cannot face each other on the same column without pieces between them. Any move resulting in facing kings is rejected as illegal self-check.
4. **Game End Detection**:
   - **Check (Chiếu)**: King under threat.
   - **Checkmate (Chiếu bí)**: Checked player has 0 legal moves (Loss).
   - **Stalemate (Hết nước đi / Buột)**: Player with no legal moves loses (Xiangqi rule).
5. **UCI Format**: Standard UCI strings (e.g. `b2e2` for Red Cannon opening move).

---

## ⏱️ Matchmaking, Timers & Disconnection Grace Period

- **Random Matchmaking**: Pairs waiting players, randomizes Red/Black, starts clocks.
- **Custom Room with PIN**: Generates 6-character alphanumeric room codes (`ROOM_CREATE` / `ROOM_JOIN`).
- **Spectator Support**: 3rd+ joiners automatically spectate the active match with real-time state broadcasts.
- **Dual Timer Clock**:
  - `totalBankSeconds` (e.g. 600s / 10m).
  - `turnLimitSeconds` (e.g. 30s per turn).
  - Automatically awards victory on timeout.
- **60-Second Network Grace Period**:
  - When a player drops connection, a 60-second grace timer is initiated.
  - Opponent is notified via `OPPONENT_STATUS { status: "DISCONNECTED", gracePeriodSeconds: 60 }`.
  - If reconnected within 60s (`RECONNECT`), state is restored and `OPPONENT_STATUS { status: "RECONNECTED" }` is sent.
  - If 60s expires without return, the disconnected player forfeits (`DISCONNECT_TIMEOUT`).

---

## 📡 WebSocket Protocol

Endpoint: `ws://localhost:8080/ws?playerId={id}&name={name}`

### Client -> Server Actions

```json
// Find match in queue
{ "action": "QUEUE_FIND_MATCH", "name": "Alice", "timeConfig": { "totalBankSeconds": 600, "turnLimitSeconds": 30 } }

// Cancel queue
{ "action": "QUEUE_CANCEL" }

// Create custom room
{ "action": "ROOM_CREATE", "name": "Alice" }

// Join room by code
{ "action": "ROOM_JOIN", "roomCode": "K8X9Y2", "name": "Bob" }

// Make move
{ "action": "MAKE_MOVE", "matchId": "match_123", "from": [1, 2], "to": [4, 2] }

// Resign
{ "action": "RESIGN", "matchId": "match_123" }

// Offer / Respond Draw
{ "action": "OFFER_DRAW", "matchId": "match_123" }
{ "action": "RESPOND_DRAW", "matchId": "match_123", "accepted": true }

// Reconnect
{ "action": "RECONNECT", "playerId": "user_123" }
```

### Server -> Client Events

- `CONNECTED`: `{ "playerId": "user_123", "name": "Alice" }`
- `ROOM_CREATED`: `{ "roomCode": "K8X9Y2", "isCustom": true }`
- `ROOM_JOINED`: `{ "roomCode": "K8X9Y2", "role": "PLAYER" | "SPECTATOR" }`
- `MATCH_FOUND`: `{ "matchId": "m_1", "role": "RED", "opponentName": "Bob", "fen": "...", "timeConfig": {...} }`
- `MOVE_APPLIED`: `{ "from": [1,2], "to": [4,2], "uci": "b2e2", "isCheck": false, "isCheckmate": false, "nextTurn": "BLACK", "timeRemaining": {...} }`
- `MATCH_OVER`: `{ "winner": "RED", "reason": "CHECKMATE" }`
- `OPPONENT_STATUS`: `{ "status": "DISCONNECTED", "gracePeriodSeconds": 60 }`

---

## 🚀 Getting Started

### 1. Install Dependencies
```bash
cd server
npm install
```

### 2. Run Test Suite
```bash
npm test
```

### 3. Start Development Server
```bash
npm run dev
```

### 4. Build for Production
```bash
npm run build
npm start
```
