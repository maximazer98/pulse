# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Pulse is a Flutter mobile game built on the [Flame](https://pub.dev/packages/flame) 2D game engine. The player controls a glowing ball that must pass through gaps in descending bars. High scores persist via `shared_preferences`.

Dart SDK: `^3.11.5`. Key deps: `flame ^1.37.0`, `shared_preferences ^2.5.5`, `flutter_lints ^6.0.0`.

## Commands

```bash
flutter pub get                      # install deps
flutter run                          # run on attached device/emulator
flutter run -d chrome                # run web build
flutter analyze                      # static analysis / lints
flutter test                         # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter test --name "substring"      # run tests whose name matches
flutter build apk | ios | web | windows
```

## Architecture

All game code currently lives in a single file: `lib/main.dart`.

- `GameApp` (StatelessWidget) hosts a `GameWidget(game: PulseGame())`.
- `PulseGame extends FlameGame with TapCallbacks, PanDetector` is the root of the game world and owns all state (score, best score, speeds, game state machine).
- `GameState { waiting, playing, gameOver }` drives input handling in `onTapDown` / `onPanStart` / `onPanUpdate` and the main `update(dt)` loop — `update` is a no-op outside `playing`.
- Obstacles are pairs of `RectangleComponent`s (left/right bars separated by a gap), each with an attached `ObstacleMover` child component. `ObstacleMover` is the behavioral "system" — it handles vertical movement, horizontal sway (enabled once `score >= 8`), fade-in at the top, scoring when the bar passes the ball, AABB-style collision against the ball, and self-removal off-screen.
- Scoring: normal pass `+1`; "close call" (ball within 5px of gap edge) `+2` and spawns a `ClosseCallText` + extra `ScorePulse`. Difficulty ramps via `obstacleSpeed = 200 + score * 3.5` and `spawnInterval = (1.8 - score * 0.02).clamp(0.95, 1.8)`.
- Visual-only components: `BackgroundStar` (parallax, speed scales with `obstacleSpeed`), `ScorePulse` (expanding ring on score), `ClosseCallText` (floating "+2 CLOSE!" label), `ParticleDot` (game-over burst). These manage their own lifetime via a `life` field and `removeFromParent()`.
- Trail effect: `trailDots` is a fixed list of 8 `CircleComponent`s updated each frame by shifting positions down the list (index 0 = ball position).
- Best score is read in `onLoad` from `SharedPreferences` key `bestScore` and written on game over when beaten.
- Restart (`_restartGame`) sweeps leftover obstacles and particles via `removeWhere((c) => c is RectangleComponent || c is ParticleDot)` — any new persistent component types must be excluded from that predicate or they'll be destroyed on restart.

UI text is in German (e.g. "Finger ziehen zum Spielen", "Bestleistung", "Tippen zum Neustart").

## Lints

`analysis_options.yaml` uses `package:flutter_lints/flutter.yaml`. Run `flutter analyze` before considering changes done.
