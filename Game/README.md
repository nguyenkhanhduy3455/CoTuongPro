# Cờ Tướng Pro - Godot 4.x Client (Android & Cross-Platform)

A production-ready, modular, responsive 2D Chinese Chess (Xiangqi / Cờ Tướng) client built in **Godot 4.3 (GDScript)**, optimized for Android touch input, multi-resolution screens, notch safe areas, and portrait/landscape responsive layouts.

---

## 📁 Architecture & File Layout

```
Game/ (and client/)
├── project.godot            # Godot 4 project configuration (Mobile renderer, portrait/expand stretch, Autoloads)
├── icon.svg                 # Project app icon
├── assets/
│   ├── videos/              # .ogv cutscene clips (cannon_barrage, cavalry_charge, checkmate, etc.)
│   ├── sprites/             # UI and board textures
│   └── audio/               # Combat sound effects & BGM
├── scenes/
│   ├── Main.tscn            # Root container managing transitions between all views
│   ├── MainMenu.tscn        # Play PvE (AI), Play Online Queue, PIN Room modal, Settings
│   ├── MatchmakingLobby.tscn# Queue searching spinner & 6-character PIN display
│   ├── GameView.tscn        # In-game HUD (timers, avatars), BoardContainer, Resign/Draw controls
│   ├── CutsceneOverlay.tscn # VideoStreamPlayer + Procedural shake/flash strike fallback
│   └── SettingsDialog.tscn  # Difficulty (Easy/Medium/Hard), Cutscene mode, Server URL
└── scripts/
    ├── engine/
    │   ├── xiangqi_types.gd     # Domain types (PieceType, PieceColor, Move, GameStatus, MoveResult)
    │   ├── xiangqi_constants.gd # Boundaries, Palace, River, UCI converters
    │   └── xiangqi_board.gd     # Full Xiangqi rule validation, legality, Flying General rule
    ├── ai/
    │   ├── ai_evaluator.gd      # Piece-Square Tables (PST) & positional evaluation heuristics
    │   └── ai_engine.gd         # Threaded Minimax + Alpha-Beta Pruning + MVV-LVA move ordering
    ├── network/
    │   └── (integrated in Autoload NetworkManager with WebSocketPeer)
    ├── cinematics/
    │   └── (handled by CutsceneManager & CutsceneOverlay)
    ├── ui/
    │   ├── main.gd              # Top-level screen coordinator
    │   ├── main_menu.gd         # Main Menu actions
    │   ├── matchmaking_lobby.gd # Queue and PIN room waiting view
    │   ├── game_view.gd         # PvE and PvP Game controller
    │   ├── board_view.gd        # 2D grid rendering, touch/drag input, move highlights
    │   ├── piece_view.gd        # Procedural wooden token rendering with tween animations
    │   ├── settings_dialog.gd   # User settings dialog
    │   └── cutscene_overlay.gd  # Video playback and procedural screen-shake fallback
    └── autoload/
        ├── game_config.gd       # ConfigFile user settings persistence (`user://settings.cfg`)
        ├── network_manager.gd   # WebSocketPeer client with auto-reconnect & JSON protocol
        └── cutscene_manager.gd  # Event triggers for combat cutscenes
```

---

## 🎮 Key Features & Mechanics

### 1. Interactive 2D Board & Touch Input
- **Procedural 9x10 Xiangqi Board**: Traditional river markings (*"SỞ HÀ (楚河) - HÁN GIỚI (漢界)"*), palace diagonals, and intersection markers.
- **Dynamic Mobile Sizing**: Cell sizing and board offset calculate dynamically on screen resize to fit any Android device resolution and aspect ratio.
- **Touch & Tap Controls**: Tap-to-select, legal move highlight dots, capture indicator rings, red check pulse highlight.
- **Orientation Flipping**: Automatically orients Black at bottom when playing as Black.

### 2. Multi-Difficulty AI Engine (Threaded)
- **Zero UI Frame Drops**: AI computation executes in a background `Thread` (`start_calculation_threaded`), maintaining smooth 60/120 FPS animations on mobile.
- **Difficulties**:
  - **Easy (Dễ)**: Depth 1-2 with 25% randomized moves for casual players.
  - **Medium (Trung bình)**: Depth 3-4 with standard Alpha-Beta pruning and Piece-Square Table (PST) positional heuristics.
  - **Hard (Khó)**: Depth 4-5 with Iterative Deepening, MVV-LVA move ordering, and Quiescence search on capture sequences.

### 3. Real-Time Online Multiplayer (WebSocketPeer)
- Communicates directly with the Fastify WebSocket server (`ws://127.0.0.1:8080/ws`).
- **Matchmaking Queue**: `find_match` -> `QUEUE_JOINED` -> `MATCH_FOUND`.
- **Custom PIN Rooms**: `create_custom_room` -> generates 6-character code -> opponent joins with code.
- **Network Resilience**: Automatically detects disconnection and sends `RECONNECT` session restore during the 60s grace period.

### 4. Cinematic Battle Cutscenes & Procedural Fallbacks
- Plays short 1-3 second `.ogv` cinematic video clips using `VideoStreamPlayer` over the board:
  - **Cannon Barrage**: Cannon capturing Pawns or pieces.
  - **Cavalry Charge**: Horse/Rook captures.
  - **Shield Defense**: Advisor blocking an active check.
  - **Dramatic General Zoom / Checkmate**: When check/checkmate is delivered.
- **Procedural Fallback**: If `.ogv` assets are not loaded, triggers dynamic screen shake, color flash, and combat impact text overlays.
- **UX Controls**:
  - Instant touch-to-skip (`_gui_input`).
  - Configurable in Settings: **"All Cutscenes"**, **"Decisive Moves Only"**, or **"Disabled"**.

---

## 📱 Android Mobile Export

1. Open the project in Godot 4.3+.
2. Configure **Project Settings** -> **Display** -> **Window**:
   - Viewport Width: `720`, Height: `1280`
   - Stretch Mode: `canvas_items`, Aspect: `expand`
   - Handheld Orientation: `Portrait` / `Sensor`
3. Export to Android APK using Godot's standard Android Export Preset.
