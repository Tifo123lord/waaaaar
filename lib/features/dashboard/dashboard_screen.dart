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
import '../../widgets/country_culture_view.dart';
import '../events/events_screen.dart' show EventRow;
import '../nations/country_dashboard_screen.dart';
import '../nations/nation_stats.dart';
import '../nations/nation_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final controller = ref.read(campaignProvider.notifier);
    final budget = controller.simulation.economy.breakdown(
      state,
      state.playerId,
    );
    final army = state.armyOf(state.playerId);
    final player = state.player;
    final events = state.events.recent(6).reversed.toList();

    return ListView(
      padding: WD.padScreen,
      children: [
        CountryHeroBanner(
          country: player,
          height: 150,
          onTap: () => CountryProfileScreen.open(context, player),
        ),
        const SizedBox(height: 10),
        _WorldStandingCard(state: state),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dash.overview'),
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.85,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  StatTile(
                    label: l10n.t('res.treasury'),
                    value: fmt.credits(player.treasury),
                    icon: Icons.account_balance_wallet_outlined,
                    valueColor: player.treasury < 0
                        ? WD.danger
                        : WD.textPrimary,
                  ),
                  StatTile(
                    label: l10n.t('res.net'),
                    value: fmt.creditsSigned(budget.net),
                    icon: Icons.swap_vert,
                    valueColor: signedColor(budget.net),
                  ),
                  StatTile(
                    label: l10n.t('res.army'),
                    value: fmt.number(army.combatScore),
                    icon: Icons.shield_outlined,
                  ),
                  StatTile(
                    label: l10n.t('res.population'),
                    value: fmt.number(player.population),
                    icon: Icons.people_outline,
                    footnote: l10n.t('res.bn'),
                  ),
                  StatTile(
                    label: l10n.t('res.stability'),
                    value: fmt.percentLabel(player.stability / 100),
                    icon: Icons.balance,
                  ),
                  StatTile(
                    label: l10n.t('res.industrial'),
                    value: fmt.number(player.industrial),
                    icon: Icons.factory_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.t('dash.stabilityTrend'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 5),
              Meter(fraction: player.stability / 100),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dash.economySnapshot'),
          action: TextButton(
            onPressed: () => context.go(Routes.economy),
            child: Text(l10n.t('dash.viewAll')),
          ),
          child: Column(
            children: [
              KeyValueRow(
                label: l10n.t('res.income'),
                value: fmt.money(budget.totalIncome),
                valueColor: WD.positive,
              ),
              KeyValueRow(
                label: l10n.t('res.expenses'),
                value: fmt.money(budget.totalExpenses),
                valueColor: WD.danger,
              ),
              const Divider(height: 14),
              KeyValueRow(
                label: l10n.t('res.net'),
                value: fmt.moneySigned(budget.net),
                valueColor: signedColor(budget.net),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dash.militarySnapshot'),
          action: TextButton(
            onPressed: () => context.go(Routes.military),
            child: Text(l10n.t('dash.viewAll')),
          ),
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l10n.t('mil.infantry'),
                  value: fmt.integer(army.infantryUnits),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: l10n.t('mil.armor'),
                  value: fmt.integer(army.armorUnits),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: l10n.t('mil.maintenance'),
                  value: fmt.credits(army.monthlyMaintenance),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dash.activeWars'),
          child: state.playerWars.isEmpty
              ? EmptyState(
                  message: l10n.t('dash.noWars'),
                  icon: Icons.verified_user_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final w in state.playerWars)
                      KeyValueRow(
                        label: l10n.isPersian
                            ? state
                                  .countries[w.opponentOf(state.playerId)]!
                                  .nameFa
                            : state
                                  .countries[w.opponentOf(state.playerId)]!
                                  .nameEn,
                        value: l10n.t('map.atWarTag'),
                        valueColor: WD.danger,
                        icon: Icons.gps_fixed,
                        onTap: () => context.go(Routes.battle),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dash.construction'),
          child: state.constructionOf(state.playerId).isEmpty
              ? EmptyState(
                  message: l10n.t('dash.idle'),
                  icon: Icons.construction,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final o in state.constructionOf(state.playerId)) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.t('eco.${o.type.name}.name'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            l10n.t('eco.readyIn', {
                              'n': fmt.integer(o.daysRemaining),
                            }),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Meter(fraction: o.fraction),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dash.recentEvents'),
          action: TextButton(
            onPressed: () => context.go(Routes.events),
            child: Text(l10n.t('dash.viewAll')),
          ),
          child: events.isEmpty
              ? EmptyState(
                  message: l10n.t('evt.empty'),
                  icon: Icons.receipt_long_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final e in events) EventRow(event: e, state: state),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dash.quickActions'),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(Routes.economy),
                      icon: const Icon(Icons.add_business_outlined, size: 16),
                      label: Text(l10n.t('nav.economy')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(Routes.military),
                      icon: const Icon(Icons.group_add_outlined, size: 16),
                      label: Text(l10n.t('mil.recruit')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(Routes.diplomacy),
                      icon: const Icon(Icons.handshake_outlined, size: 16),
                      label: Text(l10n.t('nav.diplomacy')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(Routes.save),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: Text(l10n.t('nav.save')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(Routes.industry),
                      icon: const Icon(Icons.science_outlined, size: 16),
                      label: Text(l10n.t('nav.industry')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(Routes.nations),
                      icon: const Icon(Icons.leaderboard_outlined, size: 16),
                      label: Text(l10n.t('nav.nations')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Compact world-standing card with shortcuts into the full nation dashboards.
class _WorldStandingCard extends StatelessWidget {
  const _WorldStandingCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fa = l10n.isPersian;
    final stats = WorldStats(state);
    final ctx = NationContext(
      state: state,
      stats: stats,
      country: state.player,
      l10n: l10n,
    );
    final top = stats.ordered(NationMetric.power).take(3).toList();
    return Panel(
      accentBorder: true,
      title: fa ? 'جایگاه جهانی' : 'World standing',
      action: TextButton(
        onPressed: () => context.go(Routes.nations),
        child: Text(fa ? 'همه کشورها' : 'All nations'),
      ),
      child: Column(
        children: [
          FigureGrid(
            columns: 4,
            spacing: 6,
            children: [
              for (final m in const [
                NationMetric.power,
                NationMetric.income,
                NationMetric.army,
                NationMetric.industry,
              ])
                Column(
                  children: [
                    Text(
                      ctx.labels.metricShort(m),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${ctx.fmt.integer(stats.rankOf(ctx.id, m))}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: stats.rankOf(ctx.id, m) <= 3
                            ? WD.brass
                            : WD.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < top.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => CountryDashboardScreen.open(context, top[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: WD.surface2,
                        borderRadius: BorderRadius.circular(WD.radiusSm),
                        border: Border.all(
                          color: top[i] == ctx.id ? WD.brassDim : WD.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            ctx.fmt.integer(i + 1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: WD.brass,
                            ),
                          ),
                          const SizedBox(width: 5),
                          CountryFlag(
                            country: state.countries[top[i]]!,
                            width: 20,
                            height: 13,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              fa
                                  ? state.countries[top[i]]!.shortFa
                                  : state.countries[top[i]]!.shortEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: WD.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => CountryDashboardScreen.open(context, ctx.id),
              icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
              label: Text(
                fa ? 'داشبورد کامل کشور من' : 'Open my full national dashboard',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
