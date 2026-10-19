import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../models/history.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import 'country_dashboard_screen.dart';
import 'nation_stats.dart';
import 'nation_widgets.dart';

/// World index: every nation, sortable by any metric, with live figures.
class NationsScreen extends ConsumerStatefulWidget {
  const NationsScreen({super.key});

  @override
  ConsumerState<NationsScreen> createState() => _NationsScreenState();
}

enum _Filter { all, allies, rivals, atWar, bloc }

class _NationsScreenState extends ConsumerState<NationsScreen> {
  NationMetric _metric = NationMetric.power;
  _Filter _filter = _Filter.all;
  String _query = '';
  bool _ascending = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fa = l10n.isPersian;
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final stats = WorldStats(state);
    final ctx = NationContext(
      state: state,
      stats: stats,
      country: state.player,
      l10n: l10n,
    );
    final labels = ctx.labels;
    final playerId = state.playerId;
    final allies = state.alliesOf(playerId).toSet();
    final playerBloc = state.politics.blocOf(playerId);

    var ids = stats.ordered(_metric).toList();
    if (_ascending) ids = ids.reversed.toList();
    ids = ids.where((id) {
      final c = state.countries[id]!;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!c.nameEn.toLowerCase().contains(q) &&
            !c.nameFa.contains(_query) &&
            c.iso.toLowerCase() != q) {
          return false;
        }
      }
      return switch (_filter) {
        _Filter.all => true,
        _Filter.allies => allies.contains(id) || id == playerId,
        _Filter.rivals => (state.player.relations[id] ?? 0) <= -15,
        _Filter.atWar => state.wars.any((w) => w.involves(id)),
        _Filter.bloc => playerBloc != null && playerBloc.contains(id),
      };
    }).toList();

    final maxValue = stats.maxOf(_metric);
    final top = stats.ordered(NationMetric.power).take(5).toList();
    final colors = [WD.brass, WD.info, WD.accent, WD.warning, WD.danger];

    final filterLabels = {
      _Filter.all: fa ? 'همه' : 'All',
      _Filter.allies: fa ? 'متحدان' : 'Allies',
      _Filter.rivals: fa ? 'رقبا' : 'Rivals',
      _Filter.atWar: fa ? 'در جنگ' : 'At war',
      _Filter.bloc: fa ? 'بلوک من' : 'My bloc',
    };

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: fa ? 'خلاصه جهان' : 'World summary',
          child: Column(
            children: [
              FigureGrid(
                columns: 3,
                children: [
                  MiniFigure(
                    icon: Icons.flag_outlined,
                    label: fa ? 'کشورها' : 'Nations',
                    value: ctx.fmt.integer(stats.count),
                  ),
                  MiniFigure(
                    icon: Icons.local_fire_department_outlined,
                    label: fa ? 'جنگ‌های فعال' : 'Active wars',
                    value: ctx.fmt.integer(state.wars.length),
                    color: state.wars.isEmpty ? WD.positive : WD.danger,
                  ),
                  MiniFigure(
                    icon: Icons.hub_outlined,
                    label: fa ? 'بلوک‌ها' : 'Blocs',
                    value: ctx.fmt.integer(state.politics.blocs.length),
                  ),
                  MiniFigure(
                    icon: Icons.block,
                    label: fa ? 'تحریم‌ها' : 'Sanctions',
                    value: ctx.fmt.integer(state.politics.sanctions.length),
                  ),
                  MiniFigure(
                    icon: Icons.warning_amber_outlined,
                    label: fa ? 'تنش جهانی' : 'World tension',
                    value: ctx.fmt.percentLabel(state.politics.tension / 100),
                    color: state.politics.tension > 60
                        ? WD.danger
                        : state.politics.tension > 35
                        ? WD.warning
                        : WD.positive,
                  ),
                  MiniFigure(
                    icon: Icons.star_outline,
                    label: fa ? 'رتبه شما' : 'Your rank',
                    value:
                        '#${ctx.fmt.integer(stats.rankOf(playerId, NationMetric.power))}',
                    color: WD.brass,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Meter(
                fraction: state.politics.tension / 100,
                color: state.politics.tension > 60 ? WD.danger : WD.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: fa ? 'رقابت ۵ قدرت برتر' : 'Top five power race',
          child: TrendChart(
            height: 130,
            emptyLabel: fa
                ? 'داده کافی نیست — چند روز بازی را جلو ببرید.'
                : 'Not enough data yet — let a few days pass.',
            formatValue: (v) => ctx.fmt.number(v),
            series: [
              for (var i = 0; i < top.length; i++)
                ChartSeries(
                  values: state.history.raw(top[i], HistoryMetric.power),
                  color: colors[i],
                  label: ctx.nameOf(top[i]),
                  fill: false,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: l10n.t('select.search'),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in _Filter.values) ...[
                ChoiceChip(
                  label: Text(
                    filterLabels[f]!,
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              IconButton(
                tooltip: fa ? 'ترتیب' : 'Order',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
                onPressed: () => setState(() => _ascending = !_ascending),
              ),
              for (final m in NationMetric.values) ...[
                ChoiceChip(
                  avatar: Icon(NationContext.iconOf(m), size: 13),
                  label: Text(
                    labels.metricShort(m),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _metric == m,
                  onSelected: (_) => setState(() => _metric = m),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Panel(
          title:
              '${fa ? 'رتبه‌بندی بر اساس' : 'Ranked by'} ${labels.metric(_metric)} (${ctx.fmt.integer(ids.length)})',
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: ids.isEmpty
              ? EmptyState(
                  message: l10n.t('select.noResults'),
                  icon: Icons.search_off,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final id in ids)
                      _NationRow(
                        ctx: ctx,
                        id: id,
                        metric: _metric,
                        rank: stats.rankOf(id, _metric),
                        fraction: maxValue <= 0
                            ? 0
                            : (stats.of(id)[_metric] / maxValue).clamp(
                                0.0,
                                1.0,
                              ),
                        ally: allies.contains(id),
                        onTap: () => CountryDashboardScreen.open(context, id),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _NationRow extends StatelessWidget {
  const _NationRow({
    required this.ctx,
    required this.id,
    required this.metric,
    required this.rank,
    required this.fraction,
    required this.ally,
    required this.onTap,
  });

  final NationContext ctx;
  final String id;
  final NationMetric metric;
  final int rank;
  final double fraction;
  final bool ally;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = ctx.state;
    final c = state.countries[id]!;
    final isPlayer = id == state.playerId;
    final atWarWithPlayer = state.atWarWith(state.playerId, id);
    final atWar = state.wars.any((w) => w.involves(id));
    final rel = state.player.relations[id] ?? 0;
    final snap = ctx.stats.of(id);
    final trend = state.history.raw(id, HistoryMetric.power);
    final delta = trend.isEmpty ? 0.0 : trend.last - trend.first;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WD.radiusSm),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
        decoration: BoxDecoration(
          color: isPlayer ? WD.brass.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(WD.radiusSm),
          border: Border.all(
            color: isPlayer ? WD.brassDim : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                ctx.fmt.integer(rank),
                style: text.titleSmall?.copyWith(
                  fontSize: 12,
                  color: rank <= 3 ? WD.brass : WD.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            CountryFlag(country: c, width: 30, height: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ctx.nameOf(id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontSize: 12.5,
                            color: isPlayer ? WD.brass : WD.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (atWarWithPlayer)
                        const Icon(Icons.gps_fixed, size: 12, color: WD.danger)
                      else if (atWar)
                        const Icon(
                          Icons.local_fire_department,
                          size: 12,
                          color: WD.warning,
                        ),
                      if (ally)
                        const Icon(Icons.handshake, size: 12, color: WD.ally),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(
                      children: [
                        Container(height: 4, color: WD.surface3),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 4,
                            color: isPlayer ? WD.brass : WD.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${ctx.labels.metricShort(NationMetric.army)} ${ctx.fmt.number(snap[NationMetric.army])} · '
                    '${ctx.labels.metricShort(NationMetric.stability)} ${ctx.fmt.percentLabel(snap[NationMetric.stability] / 100)}'
                    '${isPlayer ? '' : ' · ${ctx.l10n.t('dip.attitude.${attitudeKey(rel)}')}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ctx.value(metric, snap[metric]),
                  style: text.titleSmall?.copyWith(
                    fontSize: 12.5,
                    color: metric == NationMetric.net
                        ? signedColor(snap[metric])
                        : WD.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (trend.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        delta >= 0
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        size: 16,
                        color: signedColor(delta),
                      ),
                      Text(
                        ctx.fmt.number(delta.abs()),
                        style: text.labelSmall?.copyWith(
                          fontSize: 9,
                          color: signedColor(delta),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Icon(Icons.chevron_right, size: 16, color: WD.textMuted),
          ],
        ),
      ),
    );
  }
}
