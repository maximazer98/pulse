import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/l10n.dart';

class Skin {
  final String id;
  final String _labelDe;
  final String _labelEn;
  final String _descDe;
  final String _descEn;
  final int cost; // 0 = free / default
  final Color ballColor;
  final Color trailColor;
  final bool rainbow;

  const Skin({
    required this.id,
    required String label,
    String labelEn = '',
    required String description,
    String descriptionEn = '',
    required this.cost,
    required this.ballColor,
    required this.trailColor,
    this.rainbow = false,
  })  : _labelDe = label,
        _labelEn = labelEn,
        _descDe = description,
        _descEn = descriptionEn;

  String get label => _labelEn.isNotEmpty && L10n.isEn.value ? _labelEn : _labelDe;
  String get description => _descEn.isNotEmpty && L10n.isEn.value ? _descEn : _descDe;
}

const List<Skin> skins = [
  Skin(
    id: 'default',
    label: 'Puls',
    labelEn: 'Pulse',
    description: 'Das Original.',
    descriptionEn: 'The original.',
    cost: 0,
    ballColor: Color(0xFFFFFFFF),
    trailColor: Color(0xFF00C8FF),
  ),
  Skin(
    id: 'magenta',
    label: 'Neon',
    labelEn: 'Neon',
    description: 'Pink, wie ein Herzschlag.',
    descriptionEn: 'Pink like a heartbeat.',
    cost: 30,
    ballColor: Color(0xFFFF2D87),
    trailColor: Color(0xFFFF66B8),
  ),
  Skin(
    id: 'cyan',
    label: 'Aqua',
    labelEn: 'Aqua',
    description: 'Kühl und klar.',
    descriptionEn: 'Cool and clear.',
    cost: 50,
    ballColor: Color(0xFF66FFCC),
    trailColor: Color(0xFF00FFD1),
  ),
  Skin(
    id: 'fire',
    label: 'Feuer',
    labelEn: 'Fire',
    description: 'Heiß durch jede Lücke.',
    descriptionEn: 'Hot through every gap.',
    cost: 120,
    ballColor: Color(0xFFFFAA33),
    trailColor: Color(0xFFFF4422),
  ),
  Skin(
    id: 'gold',
    label: 'Gold',
    labelEn: 'Gold',
    description: 'Für Sammler.',
    descriptionEn: 'For collectors.',
    cost: 300,
    ballColor: Color(0xFFFFD166),
    trailColor: Color(0xFFFFB700),
  ),
  Skin(
    id: 'rainbow',
    label: 'Spektrum',
    labelEn: 'Spectrum',
    description: 'Zyklischer Regenbogen.',
    descriptionEn: 'Cyclic rainbow.',
    cost: 500,
    ballColor: Color(0xFFFFFFFF),
    trailColor: Color(0xFFFFFFFF),
    rainbow: true,
  ),
];

class Skins {
  static const _kOwned = 'skins_owned';
  static const _kEquipped = 'skin_equipped';

  static final Set<String> _owned = {'default'};
  static String _equipped = 'default';
  static bool _initialized = false;

  static final ValueNotifier<String> equippedId = ValueNotifier('default');
  static final ValueNotifier<Set<String>> owned = ValueNotifier({'default'});

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kOwned) ?? const [];
    _owned
      ..clear()
      ..add('default')
      ..addAll(stored);
    _equipped = prefs.getString(_kEquipped) ?? 'default';
    if (!_owned.contains(_equipped)) _equipped = 'default';
    equippedId.value = _equipped;
    owned.value = {..._owned};
  }

  static Skin get equipped => skins.firstWhere((s) => s.id == _equipped, orElse: () => skins.first);
  static bool isOwned(String id) => _owned.contains(id);

  static Future<bool> purchase(Skin s, {required int coins, required Future<void> Function(int) spend}) async {
    if (_owned.contains(s.id)) return false;
    if (coins < s.cost) return false;
    await spend(s.cost);
    _owned.add(s.id);
    owned.value = {..._owned};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOwned, _owned.where((id) => id != 'default').toList());
    return true;
  }

  static Future<void> equip(String id) async {
    if (!_owned.contains(id)) return;
    _equipped = id;
    equippedId.value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEquipped, id);
  }
}
