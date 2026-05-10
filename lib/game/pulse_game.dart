import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import '../services/audio.dart';
import '../services/haptics.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import 'achievements.dart';
import 'daily.dart';
import 'effects.dart';
import 'obstacle.dart';
import 'skins.dart';

enum GameMode { classic, zen, hardcore, daily }

extension GameModeX on GameMode {
  String get id => toString().split('.').last;
  String get label {
    switch (this) {
      case GameMode.classic: return 'CLASSIC';
      case GameMode.zen: return 'ZEN';
      case GameMode.hardcore: return 'HARDCORE';
      case GameMode.daily: return 'DAILY';
    }
  }
  String get description {
    switch (this) {
      case GameMode.classic: return L10n.t('Der klassische Run', 'The classic run');
      case GameMode.zen: return L10n.t('Entspannt, kein Game Over', 'Relaxed, no game over');
      case GameMode.hardcore: return L10n.t('Ab Sekunde eins am Limit', 'At the limit from second one');
      case GameMode.daily: return L10n.t('Heutige Challenge — gleicher Seed für alle', "Today's challenge — same seed for all");
    }
  }
}

enum GameState { menu, playing, gameOver }

class PulseGame extends FlameGame with TapCallbacks, PanDetector {
  late CircleComponent ball;
  late CircleComponent ballHalo;
  late List<CircleComponent> trailDots = [];

  double targetX = 0;
  double ballY = 0;
  double followSpeed = 10;

  double obstacleSpeed = 200;
  double timeSinceLastObstacle = 0;
  double spawnInterval = 1.6;
  int score = 0;
  int runCloseCalls = 0;
  Map<GameMode, int> bestScores = {};
  GameState _gameState = GameState.menu;
  GameState get gameState => _gameState;
  set gameState(GameState v) {
    _gameState = v;
    stateNotifier.value = v;
  }
  final ValueNotifier<GameState> stateNotifier = ValueNotifier(GameState.menu);
  GameMode mode = GameMode.classic;

  late TextComponent scoreText;

  Random random = Random();
  int dailyBest = 0;
  DateTime _today = DateTime.now();
  final double gapSize = 140;
  final double barHeight = 16;

  final Color neonBlue = const Color(0xFF00C8FF);
  final Color neonPink = const Color(0xFFFF2D87);

  int get bestScore => mode == GameMode.daily ? dailyBest : (bestScores[mode] ?? 0);
  bool get isZen => mode == GameMode.zen;

  DailyModifier get todayModifier => modifierFor(DateTime.now());
  Medal get dailyMedal => medalFor(dailyBest, todayModifier);

  int _dailySeed(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  @override
  Color backgroundColor() => const Color(0xFF0A0A1A);

  @override
  Future<void> onLoad() async {
    targetX = size.x / 2;
    ballY = size.y * 0.65;

    for (final m in GameMode.values) {
      if (m == GameMode.daily) continue;
      bestScores[m] = await Storage.loadBest(m.id);
    }
    _today = DateTime.now();
    dailyBest = await Storage.loadDailyBest(_today);
    await AudioService.init();
    await Achievements.init();
    await Wallet.init();
    await Skins.init();
    await PowerUps.init();
    _hintShown = await Storage.loadBool('hint_shown');
    Skins.equippedId.addListener(_applySkin);

    add(GradientBackdrop(game: this));
    _addBackgroundStars();

    ballHalo = CircleComponent(
      radius: 30,
      position: Vector2(size.x / 2, ballY),
      paint: Paint()
        ..color = const Color(0xFF00C8FF).withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      anchor: Anchor.center,
      priority: -1,
    );
    add(ballHalo);

    _addTrail();

    ball = CircleComponent(
      radius: 16,
      position: Vector2(size.x / 2, ballY),
      paint: Paint()
        ..color = const Color(0xFFFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      anchor: Anchor.center,
    );
    add(ball);

    scoreText = TextComponent(
      text: '0',
      position: Vector2(size.x / 2, 110),
      anchor: Anchor.center,
      priority: 100,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 52,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );

    overlays.add('menu');
    _applySkin();
  }

  double _skinTime = 0;
  double _fxAccum = 0;

  int closeCallStreak = 0;
  double multiplierTimer = 0;
  final ValueNotifier<double> multiplierRemaining = ValueNotifier(0);
  bool get multiplierActive => multiplierTimer > 0;

  bool _hintShown = true;
  final ValueNotifier<bool> hintNotifier = ValueNotifier(false);

  bool _continueUsed = false;
  bool _invincible = false;
  double _invincibleTimer = 0.0;
  bool _shieldActive = false;
  final ValueNotifier<bool> shieldActiveNotifier = ValueNotifier(false);

  bool get canContinue => !_continueUsed && Wallet.value >= 50;

  void _applySkin() {
    final skin = Skins.equipped;
    final ballColor = skin.rainbow
        ? HSVColor.fromAHSV(1, (_skinTime * 60) % 360, 1, 1).toColor()
        : skin.ballColor;
    ball.paint.color = ballColor;
    ballHalo.paint.color = (skin.rainbow ? ballColor : skin.trailColor).withAlpha(90);
    for (int i = 0; i < trailDots.length; i++) {
      final baseAlpha = ((1 - i / trailDots.length) * 120).toInt();
      final c = skin.rainbow
          ? HSVColor.fromAHSV(1, ((_skinTime * 60) - i * 18) % 360, 1, 1).toColor()
          : skin.trailColor;
      trailDots[i].paint.color = c.withAlpha(baseAlpha);
    }
  }

  void _addBackgroundStars() {
    for (int i = 0; i < 40; i++) {
      add(BackgroundStar(
        position: Vector2(
          random.nextDouble() * size.x,
          random.nextDouble() * size.y,
        ),
        game: this,
      ));
    }
  }

  void _addTrail() {
    for (int i = 0; i < 8; i++) {
      final dot = CircleComponent(
        radius: 10 - i * 1.0,
        position: Vector2(-100, -100),
        paint: Paint()
          ..color = const Color(0xFF00C8FF).withAlpha(((1 - i / 8) * 120).toInt()),
        anchor: Anchor.center,
      );
      trailDots.add(dot);
      add(dot);
    }
  }

  void togglePause() {
    if (gameState != GameState.playing && !paused) return;
    if (paused) {
      resumeEngine();
      overlays.remove('pause');
      AudioService.resumeMusic();
    } else {
      pauseEngine();
      overlays.add('pause');
      AudioService.pauseMusic();
    }
  }

  void startGame(GameMode m) {
    mode = m;
    gameState = GameState.playing;
    score = 0;
    runCloseCalls = 0;
    timeSinceLastObstacle = 0;
    ball.position = Vector2(targetX, ballY);
    scoreText.text = '0';
    closeCallStreak = 0;
    multiplierTimer = 0;
    multiplierRemaining.value = 0;
    _continueUsed = false;
    _invincible = false;
    _invincibleTimer = 0.0;
    _shieldActive = PowerUps.consume();
    shieldActiveNotifier.value = _shieldActive;

    switch (m) {
      case GameMode.classic:
      case GameMode.daily:
        obstacleSpeed = 200;
        spawnInterval = 1.6;
        break;
      case GameMode.zen:
        obstacleSpeed = 150;
        spawnInterval = 2.0;
        break;
      case GameMode.hardcore:
        obstacleSpeed = 260;
        spawnInterval = 1.2;
        break;
    }

    if (m == GameMode.daily) {
      _today = DateTime.now();
      random = Random(_dailySeed(_today));
      final mod = todayModifier;
      obstacleSpeed *= mod.speedMult;
      spawnInterval *= mod.spawnMult;
    } else {
      random = Random();
    }

    overlays.remove('menu');
    overlays.remove('game_over');
    if (scoreText.parent == null) add(scoreText);
    if (!_hintShown) hintNotifier.value = true;
    AudioService.playMusic();
  }

  void triggerGameOver() {
    if (gameState != GameState.playing) return;
    if (isZen) return;
    if (_invincible) return;
    if (_shieldActive) {
      _shieldActive = false;
      shieldActiveNotifier.value = false;
      _invincible = true;
      _invincibleTimer = 1.5;
      Haptics.heavy();
      return;
    }
    gameState = GameState.gameOver;
    camera.viewfinder.add(
      MoveEffect.by(
        Vector2(12, 0),
        EffectController(duration: 0.05, alternate: true, repeatCount: 6),
      ),
    );
    AudioService.stopMusic();
    AudioService.play('gameover.wav', volume: 0.7);
    Haptics.heavy();
    if (score > bestScore) {
      if (mode == GameMode.daily) {
        dailyBest = score;
        Storage.saveDailyBest(_today, score);
      } else {
        bestScores[mode] = score;
        Storage.saveBest(mode.id, score);
      }
    }
    Achievements.onGameEnded();
    Achievements.onScore(mode: mode, score: score);
    if (mode == GameMode.daily) {
      Achievements.onDailyMedal(medalFor(score, todayModifier));
    }
    if (scoreText.parent != null) remove(scoreText);
    _spawnParticles();
    overlays.add('game_over');
  }

  void useContinue() {
    if (!canContinue) return;
    Wallet.spend(50);
    _continueUsed = true;
    removeWhere((c) =>
        c is RectangleComponent ||
        c is Coin ||
        c is CoinBurst ||
        c is SkinSpark ||
        c is ScorePulse ||
        c is CloseCallText);
    timeSinceLastObstacle = 0;
    _invincible = true;
    _invincibleTimer = 3.0;
    gameState = GameState.playing;
    overlays.remove('game_over');
    if (scoreText.parent == null) add(scoreText);
  }

  void _spawnParticles() {
    for (int i = 0; i < 24; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 80 + random.nextDouble() * 220;
      add(ParticleDot(
        position: ball.position.clone(),
        velocity: Vector2(cos(angle) * speed, sin(angle) * speed),
        color: i.isEven ? neonBlue : neonPink,
      ));
    }
  }

  void backToMenu() {
    AudioService.stopMusic();
    if (paused) resumeEngine();
    // If we leave during a live run (zen quit, pause→menu), count it as ended.
    if (gameState == GameState.playing && score > 0) {
      Achievements.onGameEnded();
    }
    _invincible = false;
    _invincibleTimer = 0.0;
    _shieldActive = false;
    shieldActiveNotifier.value = false;
    removeWhere((c) =>
        c is RectangleComponent ||
        c is ParticleDot ||
        c is Coin ||
        c is CoinBurst ||
        c is SkinSpark ||
        c is ScorePulse ||
        c is CloseCallText);
    if (scoreText.parent != null) remove(scoreText);
    gameState = GameState.menu;
    overlays.remove('pause');
    overlays.remove('game_over');
    overlays.add('menu');
  }

  void retry() {
    removeWhere((c) =>
        c is RectangleComponent ||
        c is ParticleDot ||
        c is Coin ||
        c is CoinBurst ||
        c is SkinSpark ||
        c is ScorePulse ||
        c is CloseCallText);
    startGame(mode);
  }

  @override
  void onTapDown(TapDownEvent event) {
    AudioService.unlockAudio();
    if (gameState == GameState.playing) {
      targetX = event.localPosition.x;
    }
  }

  @override
  void onPanStart(DragStartInfo info) {
    AudioService.unlockAudio();
    if (gameState == GameState.playing) {
      targetX = info.eventPosition.global.x;
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (gameState == GameState.playing) {
      if (hintNotifier.value) {
        hintNotifier.value = false;
        _hintShown = true;
        Storage.saveBool('hint_shown', value: true);
      }
      targetX = info.eventPosition.global.x;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (Skins.equipped.rainbow) {
      _skinTime += dt;
      if (!_invincible) _applySkin();
    }
    if (gameState != GameState.playing) return;

    if (_invincibleTimer > 0) {
      _invincibleTimer -= dt;
      final blink = (_invincibleTimer * 8).floor().isOdd;
      ball.paint.color = blink ? Colors.white.withAlpha(80) : Skins.equipped.ballColor;
      if (_invincibleTimer <= 0) {
        _invincible = false;
        _invincibleTimer = 0.0;
        _applySkin();
      }
    }

    final clampedTarget = targetX.clamp(ball.radius, size.x - ball.radius);
    ball.position.x += (clampedTarget - ball.position.x) * followSpeed * dt;
    ball.position.y = ballY;
    ballHalo.position = ball.position;

    for (int i = trailDots.length - 1; i > 0; i--) {
      trailDots[i].position = trailDots[i - 1].position.clone();
    }
    trailDots[0].position = ball.position.clone();

    timeSinceLastObstacle += dt;
    if (timeSinceLastObstacle >= spawnInterval) {
      timeSinceLastObstacle = 0;
      _spawnObstacle();
    }

    _emitSkinFx(dt);

    if (multiplierTimer > 0) {
      multiplierTimer -= dt;
      if (multiplierTimer <= 0) {
        multiplierTimer = 0;
        multiplierRemaining.value = 0;
        _setScoreStyle(gold: false);
      } else {
        multiplierRemaining.value = multiplierTimer;
      }
    }
  }

  bool _scoreGold = false;
  void _setScoreStyle({required bool gold}) {
    if (_scoreGold == gold) return;
    _scoreGold = gold;
    scoreText.textRenderer = TextPaint(
      style: TextStyle(
        color: gold ? const Color(0xFFFFD166) : Colors.white,
        fontSize: 52,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        shadows: gold
            ? const [Shadow(color: Color(0xFFFFD166), blurRadius: 18)]
            : null,
      ),
    );
  }

  void _emitSkinFx(double dt) {
    final id = Skins.equipped.id;
    if (id == 'default') return;
    _fxAccum += dt;

    // Rate per skin (sparks per second).
    final rate = switch (id) {
      'fire' => 38.0,
      'gold' => 18.0,
      'rainbow' => 26.0,
      'cyan' => 16.0,
      'magenta' => 0.0, // handled as occasional rings
      _ => 0.0,
    };

    if (id == 'magenta') {
      if (_fxAccum > 0.6) {
        _fxAccum = 0;
        add(ScorePulse(position: ball.position.clone(), color: neonPink));
      }
      return;
    }

    while (rate > 0 && _fxAccum > 1 / rate) {
      _fxAccum -= 1 / rate;
      _emitOneSpark(id);
    }
  }

  void _emitOneSpark(String id) {
    final r = random;
    final pos = ball.position + Vector2((r.nextDouble() - 0.5) * 14, (r.nextDouble() - 0.5) * 14);
    switch (id) {
      case 'fire':
        final hot = r.nextBool();
        add(SkinSpark(
          position: pos,
          velocity: Vector2((r.nextDouble() - 0.5) * 40, 120 + r.nextDouble() * 80),
          life: 0.45 + r.nextDouble() * 0.2,
          color: hot ? const Color(0xFFFFCC33) : const Color(0xFFFF4422),
          radius: 2 + r.nextDouble() * 1.5,
        ));
        break;
      case 'gold':
        add(SkinSpark(
          position: pos,
          velocity: Vector2((r.nextDouble() - 0.5) * 60, 60 + r.nextDouble() * 40),
          life: 0.7,
          color: const Color(0xFFFFD166),
          radius: 1.5 + r.nextDouble() * 1.5,
        ));
        break;
      case 'rainbow':
        final hue = (_skinTime * 60 + r.nextDouble() * 60) % 360;
        add(SkinSpark(
          position: pos,
          velocity: Vector2((r.nextDouble() - 0.5) * 80, 80 + r.nextDouble() * 60),
          life: 0.5,
          color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
          radius: 2,
        ));
        break;
      case 'cyan':
        add(SkinSpark(
          position: pos + Vector2(0, 4),
          velocity: Vector2((r.nextDouble() - 0.5) * 30, 80 + r.nextDouble() * 60),
          life: 0.5,
          color: const Color(0xFF66FFCC),
          radius: 2,
        ));
        break;
    }
  }

  void _spawnObstacle() {
    final effectiveBase = isZen
        ? gapSize
        : (gapSize - score * 1.5).clamp(80.0, gapSize);
    final variance = random.nextDouble();
    double currentGap;
    if (variance < 0.15) {
      currentGap = effectiveBase * 1.5;
    } else if (mode == GameMode.hardcore || variance > 0.85) {
      currentGap = effectiveBase * 0.75;
    } else {
      currentGap = effectiveBase;
    }
    if (isZen) currentGap = effectiveBase * 1.25;
    if (mode == GameMode.daily) currentGap *= todayModifier.gapMult;

    final canMove = _canSway();
    final swayAmplitude = canMove ? 40 + random.nextDouble() * 40 : 0.0;
    final swaySpeed = canMove ? 1.5 + random.nextDouble() * 1.5 : 0.0;
    final color = canMove ? neonPink : neonBlue;

    final gapX = random.nextDouble() * (size.x - currentGap - 40 - swayAmplitude * 2) + 20 + swayAmplitude;
    final startY = -barHeight - 60;

    final leftBar = ObstacleBar(
      position: Vector2(0, startY),
      size: Vector2(gapX, barHeight),
    );

    final rightBar = ObstacleBar(
      position: Vector2(gapX + currentGap, startY),
      size: Vector2(size.x - gapX - currentGap, barHeight),
    );

    leftBar.add(ObstacleMover(
      speed: obstacleSpeed, game: this, isLeft: true, currentGap: currentGap,
      baseX: gapX, swayAmplitude: swayAmplitude, swaySpeed: swaySpeed, color: color,
    ));
    rightBar.add(ObstacleMover(
      speed: obstacleSpeed, game: this, isLeft: false, currentGap: currentGap,
      baseX: gapX + currentGap, swayAmplitude: swayAmplitude, swaySpeed: swaySpeed, color: color,
    ));

    add(leftBar);
    add(rightBar);

    // Coins only in Classic/Daily — Zen would enable infinite farming (no game over),
    // Hardcore stays pure.
    if ((mode == GameMode.classic || mode == GameMode.daily) && random.nextDouble() < 0.15) {
      final randomOffset = (random.nextDouble() - 0.5) * (currentGap * 0.4);
      final coinX = gapX + currentGap / 2 + randomOffset;
      add(Coin(
        position: Vector2(coinX, startY + barHeight / 2),
        game: this,
        speed: obstacleSpeed,
        baseGapCenterX: coinX,
        swayAmplitude: swayAmplitude,
        swaySpeed: swaySpeed,
      ));
    }
  }

  void onCoinCollected(Vector2 pos) {
    Wallet.add(1);
    AudioService.play('close.wav', volume: 0.4);
    Haptics.light();
    add(CoinBurst(position: pos));
  }

  bool _canSway() {
    switch (mode) {
      case GameMode.classic:
        return score >= 8 && random.nextDouble() < 0.3;
      case GameMode.daily:
        final mod = todayModifier;
        if (mod.swayChance >= 0) {
          final allowed = mod.swayFromStart || score >= 4;
          return allowed && random.nextDouble() < mod.swayChance;
        }
        return score >= 8 && random.nextDouble() < 0.3;
      case GameMode.zen:
        return random.nextDouble() < 0.2;
      case GameMode.hardcore:
        return random.nextDouble() < 0.5;
    }
  }

  void onObstaclePassed({bool closeCall = false}) {
    if (gameState != GameState.playing) return;
    final base = closeCall ? 2 : 1;
    final mult = multiplierActive ? 2 : 1;
    score += base * mult;
    if (closeCall) {
      runCloseCalls += 1;
      closeCallStreak += 1;
      if (closeCallStreak >= 3 && !multiplierActive) {
        multiplierTimer = 5.0;
        multiplierRemaining.value = 5.0;
        _setScoreStyle(gold: true);
        add(ScorePulse(position: ball.position.clone(), color: const Color(0xFFFFD166)));
      }
      AudioService.play('close.wav', volume: 0.7);
      Haptics.light();
      Achievements.onCloseCall(runCloseCalls: runCloseCalls);
    } else {
      closeCallStreak = 0;
      AudioService.play('pass.wav', volume: 0.45);
    }
    scoreText.text = '$score';
    Achievements.onScore(mode: mode, score: score);

    switch (mode) {
      case GameMode.classic:
        obstacleSpeed = 200 + score * 5.0;
        spawnInterval = (1.6 - score * 0.025).clamp(0.85, 1.6);
        break;
      case GameMode.daily:
        final mod = todayModifier;
        obstacleSpeed = (200 + score * 5.0) * mod.speedMult;
        spawnInterval = ((1.6 - score * 0.025).clamp(0.85, 1.6)) * mod.spawnMult;
        break;
      case GameMode.zen:
        // Zen: tiny ramp so it doesn't stay trivial forever.
        obstacleSpeed = 150 + score * 1.2;
        spawnInterval = (2.2 - score * 0.01).clamp(1.4, 2.2);
        break;
      case GameMode.hardcore:
        obstacleSpeed = 260 + score * 4.5;
        spawnInterval = (1.4 - score * 0.025).clamp(0.8, 1.4);
        break;
    }

    scoreText.add(
      ScaleEffect.by(
        Vector2.all(closeCall ? 1.6 : 1.3),
        EffectController(duration: 0.08, reverseDuration: 0.15),
      ),
    );

    add(ScorePulse(
      position: ball.position.clone(),
      color: closeCall ? neonPink : neonBlue,
    ));

    if (closeCall) {
      add(ScorePulse(
        position: ball.position.clone(),
        color: neonPink,
      ));
      add(CloseCallText(
        position: ball.position.clone() - Vector2(0, 40),
        color: neonPink,
      ));
    }
  }
}
