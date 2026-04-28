import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/l10n.dart';
import '../services/storage.dart';
import 'daily.dart';
import 'pulse_game.dart';

class Achievement {
  final String id;
  final String _de;
  final String _en;
  final String _descDe;
  final String _descEn;
  final int coinReward;

  const Achievement(this.id, this._de, this._descDe, {String en = '', String descEn = '', this.coinReward = 10})
      : _en = en,
        _descEn = descEn;

  String get label => _en.isNotEmpty && L10n.isEn.value ? _en : _de;
  String get description => _descEn.isNotEmpty && L10n.isEn.value ? _descEn : _descDe;
}

const List<Achievement> achievements = [
  Achievement('score_10', 'Erster Schritt', 'Erreiche 10 Punkte in Classic.',
      en: 'First Step', descEn: 'Reach 10 points in Classic.', coinReward: 10),
  Achievement('score_50', 'Geübt', 'Erreiche 50 Punkte in Classic.',
      en: 'Practiced', descEn: 'Reach 50 points in Classic.', coinReward: 25),
  Achievement('score_100', 'Meister', 'Erreiche 100 Punkte in Classic.',
      en: 'Master', descEn: 'Reach 100 points in Classic.', coinReward: 50),
  Achievement('close_10_run', 'Hauchdünn', '10 Close-Calls in einem Run.',
      en: 'Razor Thin', descEn: '10 close calls in one run.', coinReward: 25),
  Achievement('hardcore_20', 'Hardcore-Held', 'Erreiche 20 in Hardcore.',
      en: 'Hardcore Hero', descEn: 'Reach 20 in Hardcore.', coinReward: 25),
  Achievement('zen_100', 'Durchatmen', 'Erreiche 100 in Zen.',
      en: 'Breathe', descEn: 'Reach 100 in Zen.', coinReward: 25),
  Achievement('daily_bronze', 'Teilnehmer', 'Hole deine erste Bronze-Medaille.',
      en: 'Participant', descEn: 'Earn your first Bronze medal.', coinReward: 10),
  Achievement('daily_silver', 'Ausdauernd', 'Hole eine Silber-Medaille.',
      en: 'Persistent', descEn: 'Earn a Silver medal.', coinReward: 25),
  Achievement('daily_gold', 'Legendär', 'Hole eine Gold-Medaille.',
      en: 'Legendary', descEn: 'Earn a Gold medal.', coinReward: 50),
  Achievement('games_10', 'Warmlaufen', 'Spiele 10 Runden.',
      en: 'Warming Up', descEn: 'Play 10 rounds.', coinReward: 10),
  Achievement('games_100', 'Veteran', 'Spiele 100 Runden.',
      en: 'Veteran', descEn: 'Play 100 rounds.', coinReward: 25),
  Achievement('close_100_total', 'Risikofreudig', '100 Close-Calls insgesamt.',
      en: 'Risk Taker', descEn: '100 close calls total.', coinReward: 50),
];

class Achievements {
  static const _prefix = 'ach_';
  static const _kGames = 'stat_games';
  static const _kCloseTotal = 'stat_close_total';

  static final Set<String> _unlocked = {};
  static int _games = 0;
  static int _closeTotal = 0;
  static bool _initialized = false;

  // Queue of newly unlocked achievements for UI to display.
  static final ValueNotifier<List<Achievement>> pending = ValueNotifier([]);

  static int get unlockedCount => _unlocked.length;
  static int get totalGames => _games;
  static int get totalCloseCalls => _closeTotal;
  static bool isUnlocked(String id) => _unlocked.contains(id);

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    for (final a in achievements) {
      if (prefs.getBool('$_prefix${a.id}') == true) _unlocked.add(a.id);
    }
    _games = prefs.getInt(_kGames) ?? 0;
    _closeTotal = prefs.getInt(_kCloseTotal) ?? 0;
  }

  static Future<void> _unlock(String id) async {
    if (_unlocked.contains(id)) return;
    final a = achievements.firstWhere((x) => x.id == id, orElse: () => const Achievement('', '', ''));
    if (a.id.isEmpty) return;
    _unlocked.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$id', true);
    Wallet.add(a.coinReward);
    pending.value = [...pending.value, a];
  }

  static void consumeOne() {
    if (pending.value.isEmpty) return;
    pending.value = pending.value.sublist(1);
  }

  // Hooks from the game.

  static Future<void> onGameEnded() async {
    _games += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGames, _games);
    if (_games >= 10) await _unlock('games_10');
    if (_games >= 100) await _unlock('games_100');
  }

  static Future<void> onCloseCall({required int runCloseCalls}) async {
    _closeTotal += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCloseTotal, _closeTotal);
    if (runCloseCalls >= 10) await _unlock('close_10_run');
    if (_closeTotal >= 100) await _unlock('close_100_total');
  }

  static Future<void> onScore({required GameMode mode, required int score}) async {
    switch (mode) {
      case GameMode.classic:
        if (score >= 10) await _unlock('score_10');
        if (score >= 50) await _unlock('score_50');
        if (score >= 100) await _unlock('score_100');
        break;
      case GameMode.hardcore:
        if (score >= 20) await _unlock('hardcore_20');
        break;
      case GameMode.zen:
        if (score >= 100) await _unlock('zen_100');
        break;
      case GameMode.daily:
        break;
    }
  }

  static Future<void> onDailyMedal(Medal m) async {
    if (m.index >= Medal.bronze.index) await _unlock('daily_bronze');
    if (m.index >= Medal.silver.index) await _unlock('daily_silver');
    if (m.index >= Medal.gold.index) await _unlock('daily_gold');
  }
}
