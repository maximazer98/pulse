import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'pulse_game.dart';

class GradientBackdrop extends PositionComponent {
  final PulseGame game;
  double time = 0;

  GradientBackdrop({required this.game}) : super(priority: -10);

  @override
  void update(double dt) {
    time += dt * 0.05;
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final cx = w * (0.5 + sin(time) * 0.18);
    final cy = h * (0.32 + cos(time * 0.7) * 0.1);
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: const [
          Color(0xFF231845),
          Color(0xFF0D0A25),
          Color(0xFF04040C),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 1.0));
    canvas.drawRect(rect, paint);
  }
}

class BackgroundStar extends CircleComponent {
  final PulseGame game;
  double speed;

  BackgroundStar({required Vector2 position, required this.game})
      : speed = 40 + Random().nextDouble() * 80,
        super(
          radius: 1 + Random().nextDouble() * 1.5,
          position: position,
          anchor: Anchor.center,
          paint: Paint()
            ..color = Color.fromARGB(
              (80 + Random().nextDouble() * 120).toInt(),
              255,
              255,
              255,
            ),
        );

  @override
  void update(double dt) {
    final activeSpeed = game.gameState == GameState.playing
        ? speed + game.obstacleSpeed * 0.3
        : speed * 0.3;
    position.y += activeSpeed * dt;
    if (position.y > game.size.y) {
      position.y = -5;
      position.x = Random().nextDouble() * game.size.x;
    }
  }
}

class ScorePulse extends CircleComponent {
  double life = 1.0;

  ScorePulse({required Vector2 position, required Color color})
      : super(
          radius: 20,
          position: position,
          anchor: Anchor.center,
          paint: Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );

  @override
  void update(double dt) {
    life -= dt * 3;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    final baseColor = paint.color;
    paint.color = baseColor.withAlpha((life * 200).toInt());
    scale = Vector2.all(1 + (1 - life) * 2.5);
  }
}

class CloseCallText extends TextComponent {
  double life = 1.0;

  CloseCallText({required Vector2 position, required Color color})
      : super(
          text: '+2 CLOSE!',
          position: position,
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              shadows: [Shadow(color: color, blurRadius: 8)],
            ),
          ),
        );

  @override
  void update(double dt) {
    life -= dt * 1.2;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    position.y -= 60 * dt;
  }
}

class Coin extends CircleComponent {
  final PulseGame game;
  final double speed;
  final double baseGapCenterX;
  final double swayAmplitude;
  final double swaySpeed;
  double time = 0;
  bool collected = false;

  Coin({
    required Vector2 position,
    required this.game,
    required this.speed,
    required this.baseGapCenterX,
    this.swayAmplitude = 0,
    this.swaySpeed = 0,
  }) : super(
          radius: 9,
          position: position,
          anchor: Anchor.center,
          paint: Paint()
            ..color = const Color(0xFFFFD166)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );

  @override
  void update(double dt) {
    if (collected) {
      time += dt;
      scale = Vector2.all(1 + time * 6);
      paint.color = paint.color.withAlpha(((1 - time * 4).clamp(0, 1) * 255).toInt());
      if (time > 0.25) removeFromParent();
      return;
    }
    position.y += speed * dt;
    time += dt;
    if (swayAmplitude > 0) {
      position.x = baseGapCenterX + sin(time * swaySpeed) * swayAmplitude;
    }
    final pulse = 1 + sin(time * 8) * 0.12;
    scale = Vector2.all(pulse);

    if (game.gameState == GameState.playing) {
      final ball = game.ball;
      final dx = ball.position.x - position.x;
      final dy = ball.position.y - position.y;
      final r = radius + ball.radius;
      if (dx * dx + dy * dy < r * r) {
        collected = true;
        time = 0;
        game.onCoinCollected(position.clone());
      }
    }

    if (position.y > game.size.y + 30) removeFromParent();
  }
}

class CoinBurst extends CircleComponent {
  double life = 1.0;

  CoinBurst({required Vector2 position})
      : super(
          radius: 14,
          position: position,
          anchor: Anchor.center,
          paint: Paint()
            ..color = const Color(0xFFFFD166)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );

  @override
  void update(double dt) {
    life -= dt * 3;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    paint.color = const Color(0xFFFFD166).withAlpha((life * 220).toInt());
    scale = Vector2.all(1 + (1 - life) * 2.2);
  }
}

class SkinSpark extends CircleComponent {
  Vector2 velocity;
  double life;
  final double maxLife;

  SkinSpark({
    required Vector2 position,
    required this.velocity,
    required this.life,
    required Color color,
    double radius = 2.5,
  })  : maxLife = life,
        super(
          radius: radius,
          position: position,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

  @override
  void update(double dt) {
    life -= dt;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    position += velocity * dt;
    velocity.y += 60 * dt; // subtle downward drift
    final t = (life / maxLife).clamp(0.0, 1.0);
    paint.color = paint.color.withAlpha((t * 220).toInt());
  }
}

class ParticleDot extends CircleComponent {
  Vector2 velocity;
  double life = 1.0;

  ParticleDot({
    required Vector2 position,
    required this.velocity,
    required Color color,
  }) : super(
          radius: 4,
          position: position,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

  @override
  void update(double dt) {
    life -= dt * 1.5;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    position += velocity * dt;
    velocity *= 0.95;
    paint.color = paint.color.withAlpha((life * 255).toInt());
  }
}
