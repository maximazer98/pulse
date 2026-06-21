import '../services/l10n.dart';

class DailyModifier {
  final String id;
  final String _labelDe;
  final String _labelEn;
  final String _descDe;
  final String _descEn;
  final double speedMult;
  final double gapMult;
  final double spawnMult;
  final double? swayChance; // 0..1 overrides normal gate; null = keep default (classic rule)
  final bool swayFromStart;
  final int bronze;
  final int silver;
  final int gold;

  const DailyModifier({
    required this.id,
    required String label,
    String labelEn = '',
    required String description,
    String descriptionEn = '',
    this.speedMult = 1.0,
    this.gapMult = 1.0,
    this.spawnMult = 1.0,
    this.swayChance, // null = keep default (classic rule)
    this.swayFromStart = false,
    required this.bronze,
    required this.silver,
    required this.gold,
  })  : _labelDe = label,
        _labelEn = labelEn,
        _descDe = description,
        _descEn = descriptionEn;

  String get label => _labelEn.isNotEmpty && L10n.isEn.value ? _labelEn : _labelDe;
  String get description => _descEn.isNotEmpty && L10n.isEn.value ? _descEn : _descDe;
}

const List<DailyModifier> dailyModifiers = [
  DailyModifier(
    id: 'blitz',
    label: 'BLITZ',
    labelEn: 'BLITZ',
    description: 'Startet schnell, bleibt schnell.',
    descriptionEn: 'Starts fast, stays fast.',
    speedMult: 1.35,
    spawnMult: 0.85,
    bronze: 10, silver: 20, gold: 35,
  ),
  DailyModifier(
    id: 'narrow',
    label: 'NADELÖHR',
    labelEn: 'NEEDLE',
    description: 'Alle Lücken 25% schmaler.',
    descriptionEn: 'All gaps 25% narrower.',
    gapMult: 0.75,
    bronze: 8, silver: 16, gold: 28,
  ),
  DailyModifier(
    id: 'chaos',
    label: 'CHAOS',
    labelEn: 'CHAOS',
    description: 'Jeder Balken schwingt von Anfang an.',
    descriptionEn: 'Every bar sways from the start.',
    swayChance: 0.9,
    swayFromStart: true,
    speedMult: 0.9,
    bronze: 8, silver: 16, gold: 28,
  ),
  DailyModifier(
    id: 'slow_swarm',
    label: 'DICHT',
    labelEn: 'DENSE',
    description: 'Gemächliche Geschwindigkeit, aber Balken kommen im Takt.',
    descriptionEn: 'Slow speed, but bars come rapidly.',
    speedMult: 0.75,
    spawnMult: 0.6,
    bronze: 14, silver: 28, gold: 48,
  ),
  DailyModifier(
    id: 'mini',
    label: 'MINIATUR',
    labelEn: 'TINY',
    description: 'Winzige Lücken, dafür langsamer.',
    descriptionEn: 'Tiny gaps, but slower.',
    gapMult: 0.6,
    speedMult: 0.8,
    bronze: 8, silver: 15, gold: 25,
  ),
  DailyModifier(
    id: 'wide_rush',
    label: 'ANSTURM',
    labelEn: 'RUSH',
    description: 'Breite Lücken — aber Speed explodiert.',
    descriptionEn: 'Wide gaps — but speed explodes.',
    gapMult: 1.35,
    speedMult: 1.5,
    bronze: 12, silver: 24, gold: 40,
  ),
  DailyModifier(
    id: 'pulsing',
    label: 'PULSIEREND',
    labelEn: 'PULSING',
    description: 'Alle Balken pulsieren sanft seitwärts.',
    descriptionEn: 'All bars pulse gently sideways.',
    swayChance: 0.7,
    swayFromStart: true,
    gapMult: 1.1,
    bronze: 10, silver: 20, gold: 35,
  ),
];

DailyModifier modifierFor(DateTime d) {
  final seed = d.year * 10000 + d.month * 100 + d.day;
  return dailyModifiers[seed % dailyModifiers.length];
}

enum Medal { none, bronze, silver, gold }

Medal medalFor(int score, DailyModifier m) {
  if (score >= m.gold) return Medal.gold;
  if (score >= m.silver) return Medal.silver;
  if (score >= m.bronze) return Medal.bronze;
  return Medal.none;
}

extension MedalX on Medal {
  String get label {
    switch (this) {
      case Medal.none: return '';
      case Medal.bronze: return 'BRONZE';
      case Medal.silver: return L10n.t('SILBER', 'SILVER');
      case Medal.gold: return 'GOLD';
    }
  }
}
