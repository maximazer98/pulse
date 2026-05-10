import 'dart:io';
import 'package:image/image.dart';

void main() {
  _generate('assets/launcher_icon/icon.png', foreground: false);
  _generate('assets/launcher_icon/icon_foreground.png', foreground: true);
  print('Done: assets/launcher_icon/icon.png + icon_foreground.png');
}

void _generate(String path, {required bool foreground}) {
  const size = 1024;
  final img = Image(width: size, height: size);

  // Background
  if (foreground) {
    fill(img, color: ColorRgba8(0, 0, 0, 0)); // transparent for adaptive
  } else {
    fill(img, color: ColorRgb8(10, 10, 26));
    _backgroundGlow(img, size);
  }

  const cx = size ~/ 2;
  const cy = size ~/ 2;

  // Gap / bar layout
  const gapY = cy + 30;
  const barH = 75;
  const gapHalf = 105;
  const barLeft = cx - gapHalf;
  const barRight = cx + gapHalf;

  // Bar glow layers
  for (var g = 24; g >= 2; g -= 2) {
    final alpha = (8 + (24 - g)).clamp(0, 255);
    fillRect(img,
        x1: 0,
        y1: gapY - barH ~/ 2 - g,
        x2: barLeft + g ~/ 2,
        y2: gapY + barH ~/ 2 + g,
        color: ColorRgba8(0, 200, 255, alpha));
    fillRect(img,
        x1: barRight - g ~/ 2,
        y1: gapY - barH ~/ 2 - g,
        x2: size,
        y2: gapY + barH ~/ 2 + g,
        color: ColorRgba8(0, 200, 255, alpha));
  }

  // Bars (solid neon blue)
  fillRect(img,
      x1: 0,
      y1: gapY - barH ~/ 2,
      x2: barLeft,
      y2: gapY + barH ~/ 2,
      color: ColorRgb8(0, 190, 245));
  fillRect(img,
      x1: barRight,
      y1: gapY - barH ~/ 2,
      x2: size,
      y2: gapY + barH ~/ 2,
      color: ColorRgb8(0, 190, 245));

  // Bar edge highlight (top edge brighter)
  fillRect(img,
      x1: 0, y1: gapY - barH ~/ 2, x2: barLeft, y2: gapY - barH ~/ 2 + 4,
      color: ColorRgb8(80, 230, 255));
  fillRect(img,
      x1: barRight, y1: gapY - barH ~/ 2, x2: size, y2: gapY - barH ~/ 2 + 4,
      color: ColorRgb8(80, 230, 255));

  // Ball glow layers
  const ballR = 58;
  for (var g = 48; g >= 4; g -= 4) {
    final alpha = ((1 - g / 52) * 55).toInt().clamp(0, 255);
    fillCircle(img,
        x: cx,
        y: gapY,
        radius: ballR + g,
        color: ColorRgba8(180, 235, 255, alpha));
  }

  // Ball inner glow
  fillCircle(img, x: cx, y: gapY, radius: ballR + 8,
      color: ColorRgba8(220, 245, 255, 120));

  // Ball (white)
  fillCircle(img, x: cx, y: gapY, radius: ballR,
      color: ColorRgb8(255, 255, 255));

  // Ball highlight (top-left bright spot)
  fillCircle(img, x: cx - 18, y: gapY - 18, radius: 18,
      color: ColorRgba8(255, 255, 255, 160));

  // Trail dots above ball
  const trailColor = ColorRgba8(180, 235, 255, 140);
  for (var i = 1; i <= 5; i++) {
    final tr = (ballR * (1 - i * 0.16)).toInt().clamp(4, ballR);
    final alpha = (140 - i * 22).clamp(20, 140);
    fillCircle(img,
        x: cx,
        y: gapY - ballR * 2 - i * (ballR ~/ 2 + 10),
        radius: tr,
        color: ColorRgba8(180, 235, 255, alpha));
  }

  final dir = Directory('assets/launcher_icon');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File(path).writeAsBytesSync(encodePng(img));
}

void _backgroundGlow(Image img, int size) {
  final cx = size ~/ 2;
  final cy = size ~/ 2;
  for (var r = 420; r > 20; r -= 20) {
    final t = 1 - r / 420;
    final alpha = (t * 28).toInt().clamp(0, 255);
    fillCircle(img, x: cx, y: cy, radius: r,
        color: ColorRgba8(20, 15, 55, alpha));
  }
}
