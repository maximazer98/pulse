import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

class Haptics {
  static bool _supported = false;
  static bool _checked = false;
  static int _lastLightMs = 0;

  static Future<void> _ensureChecked() async {
    if (_checked) return;
    _checked = true;
    if (kIsWeb) return;
    try {
      _supported = await Vibration.hasVibrator();
    } catch (_) {
      _supported = false;
    }
  }

  static Future<void> light() async {
    await _ensureChecked();
    if (!_supported) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLightMs < 150) return;
    _lastLightMs = now;
    try {
      Vibration.vibrate(duration: 15, amplitude: 80);
    } catch (_) {}
  }

  static Future<void> heavy() async {
    await _ensureChecked();
    if (!_supported) return;
    try {
      Vibration.vibrate(duration: 140, amplitude: 200);
    } catch (_) {}
  }
}
