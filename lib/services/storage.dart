import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  // Legacy key (pre-modes). Migrates to 'best_classic' on first load.
  static const _kLegacyBest = 'bestScore';

  static String _bestKey(String mode) => 'best_$mode';

  static Future<int> loadBest(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_bestKey(mode));
    if (stored != null) return stored;
    if (mode == 'classic') {
      final legacy = prefs.getInt(_kLegacyBest);
      if (legacy != null) {
        await prefs.setInt(_bestKey(mode), legacy);
        return legacy;
      }
    }
    return 0;
  }

  static Future<void> saveBest(String mode, int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestKey(mode), score);
  }

  static String dailyKey(DateTime d) =>
      'daily_${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static Future<int> loadDailyBest(DateTime d) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(dailyKey(d)) ?? 0;
  }

  static Future<void> saveDailyBest(DateTime d, int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(dailyKey(d), score);
  }

  static Future<bool> loadBool(String key, {bool def = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? def;
  }

  static Future<void> saveBool(String key, {required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}

class PowerUps {
  static const _kShields = 'shield_count';
  static int _shields = 0;
  static bool _initialized = false;
  static final ValueNotifier<int> shieldCount = ValueNotifier(0);

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _shields = (prefs.getInt(_kShields) ?? 0).clamp(0, _maxShields);
    shieldCount.value = _shields;
  }

  static const int _maxShields = 99;

  static Future<void> buy() async {
    if (_shields >= _maxShields) return;
    _shields++;
    shieldCount.value = _shields;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kShields, _shields);
  }

  static bool consume() {
    if (_shields <= 0) return false;
    _shields--;
    shieldCount.value = _shields;
    SharedPreferences.getInstance().then((p) => p.setInt(_kShields, _shields));
    return true;
  }

  static int get count => _shields;
}

class Wallet {
  static const _kCoins = 'wallet_coins';
  static int _coins = 0;
  static bool _initialized = false;

  static final ValueNotifier<int> coins = ValueNotifier(0);

  static const int _maxCoins = 1 << 30; // ~1 billion, same ceiling used in spend/add

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _coins = (prefs.getInt(_kCoins) ?? 0).clamp(0, _maxCoins);
    coins.value = _coins;
  }

  static Future<void> add(int amount) async {
    if (amount <= 0) return; // reject non-positive additions (e.g. corrupted calls)
    _coins = (_coins + amount).clamp(0, 1 << 30);
    coins.value = _coins;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoins, _coins);
  }

  static Future<void> spend(int amount) async {
    if (amount <= 0) return; // reject non-positive spend amounts
    _coins = (_coins - amount).clamp(0, 1 << 30);
    coins.value = _coins;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoins, _coins);
  }

  static int get value => _coins;
}
