import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/achievements.dart';
import 'game/daily.dart';
import 'game/pulse_game.dart';
import 'game/skins.dart';
import 'services/audio.dart';
import 'services/l10n.dart';
import 'services/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await L10n.init();
  runApp(const GameApp());
}

const Color _neonBlue = Color(0xFF00C8FF);
const Color _neonPink = Color(0xFFFF2D87);
const Color _bg = Color(0xFF0A0A1A);

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  final _game = PulseGame();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: L10n.isEn,
      builder: (context, isEnValue, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: _bg,
          body: GameWidget<PulseGame>(
            game: _game,
            initialActiveOverlays: const ['hud'],
            overlayBuilderMap: {
              'hud': (context, g) => Stack(children: [HudOverlay(game: g), const AchievementToast()]),
              'pause': (context, g) => PauseOverlay(game: g),
              'menu': (context, g) => MenuOverlay(game: g),
              'game_over': (context, g) => GameOverOverlay(game: g),
            },
          ),
        ),
      ),
    );
  }
}

class HudOverlay extends StatelessWidget {
  final PulseGame game;
  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top + 14;
    return Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, topPad, 14, 14),
              child: ValueListenableBuilder<GameState>(
                valueListenable: game.stateNotifier,
                builder: (_, state, stateChild) {
                  if (state != GameState.playing) return const SizedBox.shrink();
                  return ValueListenableBuilder<int>(
                    valueListenable: Wallet.coins,
                    builder: (_, coins, child) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: const Color(0xFFFFD166).withAlpha(200), size: 10),
                        const SizedBox(width: 5),
                        Text(
                          '$coins',
                          style: TextStyle(
                            color: const Color(0xFFFFD166).withAlpha(210),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: ValueListenableBuilder<double>(
                valueListenable: game.multiplierRemaining,
                builder: (_, remaining, multChild) {
                  if (remaining <= 0) return const SizedBox.shrink();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFFFFD166).withAlpha(40),
                          border: Border.all(color: const Color(0xFFFFD166), width: 1.5),
                        ),
                        child: const Text(
                          '2× MULTI',
                          style: TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            shadows: [Shadow(color: Color(0xFFFFD166), blurRadius: 8)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 100,
                        height: 3,
                        child: LinearProgressIndicator(
                          value: (remaining / 5.0).clamp(0.0, 1.0),
                          backgroundColor: const Color(0x22FFD166),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD166)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, topPad, 12, 12),
              child: ValueListenableBuilder<GameState>(
                valueListenable: game.stateNotifier,
                builder: (_, state, stateChild) {
                  if (state != GameState.playing) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: AudioService.muted,
                        builder: (_, muted, child) => _iconButton(
                          muted ? Icons.volume_off : Icons.volume_up,
                          AudioService.toggleMute,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconButton(Icons.pause, game.togglePause),
                    ],
                  );
                },
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: game.shieldActiveNotifier,
            builder: (context, active, child) {
              if (!active) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield, color: Color(0xFF66FFCC), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        L10n.t('SCHILD', 'SHIELD'),
                        style: TextStyle(
                          color: Color(0xFF66FFCC),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: game.hintNotifier,
            builder: (context, show, child) =>
                show ? _HintBanner(game: game) : const SizedBox.shrink(),
          ),
        ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(30),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  final PulseGame game;
  const PauseOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xAA000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSE',
              style: TextStyle(
                color: _neonBlue,
                fontSize: 56,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                shadows: [Shadow(color: _neonBlue, blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 32),
            _PillButton(label: L10n.t('Weiter', 'Resume'), onTap: game.togglePause),
            const SizedBox(height: 12),
            _PillButton(label: L10n.t('Menü', 'Menu'), onTap: game.backToMenu, accent: Color(0xFF444444)),
          ],
        ),
      ),
    );
  }
}

class MenuOverlay extends StatelessWidget {
  final PulseGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg.withAlpha(220),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'PULSE',
                  style: TextStyle(
                    color: _neonBlue,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                    shadows: [Shadow(color: _neonBlue, blurRadius: 24)],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  L10n.t('Finger ziehen. Lücken treffen.', 'Slide finger. Hit the gaps.'),
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: Wallet.coins,
                builder: (_, coins, child) => Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD166).withAlpha(160), width: 1),
                      color: const Color(0xFFFFD166).withAlpha(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Color(0xFFFFD166), size: 12),
                        const SizedBox(width: 6),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [Shadow(color: Color(0xFFFFD166), blurRadius: 8)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (ctx) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MenuPill(
                      icon: Icons.emoji_events,
                      label: '${L10n.t('Erfolge', 'Trophies')} ${Achievements.unlockedCount}/${achievements.length}',
                      onTap: () => Navigator.of(ctx, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const AchievementsSheet()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MenuPill(
                      icon: Icons.bar_chart,
                      label: L10n.t('Stats', 'Stats'),
                      onTap: () => Navigator.of(ctx, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => StatsSheet(game: game)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MenuPill(
                      icon: Icons.style,
                      label: L10n.t('Shop', 'Shop'),
                      onTap: () => Navigator.of(ctx, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const SkinShopSheet()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final m in GameMode.values) ...[
                _ModeCard(
                  mode: m,
                  best: m == GameMode.daily ? game.dailyBest : (game.bestScores[m] ?? 0),
                  dailyMod: m == GameMode.daily ? game.todayModifier : null,
                  medal: m == GameMode.daily ? game.dailyMedal : Medal.none,
                  onTap: () => game.startGame(m),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 16),
            ],
              ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _LangToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GameMode mode;
  final int best;
  final DailyModifier? dailyMod;
  final Medal medal;
  final VoidCallback onTap;
  const _ModeCard({
    required this.mode,
    required this.best,
    required this.onTap,
    this.dailyMod,
    this.medal = Medal.none,
  });

  Color get _accent {
    switch (mode) {
      case GameMode.classic: return _neonBlue;
      case GameMode.zen: return const Color(0xFF66FFCC);
      case GameMode.hardcore: return _neonPink;
      case GameMode.daily: return const Color(0xFFFFCC66);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withAlpha(120), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          dailyMod != null ? dailyMod!.label : mode.label,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            shadows: [Shadow(color: _accent, blurRadius: 10)],
                          ),
                        ),
                        if (dailyMod != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            L10n.t('HEUTE', 'TODAY'),
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dailyMod != null ? dailyMod!.description : mode.description,
                      style: const TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 14,
                      ),
                    ),
                    if (dailyMod != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MedalChip(level: Medal.bronze, threshold: dailyMod!.bronze, earned: medal.index >= Medal.bronze.index),
                          const SizedBox(width: 6),
                          _MedalChip(level: Medal.silver, threshold: dailyMod!.silver, earned: medal.index >= Medal.silver.index),
                          const SizedBox(width: 6),
                          _MedalChip(level: Medal.gold, threshold: dailyMod!.gold, earned: medal.index >= Medal.gold.index),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dailyMod != null ? L10n.t('HEUTE', 'TODAY') : 'BEST',
                    style: const TextStyle(color: Color(0xFF666666), fontSize: 10, letterSpacing: 2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$best',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AchievementToast extends StatefulWidget {
  const AchievementToast({super.key});

  @override
  State<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<AchievementToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Achievement? _current;

  @override
  void initState() {
    super.initState();
    Achievements.pending.addListener(_onQueueChanged);
    _onQueueChanged();
  }

  void _onQueueChanged() {
    if (_current != null) return;
    final q = Achievements.pending.value;
    if (q.isEmpty) return;
    setState(() => _current = q.first);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (!mounted) return;
    Achievements.consumeOne();
    setState(() => _current = null);
    _onQueueChanged();
  }

  @override
  void dispose() {
    Achievements.pending.removeListener(_onQueueChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: _bg.withAlpha(230),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _neonBlue.withAlpha(180), width: 1.5),
              boxShadow: [
                BoxShadow(color: _neonBlue.withAlpha(120), blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.t('ERFOLG FREIGESCHALTET', 'ACHIEVEMENT UNLOCKED'),
                  style: const TextStyle(
                    color: _neonBlue,
                    fontSize: 10,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  current.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  current.description,
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: const Color(0xFFFFD166).withAlpha(220), size: 10),
                    const SizedBox(width: 4),
                    Text(
                      '+${current.coinReward}',
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AchievementsSheet extends StatelessWidget {
  const AchievementsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    L10n.t('ERFOLGE', 'ACHIEVEMENTS'),
                    style: const TextStyle(
                      color: _neonBlue,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      shadows: [Shadow(color: _neonBlue, blurRadius: 12)],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${Achievements.unlockedCount}/${achievements.length}',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 14, letterSpacing: 2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: achievements.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = achievements[i];
                    final unlocked = Achievements.isUnlocked(a.id);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(unlocked ? 24 : 10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: unlocked ? _neonBlue.withAlpha(180) : Colors.white.withAlpha(40),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            unlocked ? Icons.check_circle : Icons.lock_outline,
                            color: unlocked ? _neonBlue : const Color(0xFF555555),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.label,
                                  style: TextStyle(
                                    color: unlocked ? Colors.white : const Color(0xFF888888),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  a.description,
                                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(20),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _neonBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsSheet extends StatelessWidget {
  final PulseGame game;
  const StatsSheet({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final modes = [GameMode.classic, GameMode.zen, GameMode.hardcore];
    return Container(
      color: _bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'STATS',
                    style: TextStyle(
                      color: _neonBlue,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      shadows: [Shadow(color: _neonBlue, blurRadius: 12)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _StatTile(label: L10n.t('Runden gespielt', 'Rounds played'), value: '${Achievements.totalGames}'),
              const SizedBox(height: 10),
              _StatTile(label: L10n.t('Close-Calls gesamt', 'Total close calls'), value: '${Achievements.totalCloseCalls}'),
              const SizedBox(height: 10),
              _StatTile(
                label: L10n.t('Erfolge', 'Achievements'),
                value: '${Achievements.unlockedCount} / ${achievements.length}',
              ),
              const SizedBox(height: 24),
              Text(
                L10n.t('BESTLEISTUNGEN', 'HIGH SCORES'),
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              for (final m in modes) ...[
                _StatTile(label: m.label, value: '${game.bestScores[m] ?? 0}'),
                const SizedBox(height: 8),
              ],
              _StatTile(
                label: 'DAILY (${L10n.t('heute', 'today')})',
                value: '${game.dailyBest}',
                accent: const Color(0xFFFFCC66),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatTile({required this.label, required this.value, this.accent = _neonBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(100), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 15, letterSpacing: 2),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: accent, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}

class SkinShopSheet extends StatefulWidget {
  const SkinShopSheet({super.key});

  @override
  State<SkinShopSheet> createState() => _SkinShopSheetState();
}

class _SkinShopSheetState extends State<SkinShopSheet> {
  Future<void> _buy(Skin s) async {
    final ok = await Skins.purchase(
      s,
      coins: Wallet.value,
      spend: Wallet.spend,
    );
    if (ok) {
      await Skins.equip(s.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _equip(String id) async {
    await Skins.equip(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'SHOP',
                    style: TextStyle(
                      color: _neonBlue,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      shadows: [Shadow(color: _neonBlue, blurRadius: 12)],
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<int>(
                    valueListenable: Wallet.coins,
                    builder: (_, c, coinChild) => Row(
                      children: [
                        const Icon(Icons.circle, color: Color(0xFFFFD166), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '$c',
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: Skins.equippedId,
                  builder: (_, equippedId, listChild) => ValueListenableBuilder<int>(
                    valueListenable: Wallet.coins,
                    builder: (_, coins, walletChild) => ValueListenableBuilder<int>(
                      valueListenable: PowerUps.shieldCount,
                      builder: (_, shieldCount, pwChild) {
                        const extraRows = 2; // section header + shield tile
                        return ListView.separated(
                          itemCount: skins.length + extraRows,
                          separatorBuilder: (_, i) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i == skins.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'POWER-UPS',
                                  style: TextStyle(
                                    color: const Color(0xFF66FFCC).withAlpha(180),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                                ),
                              );
                            }
                            if (i == skins.length + 1) {
                              return _PowerUpTile(
                                icon: Icons.shield,
                                name: L10n.t('SCHILD', 'SHIELD'),
                                description: L10n.t('Überlebt 1 Kollision — aktiv im nächsten Run', 'Survives 1 collision — active in next run'),
                                cost: 35,
                                count: shieldCount,
                                affordable: coins >= 35,
                                onBuy: () async {
                                  if (coins >= 35) {
                                    await Wallet.spend(35);
                                    await PowerUps.buy();
                                    if (mounted) setState(() {});
                                  }
                                },
                              );
                            }
                            final s = skins[i];
                            final owned = Skins.isOwned(s.id);
                            final equipped = equippedId == s.id;
                            final affordable = coins >= s.cost;
                            return _SkinTile(
                              skin: s,
                              owned: owned,
                              equipped: equipped,
                              affordable: affordable,
                              onBuy: () => _buy(s),
                              onEquip: () => _equip(s.id),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerUpTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final int cost;
  final int count;
  final bool affordable;
  final VoidCallback onBuy;

  const _PowerUpTile({
    required this.icon,
    required this.name,
    required this.description,
    required this.cost,
    required this.count,
    required this.affordable,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF66FFCC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withAlpha(10),
        border: Border.all(color: accent.withAlpha(60), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11, letterSpacing: 0.5)),
                if (count > 0) ...[
                  const SizedBox(height: 4),
                  Text(L10n.t('$count im Besitz', '$count owned'),
                      style: const TextStyle(
                          color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: affordable ? onBuy : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: affordable ? accent.withAlpha(30) : Colors.transparent,
                border: Border.all(
                    color: affordable ? accent : const Color(0xFF444444), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      color: affordable ? const Color(0xFFFFD166) : const Color(0xFF555555),
                      size: 8),
                  const SizedBox(width: 4),
                  Text(
                    '$cost',
                    style: TextStyle(
                      color: affordable ? Colors.white : const Color(0xFF555555),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  final Skin skin;
  final bool owned;
  final bool equipped;
  final bool affordable;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  const _SkinTile({
    required this.skin,
    required this.owned,
    required this.equipped,
    required this.affordable,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = skin.ballColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(owned ? 22 : 10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: equipped ? accent : accent.withAlpha(owned ? 140 : 50),
          width: equipped ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _SkinPreview(skin: skin, locked: !owned),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skin.label,
                  style: TextStyle(
                    color: owned ? Colors.white : const Color(0xFF888888),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  skin.description,
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _actionButton(),
        ],
      ),
    );
  }

  Widget _actionButton() {
    if (equipped) {
      return _chip(L10n.t('AKTIV', 'ACTIVE'), skin.ballColor, filled: true);
    }
    if (owned) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onEquip,
          borderRadius: BorderRadius.circular(20),
          child: _chip(L10n.t('Tragen', 'Equip'), skin.ballColor),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: affordable ? onBuy : null,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: const Color(0xFFFFD166).withAlpha(affordable ? 220 : 80), size: 12),
            const SizedBox(width: 4),
            _chip(
              '${skin.cost}',
              affordable ? const Color(0xFFFFD166) : const Color(0xFF666666),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color.withAlpha(40) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(200), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _SkinPreview extends StatefulWidget {
  final Skin skin;
  final bool locked;
  const _SkinPreview({required this.skin, required this.locked});

  @override
  State<_SkinPreview> createState() => _SkinPreviewState();
}

class _SkinPreviewState extends State<_SkinPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, previewChild) {
        Color ball = widget.skin.ballColor;
        Color glow = widget.skin.trailColor;
        if (widget.skin.rainbow) {
          final h = (_ctrl.value * 360) % 360;
          ball = HSVColor.fromAHSV(1, h, 1, 1).toColor();
          glow = HSVColor.fromAHSV(1, (h + 40) % 360, 1, 1).toColor();
        }
        if (widget.locked) {
          ball = const Color(0xFF444444);
          glow = const Color(0xFF333333);
        }
        return Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ball,
            boxShadow: [
              BoxShadow(color: glow.withAlpha(widget.locked ? 0 : 160), blurRadius: 14),
            ],
          ),
          child: widget.locked
              ? const Icon(Icons.lock_outline, color: Color(0xFF888888), size: 20)
              : null,
        );
      },
    );
  }
}

class _MedalChip extends StatelessWidget {
  final Medal level;
  final int threshold;
  final bool earned;
  const _MedalChip({required this.level, required this.threshold, required this.earned});

  Color get _color {
    switch (level) {
      case Medal.bronze: return const Color(0xFFCD7F32);
      case Medal.silver: return const Color(0xFFC0C0C0);
      case Medal.gold: return const Color(0xFFFFD166);
      case Medal.none: return const Color(0xFF444444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: earned ? base.withAlpha(60) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: base.withAlpha(earned ? 200 : 80), width: 1),
      ),
      child: Text(
        '$threshold',
        style: TextStyle(
          color: earned ? base : base.withAlpha(120),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _HintBanner extends StatefulWidget {
  final PulseGame game;
  const _HintBanner({required this.game});

  @override
  State<_HintBanner> createState() => _HintBannerState();
}

class _HintBannerState extends State<_HintBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);
    _ctrl.forward().then((_) {
      if (mounted) widget.game.hintNotifier.value = false;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.45),
      child: FadeTransition(
        opacity: _opacity,
        child: Text(
          L10n.t('← Finger ziehen →', '← Slide finger →'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatefulWidget {
  final PulseGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _flashOpacity;
  late final Animation<Offset> _slideIn;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _flashOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.35), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slideIn = Tween(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.6, curve: Curves.easeOut)));
    _fadeIn = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.5)));
    final isNewBest = widget.game.score > 0 && widget.game.score == widget.game.bestScore;
    if (isNewBest) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isNewBest = game.score > 0 && game.score == game.bestScore;
    final isDaily = game.mode == GameMode.daily;
    final mod = isDaily ? game.todayModifier : null;
    final earnedMedal = isDaily ? medalFor(game.score, mod!) : Medal.none;

    final overlay = Container(
      color: _bg.withAlpha(220),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GAME OVER',
                  style: TextStyle(
                    color: _neonPink,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    shadows: [Shadow(color: _neonPink, blurRadius: 20)],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${game.score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 88,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (isNewBest)
                  SlideTransition(
                    position: _slideIn,
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: Text(
                        L10n.t('NEUE BESTLEISTUNG!', 'NEW HIGH SCORE!'),
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Color(0xFFFFD166), blurRadius: 12)],
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    '${L10n.t('Beste', 'Best')}: ${game.bestScore}',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                if (isDaily) ...[
                  const SizedBox(height: 20),
                  Text(
                    earnedMedal == Medal.none
                        ? L10n.t('Nächste Medaille: ${mod?.bronze}', 'Next medal: ${mod?.bronze}')
                        : '${earnedMedal.label} ${L10n.t('MEDAILLE', 'MEDAL')}',
                    style: TextStyle(
                      color: earnedMedal == Medal.gold
                          ? const Color(0xFFFFD166)
                          : earnedMedal == Medal.silver
                              ? const Color(0xFFC0C0C0)
                              : earnedMedal == Medal.bronze
                                  ? const Color(0xFFCD7F32)
                                  : const Color(0xFF888888),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                if (game.canContinue) ...[
                  _PillButton(
                    label: '↺  ${L10n.t('WEITERMACHEN', 'CONTINUE')}  •  50 🪙',
                    onTap: game.useContinue,
                    accent: const Color(0xFFFFD166),
                  ),
                  const SizedBox(height: 12),
                ],
                _PillButton(label: L10n.t('Nochmal', 'Retry'), onTap: game.retry, accent: _neonBlue),
                const SizedBox(height: 12),
                _PillButton(label: L10n.t('Menü', 'Menu'), onTap: game.backToMenu, accent: const Color(0xFF444444)),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isNewBest) return overlay;

    return Stack(
      children: [
        overlay,
        AnimatedBuilder(
          animation: _flashOpacity,
          builder: (context, child) => IgnorePointer(
            child: Container(
              color: const Color(0xFFFFD166).withAlpha((_flashOpacity.value * 255).toInt()),
            ),
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color accent;
  const _PillButton({required this.label, required this.onTap, this.accent = _neonBlue});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(30),
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: accent.withAlpha(180), width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: accent, blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: L10n.isEn,
      builder: (ctx, isEn, child) => GestureDetector(
        onTap: L10n.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(50), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white54, size: 14),
              const SizedBox(width: 5),
              Text(
                isEn ? 'EN' : 'DE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
