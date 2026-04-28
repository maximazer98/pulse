import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'pulse_game.dart';

class ObstacleBar extends RectangleComponent {
  ObstacleBar({required Vector2 position, required Vector2 size})
      : super(position: position, size: size, paint: Paint()..color = const Color(0x00000000));

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final a = paint.color.a;
    if (a == 0) return;
    final edgePaint = Paint()
      ..color = paint.color.withAlpha((a * 255 * 0.75).clamp(0, 255).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(size.toRect(), edgePaint);
  }
}

class ObstacleMover extends Component {
  final double speed;
  final PulseGame game;
  final bool isLeft;
  final double currentGap;
  final double baseX;
  final double swayAmplitude;
  final double swaySpeed;
  final Color color;
  double time = 0;
  bool scored = false;

  ObstacleMover({
    required this.speed,
    required this.game,
    required this.isLeft,
    required this.currentGap,
    required this.baseX,
    required this.swayAmplitude,
    required this.swaySpeed,
    required this.color,
  });

  @override
  void update(double dt) {
    final bar = parent as RectangleComponent;
    bar.position.y += speed * dt;
    time += dt;

    if (swayAmplitude > 0) {
      final offset = sin(time * swaySpeed) * swayAmplitude;
      if (isLeft) {
        bar.size.x = (baseX + offset).clamp(10.0, game.size.x - currentGap - 10);
      } else {
        final newBaseX = (baseX + offset).clamp(currentGap + 10, game.size.x - 10);
        bar.position.x = newBaseX;
        bar.size.x = game.size.x - newBaseX;
      }
    }

    if (bar.position.y < 40) {
      final t = ((bar.position.y + 60) / 100).clamp(0.0, 1.0);
      bar.paint.color = color.withAlpha((t * 255).toInt());
    } else {
      bar.paint.color = color;
    }

    if (!scored && isLeft && bar.position.y > game.ballY + 30) {
      scored = true;
      final ballX = game.ball.position.x;
      final ballR = game.ball.radius;
      final gapLeft = bar.size.x;
      final gapRight = bar.size.x + currentGap;
      final distLeft = (ballX - ballR) - gapLeft;
      final distRight = gapRight - (ballX + ballR);
      final inGap = distLeft >= 0 && distRight >= 0;
      // In Zen there's no game over, so a ball that crashed through still runs this
      // check. Only award the point if the ball was actually in the gap.
      if (!game.isZen || inGap) {
        final closeCall = (distLeft >= 0 && distLeft < 8) || (distRight >= 0 && distRight < 8);
        game.onObstaclePassed(closeCall: closeCall);
      }
    }

    final ballPos = game.ball.position;
    final ballR = game.ball.radius;
    final barTop = bar.position.y;
    final barBottom = bar.position.y + game.barHeight;

    if (ballPos.y + ballR > barTop && ballPos.y - ballR < barBottom) {
      if (isLeft && ballPos.x - ballR < bar.size.x) {
        game.triggerGameOver();
      }
      if (!isLeft && ballPos.x + ballR > bar.position.x) {
        game.triggerGameOver();
      }
    }

    if (bar.position.y > game.size.y + 50) {
      bar.removeFromParent();
    }
  }
}
