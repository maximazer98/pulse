import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static const _kMuted = 'muted';
  static final ValueNotifier<bool> muted = ValueNotifier(false);
  static bool _initialized = false;
  static bool _audioUnlocked = false;
  static const bool _assetsPresent = true;

  // Set to true once music.ogg is placed in assets/audio/
  static const bool _musicPresent = false;
  static bool _musicPlaying = false;

  static const List<String> _files = ['pass.wav', 'close.wav', 'gameover.wav', 'score.wav'];
  static final Map<String, AudioPool> _pools = {};

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    muted.value = prefs.getBool(_kMuted) ?? false;
    if (_musicPresent) FlameAudio.bgm.initialize();
    for (final f in _files) {
      try {
        _pools[f] = await FlameAudio.createPool(f, maxPlayers: 4, minPlayers: 1);
      } catch (_) {}
    }
  }

  static Future<void> playMusic() async {
    _musicPlaying = true;
    if (!_musicPresent || muted.value) return;
    try {
      await FlameAudio.bgm.play('music.ogg', volume: 0.35);
    } catch (_) {}
  }

  static void stopMusic() {
    _musicPlaying = false;
    if (!_musicPresent) return;
    try { FlameAudio.bgm.stop(); } catch (_) {}
  }

  static void pauseMusic() {
    if (!_musicPresent || !_musicPlaying) return;
    try { FlameAudio.bgm.pause(); } catch (_) {}
  }

  static void resumeMusic() {
    if (!_musicPresent || !_musicPlaying || muted.value) return;
    try { FlameAudio.bgm.resume(); } catch (_) {}
  }

  static Future<void> toggleMute() async {
    muted.value = !muted.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMuted, muted.value);
    if (muted.value) {
      pauseMusic();
    } else {
      resumeMusic();
    }
  }

  static Future<void> unlockAudio() async {
    if (_audioUnlocked || !kIsWeb) return;
    _audioUnlocked = true;
    if (kIsWeb) _unlockWebAudio();
    final pool = _pools['score.wav'];
    if (pool != null) {
      pool.start(volume: 0.01).catchError((_) => () async {});
    } else {
      FlameAudio.play('score.wav', volume: 0.01).then((_) {}, onError: (_) {});
    }
  }

  static void _unlockWebAudio() {
    // Implemented in audio_web.dart via conditional import at call site.
    // On non-web this stub is never reached due to kIsWeb guard above.
  }

  static void play(String file, {double volume = 0.6}) {
    if (muted.value || !_assetsPresent) return;
    final pool = _pools[file];
    if (pool != null) {
      pool.start(volume: volume).catchError((_) => () async {});
    } else {
      FlameAudio.play(file, volume: volume).then((_) {}, onError: (_) {});
    }
  }
}
