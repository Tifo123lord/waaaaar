import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../models/game_state.dart';
import '../../widgets/common.dart';
import '../battle/battle_report_dialog.dart';

/// Persistent frame around every campaign screen: national identity, the game
/// clock, and navigation. The clock lives here so it is always reachable.
class CampaignShell extends ConsumerStatefulWidget {
  const CampaignShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CampaignShell> createState() => _CampaignShellState();
}

class _CampaignShellState extends ConsumerState<CampaignShell> {
  String? _lastRevisionShown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final state = ref.watch(campaignProvider);

    // No campaign (e.g. after returning to the menu): bounce back.
    if (state == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.menu);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _maybeShowReport(state);

    final location = GoRouterState.of(context).uri.path;
    final index = _navIndexFor(location);

    return Scaffold(
      body: Column(
        children: [
          _CommandBar(state: state),
          Expanded(
            child: AnimatedSwitcher(
              duration: WD.normal,
              child: KeyedSubtree(key: ValueKey(location), child: widget.child),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _CampaignNav(
        index: index,
        onSelect: (i) => _navigate(i),
        l10n: l10n,
      ),
    );
  }

  void _maybeShowReport(GameState state) {
    final controller = ref.read(campaignProvider.notifier);
    final report = controller.consumeReport();
    if (report == null) return;
    if (_lastRevisionShown == '${state.revision}_${report.day}') return;
    _lastRevisionShown = '${state.revision}_${report.day}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showBattleReport(context, report, state);
    });
  }

  int _navIndexFor(String location) {
    if (location.startsWith(Routes.map)) return 0;
    if (location.startsWith(Routes.economy)) return 1;
    if (location.startsWith(Routes.military)) return 2;
    if (location.startsWith(Routes.battle)) return 3;
    if (location.startsWith(Routes.diplomacy)) return 4;
    if (location.startsWith(Routes.events)) return 5;
    return 0;
  }

  void _navigate(int index) {
    switch (index) {
      case 0:
        context.go(Routes.map);
      case 1:
        context.go(Routes.economy);
      case 2:
        context.go(Routes.military);
      case 3:
        context.go(Routes.battle);
      case 4:
        context.go(Routes.diplomacy);
      case 5:
        context.go(Routes.events);
    }
  }
}

/// Top bar: nation identity, live resources and the simulation clock.
class _CommandBar extends ConsumerWidget {
  const _CommandBar({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final controller = ref.read(campaignProvider.notifier);
    final player = state.player;
    final army = state.armyOf(state.playerId);
    final budget = controller.simulation.economy.breakdown(
      state,
      state.playerId,
    );

    return Container(
      decoration: const BoxDecoration(
        color: WD.surface1,
        border: Border(bottom: BorderSide(color: WD.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go(Routes.campaign),
                      child: Row(
                        children: [
                          CountryFlag(country: player, width: 30, height: 20),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isPersian
                                      ? player.nameFa
                                      : player.nameEn,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontSize: 13.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  fmt.date(state.date),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: WD.accent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _MiniStat(
                    label: l10n.t('res.treasury'),
                    value: fmt.credits(player.treasury),
                    valueColor: player.treasury < 0
                        ? WD.danger
                        : WD.textPrimary,
                  ),
                  _MiniStat(
                    label: l10n.t('res.net'),
                    value: fmt.creditsSigned(budget.net),
                    valueColor: signedColor(budget.net),
                  ),
                  _MiniStat(
                    label: l10n.t('res.army'),
                    value: fmt.number(army.combatScore),
                  ),
                  IconButton(
                    tooltip: l10n.t('nav.industry'),
                    onPressed: () => context.go(Routes.industry),
                    icon: Icon(
                      Icons.science_outlined,
                      size: 19,
                      color:
                          GoRouterState.of(context).uri.path == Routes.industry
                          ? WD.brass
                          : null,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: l10n.isPersian ? 'کشورهای جهان' : 'World nations',
                    onPressed: () => context.go(Routes.nations),
                    icon: Icon(
                      Icons.leaderboard_outlined,
                      size: 19,
                      color:
                          GoRouterState.of(context).uri.path == Routes.nations
                          ? WD.brass
                          : null,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: l10n.t('nav.mainMenu'),
                    onPressed: () => _confirmQuit(context, ref, l10n),
                    icon: const Icon(Icons.menu, size: 19),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _SpeedButton(
                    icon: state.speed == GameSpeed.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    label: state.speed == GameSpeed.paused
                        ? l10n.t('clock.resume')
                        : l10n.t('clock.pause'),
                    active: state.speed != GameSpeed.paused,
                    onTap: controller.togglePause,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SegmentedToggle<GameSpeed>(
                      expand: true,
                      values: const [
                        GameSpeed.paused,
                        GameSpeed.normal,
                        GameSpeed.fast,
                      ],
                      labels: [
                        l10n.t('clock.paused'),
                        l10n.t('clock.normal'),
                        l10n.t('clock.fast'),
                      ],
                      selected: state.speed,
                      onChanged: controller.setSpeed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: l10n.t('clock.stepDay'),
                    child: _SpeedButton(
                      icon: Icons.skip_next_rounded,
                      label: l10n.t('clock.stepDay'),
                      active: false,
                      onTap: () {
                        controller.setSpeed(GameSpeed.paused);
                        controller.advanceOneDay();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmQuit(
    BuildContext context,
    WidgetRef ref,
    AppStrings l10n,
  ) async {
    final confirmed = await confirmAction(
      context: context,
      title: l10n.t('nav.mainMenu'),
      message: l10n.t('save.quitConfirm'),
      confirmLabel: l10n.t('common.confirm'),
      cancelLabel: l10n.t('common.cancel'),
    );
    if (!confirmed) return;
    ref.read(campaignProvider.notifier).endCampaign();
    ref.invalidate(saveSummaryProvider);
    if (context.mounted) context.go(Routes.menu);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 8.5),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 12.5,
              color: valueColor ?? WD.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: active ? WD.accent : WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(WD.radiusSm),
          child: Container(
            width: 38,
            height: 33,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WD.radiusSm),
              border: Border.all(color: active ? WD.accent : WD.lineStrong),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? const Color(0xFF06231C) : WD.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignNav extends StatelessWidget {
  const _CampaignNav({
    required this.index,
    required this.onSelect,
    required this.l10n,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WD.line)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onSelect,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.public),
              label: l10n.t('nav.map'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_outlined),
              label: l10n.t('nav.economy'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.shield_outlined),
              label: l10n.t('nav.military'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.gps_fixed),
              label: l10n.t('nav.operations'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.handshake_outlined),
              label: l10n.t('nav.diplomacy'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              label: l10n.t('nav.events'),
            ),
          ],
        ),
      ),
    );
  }
}
