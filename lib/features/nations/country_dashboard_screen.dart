import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../data/country_culture.dart';
import '../../data/country_leaders.dart';
import '../../widgets/common.dart';
import '../../widgets/country_culture_view.dart';
import '../../widgets/leaders_view.dart';
import 'nation_stats.dart';
import 'nation_tabs.dart';
import 'nation_widgets.dart';

/// Full live dashboard for any nation in the campaign.
///
/// Six tabs — overview, economy, military, diplomacy, development and
/// intelligence — all computed from the running [GameState], so the numbers
/// update every in-game day while the screen is open.
class CountryDashboardScreen extends ConsumerStatefulWidget {
  const CountryDashboardScreen({
    super.key,
    required this.countryId,
    this.initialTab = 0,
  });

  final String countryId;
  final int initialTab;

  static Future<void> open(
    BuildContext context,
    String countryId, {
    int tab = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CountryDashboardScreen(countryId: countryId, initialTab: tab),
      ),
    );
  }

  @override
  ConsumerState<CountryDashboardScreen> createState() =>
      _CountryDashboardScreenState();
}

class _CountryDashboardScreenState extends ConsumerState<CountryDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 7,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 6),
  );
  late String _countryId = widget.countryId;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fa = l10n.isPersian;
    final state = ref.watch(campaignProvider);
    if (state == null || !state.countries.containsKey(_countryId)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final country = state.countries[_countryId]!;
    final stats = WorldStats(state);
    final ctx = NationContext(
      state: state,
      stats: stats,
      country: country,
      l10n: l10n,
    );

    final tabLabels = fa
        ? [
            'نمای کلی',
            'رهبران',
            'اقتصاد',
            'ارتش',
            'دیپلماسی',
            'توسعه',
            'اطلاعات',
          ]
        : [
            'Overview',
            'Leaders',
            'Economy',
            'Military',
            'Diplomacy',
            'Development',
            'Intel',
          ];

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 252,
            backgroundColor: WD.surface1,
            title: Row(
              children: [
                CountryFlag(country: country, width: 26, height: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fa ? country.nameFa : country.nameEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: fa ? 'شناسنامه کشور' : 'National profile',
                icon: const Icon(Icons.badge_outlined, size: 20),
                onPressed: () => CountryProfileScreen.open(context, country),
              ),
              IconButton(
                tooltip: fa ? 'کشور دیگر' : 'Switch nation',
                icon: const Icon(Icons.swap_horiz, size: 20),
                onPressed: () => _pickCountry(context, ctx),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _Header(ctx: ctx),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                color: WD.surface1,
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final t in tabLabels) Tab(text: t, height: 42)],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            OverviewTab(ctx: ctx, onOpenTab: (i) => _tabs.animateTo(i)),
            LeadersTab(ctx: ctx),
            EconomyTab(ctx: ctx),
            MilitaryTab(ctx: ctx),
            DiplomacyTab(ctx: ctx, onOpenNation: _switchTo),
            DevelopmentTab(ctx: ctx),
            IntelTab(ctx: ctx, onOpenNation: _switchTo),
          ],
        ),
      ),
    );
  }

  void _switchTo(String id) {
    if (id == _countryId) return;
    setState(() => _countryId = id);
  }

  Future<void> _pickCountry(BuildContext context, NationContext ctx) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: WD.surface1,
      isScrollControlled: true,
      builder: (_) => NationPickerSheet(ctx: ctx, currentId: _countryId),
    );
    if (picked != null) _switchTo(picked);
  }
}

/// Hero header: landmark photo, emblem, tier, capital and key tags.
class _Header extends StatelessWidget {
  const _Header({required this.ctx});

  final NationContext ctx;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fa = ctx.fa;
    final c = ctx.country;
    final culture = CountryCulture.of(c.id);
    final landmark = culture != null && culture.landmarks.isNotEmpty
        ? culture.landmarks.first.asset
        : null;
    final state = ctx.state;
    final atWar = state.wars.any((w) => w.involves(c.id));
    final bloc = state.politics.blocOf(c.id);
    final tier = ctx.stats.tierOf(c.id);
    final relation = state.player.relations[c.id] ?? 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (landmark != null)
          Image.asset(
            landmark,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          )
        else
          Image.asset(
            CountryCulture.flagAsset(c.id),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC07090B), Color(0x5507090B), Color(0xF207090B)],
              stops: [0, 0.4, 0.92],
            ),
          ),
        ),
        PositionedDirectional(
          start: 14,
          end: 14,
          bottom: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountryEmblem(countryId: c.id, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (CountryLeaders.has(c.id)) ...[
                      ParamountLeaderChip(countryId: c.id),
                      const SizedBox(height: 6),
                    ],
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        Tag(
                          ctx.labels.tier(tier).toUpperCase(),
                          color: tier == NationTier.superpower
                              ? WD.brass
                              : WD.accent,
                          filled: true,
                        ),
                        if (ctx.isPlayer)
                          Tag(
                            fa ? 'کشور شما' : 'YOUR NATION',
                            color: WD.brass,
                            icon: Icons.star,
                          ),
                        if (atWar)
                          Tag(
                            fa ? 'در جنگ' : 'AT WAR',
                            color: WD.danger,
                            icon: Icons.gps_fixed,
                            filled: true,
                          ),
                        if (bloc != null)
                          Tag(
                            fa ? bloc.nameFa : bloc.nameEn,
                            color: Color(bloc.colorArgb),
                          ),
                        if (!ctx.isPlayer)
                          Tag(
                            ctx.l10n.t('dip.attitude.${attitudeKey(relation)}'),
                            color: signedColor(relation),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fa ? c.nameFa : c.nameEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_city,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${fa ? c.capitalFa : c.capitalEn} · ${ctx.l10n.t('ai.${c.personality.name}')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fa ? 'رتبه قدرت' : 'POWER RANK',
                    style: text.labelSmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    '#${ctx.fmt.integer(ctx.stats.rankOf(c.id, NationMetric.power))}',
                    style: text.headlineSmall?.copyWith(
                      color: WD.brass,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '/ ${ctx.fmt.integer(ctx.stats.count)}',
                    style: text.labelSmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Searchable bottom sheet used to jump between nations.
class NationPickerSheet extends StatefulWidget {
  const NationPickerSheet({
    super.key,
    required this.ctx,
    required this.currentId,
  });

  final NationContext ctx;
  final String currentId;

  @override
  State<NationPickerSheet> createState() => _NationPickerSheetState();
}

class _NationPickerSheetState extends State<NationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final ids = ctx.stats.ordered(NationMetric.power).where((id) {
      if (_query.isEmpty) return true;
      final c = ctx.state.countries[id]!;
      final q = _query.toLowerCase();
      return c.nameEn.toLowerCase().contains(q) ||
          c.nameFa.contains(_query) ||
          c.iso.toLowerCase() == q;
    }).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WD.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: ctx.l10n.t('select.search'),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ids.length,
                itemBuilder: (context, i) {
                  final id = ids[i];
                  final c = ctx.state.countries[id]!;
                  return ListTile(
                    dense: true,
                    selected: id == widget.currentId,
                    leading: CountryFlag(country: c, width: 30, height: 20),
                    title: Text(ctx.nameOf(id)),
                    subtitle: Text(
                      '${ctx.labels.metricShort(NationMetric.power)} ${ctx.fmt.number(ctx.stats.of(id)[NationMetric.power])}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    trailing: RankBadge(
                      rank: ctx.stats.rankOf(id, NationMetric.power),
                      of: ctx.stats.count,
                      fmt: ctx.fmt,
                    ),
                    onTap: () => Navigator.of(context).pop(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
