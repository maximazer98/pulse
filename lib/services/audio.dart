import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static const _kMuted = 'muted';
  static final ValueNotifier<bool> muted = ValueNotifier(false);
  static bool _initialized = false;
  // Flip to true once real WAV assets exist in assets/audio/.
  static const bool _assetsPresent = true;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    muted.value = prefs.getBool(_kMuted) ?? false;
  }

  static Future<void> toggleMute() async {
    muted.value = !muted.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMuted, muted.value);
  }

  static void play(String file, {double volume = 0.6}) {
    if (muted.value || !_assetsPresent) return;
    FlameAudio.play(file, volume: volume).then((_) {}, onError: (_) {});
  }
}
