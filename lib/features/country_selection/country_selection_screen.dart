import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/balance.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../data/country_data.dart';
import '../../models/country.dart';
import '../../simulation/economy_engine.dart';
import '../../widgets/common.dart';
import '../../widgets/country_culture_view.dart';
import '../../widgets/leaders_view.dart';
import '../../data/country_leaders.dart';
import '../world_map/world_map_view.dart';

/// Country selection: interactive map *and* a searchable list, both feeding the
/// same selection, with a full dossier preview before committing.
class CountrySelectionScreen extends ConsumerStatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  ConsumerState<CountrySelectionScreen> createState() =>
      _CountrySelectionScreenState();
}

class _CountrySelectionScreenState
    extends ConsumerState<CountrySelectionScreen> {
  final TextEditingController _search = TextEditingController();
  bool _listMode = false;
  String? _selectedId;
  String _query = '';

  List<Country> get _countries => CountryData.build();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Country? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in _countries) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Country> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _countries;
    return _countries
        .where((c) {
          return c.nameEn.toLowerCase().contains(q) ||
              c.nameFa.contains(_query.trim()) ||
              c.shortEn.toLowerCase().contains(q) ||
              c.capitalEn.toLowerCase().contains(q) ||
              c.capitalFa.contains(_query.trim()) ||
              c.iso.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  void _start() {
    final country = _selected;
    if (country == null) return;
    // A new campaign replaces any previous save slot on first save.
    ref.read(campaignProvider.notifier).startNewCampaign(country.id);
    context.go(Routes.campaign);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('select.title')),
        actions: [
          IconButton(
            tooltip: _listMode ? l10n.t('select.map') : l10n.t('select.list'),
            onPressed: () => setState(() => _listMode = !_listMode),
            icon: Icon(_listMode ? Icons.public : Icons.format_list_bulleted),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: l10n.t('select.search'),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: WD.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.t('select.tapHint'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      SegmentedToggle<bool>(
                        values: const [false, true],
                        labels: [l10n.t('select.map'), l10n.t('select.list')],
                        selected: _listMode,
                        onChanged: (v) => setState(() => _listMode = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _listMode || _query.trim().isNotEmpty
                  ? _NationList(
                      countries: _filtered,
                      selectedId: _selectedId,
                      onSelect: (id) => setState(() => _selectedId = id),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(WD.radiusMd),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: WD.line),
                            borderRadius: BorderRadius.circular(WD.radiusMd),
                          ),
                          child: WorldMapView(
                            selectedId: _selectedId,
                            onSelect: (id) => setState(() => _selectedId = id),
                          ),
                        ),
                      ),
                    ),
            ),
            _SelectionBar(
              country: selected,
              onStart: selected == null ? null : _start,
              onClear: selected == null
                  ? null
                  : () => setState(() => _selectedId = null),
            ),
          ],
        ),
      ),
    );
  }
}

class _NationList extends StatelessWidget {
  const _NationList({
    required this.countries,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Country> countries;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final economy = const EconomyEngine();

    if (countries.isEmpty) {
      return EmptyState(
        message: l10n.t('select.noResults'),
        icon: Icons.search_off,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      itemCount: countries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = countries[index];
        final selected = c.id == selectedId;
        final name = l10n.isPersian ? c.nameFa : c.nameEn;
        final capital = l10n.isPersian ? c.capitalFa : c.capitalEn;
        final army = CountryData.startingArmy[c.id] ?? const [0, 0];

        return Material(
          color: selected ? WD.surface3 : WD.surface1,
          borderRadius: BorderRadius.circular(WD.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(WD.radiusMd),
            onTap: () => onSelect(c.id),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(WD.radiusMd),
                border: Border.all(
                  color: selected ? WD.brass : WD.line,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CountryEmblem(countryId: c.id, size: 38),
                      const SizedBox(width: 8),
                      CountryFlag(country: c, width: 34, height: 22),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(fontSize: 14.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${l10n.t('select.capital')}: $capital · ${c.iso}',
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Tag(
                        l10n.t('ai.${c.personality.name}'),
                        color: WD.textSecondary,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l10n.isPersian
                            ? 'شناسنامه کشور'
                            : 'Country profile',
                        onPressed: () => CountryProfileScreen.open(context, c),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                          color: WD.brass,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          compact: true,
                          label: l10n.t('res.treasury'),
                          value: fmt.credits(c.treasury),
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          compact: true,
                          label: l10n.t('res.industrial'),
                          value: fmt.number(c.industrial),
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          compact: true,
                          label: l10n.t('res.stability'),
                          value: fmt.percentLabel(c.stability / 100),
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          compact: true,
                          label: l10n.t('res.army'),
                          value: '${army[0] + army[1]}',
                          footnote: '${army[0]}+ / ${army[1]}⚙',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.trending_up, size: 12, color: WD.positive),
                      const SizedBox(width: 5),
                      Text(
                        '${fmt.money(economy.previewMonthlyIncome(c))} '
                        '${l10n.t('common.perMonth')}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: WD.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${l10n.t('res.population')}: '
                        '${fmt.number(c.population)} ${l10n.t('res.bn')}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom summary bar with the primary call to action.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.country,
    required this.onStart,
    required this.onClear,
  });

  final Country? country;
  final VoidCallback? onStart;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: WD.surface1,
        border: Border(top: BorderSide(color: WD.line)),
      ),
      child: Column(
        children: [
          if (country == null) ...[
            Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 15, color: WD.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.t('select.subtitle'), style: text.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else ...[
            CountryHeroBanner(
              country: country!,
              height: 104,
              onTap: () => CountryProfileScreen.open(context, country!),
            ),
            const SizedBox(height: 10),
            CountryDossier(
              country: country!,
              onOpenDetails: null,
              collapsed: true,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (onClear != null) ...[
                OutlinedButton(
                  onPressed: onClear,
                  child: Text(l10n.t('common.cancel')),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.flag_outlined, size: 17),
                  label: Text(l10n.t('select.start')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The rich country preview card, reused by the map dossier sheet.
class CountryDossier extends StatelessWidget {
  const CountryDossier({
    super.key,
    required this.country,
    this.state,
    this.onOpenDetails,
    this.collapsed = false,
  });

  final Country country;

  /// When non-null the dossier is rendered inside a live campaign (shows
  /// relations, alliances and current army strength from the running game).
  final dynamic state;

  final VoidCallback? onOpenDetails;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final text = Theme.of(context).textTheme;
    final economy = const EconomyEngine();
    final name = l10n.isPersian ? country.nameFa : country.nameEn;
    final capital = l10n.isPersian ? country.capitalFa : country.capitalEn;
    final strengths = l10n.isPersian
        ? country.strengthsFa
        : country.strengthsEn;
    final weaknesses = l10n.isPersian
        ? country.weaknessesFa
        : country.weaknessesEn;
    final army = CountryData.startingArmy[country.id] ?? const [0, 0];

    final income = economy.previewMonthlyIncome(country);
    final civil =
        country.population * 3.6 * (0.6 + country.infrastructure / 160);
    final military =
        army[0] * Balance.units[UnitType.infantry]!.maintenance +
        army[1] * Balance.units[UnitType.armor]!.maintenance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CountryFlag(country: country, width: 40, height: 26),
            const SizedBox(width: 8),
            CountryEmblem(countryId: country.id, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: text.titleMedium?.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${l10n.t('select.capital')}: $capital',
                        style: text.labelSmall,
                      ),
                      const SizedBox(width: 8),
                      Tag(l10n.t('select.doctrine'), color: WD.textMuted),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          l10n.t('ai.${country.personality.name}'),
                          style: text.labelSmall?.copyWith(color: WD.accent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onOpenDetails != null)
              IconButton(
                onPressed: onOpenDetails,
                icon: const Icon(Icons.open_in_new, size: 17),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.35,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            StatTile(
              label: l10n.t('res.treasury'),
              value: fmt.credits(country.treasury),
              icon: Icons.account_balance_wallet_outlined,
            ),
            StatTile(
              label: l10n.t('res.income'),
              value: fmt.credits(income),
              icon: Icons.trending_up,
              valueColor: WD.positive,
              footnote: l10n.t('common.perMonth'),
            ),
            StatTile(
              label: l10n.t('res.expenses'),
              value: fmt.credits(civil + military),
              icon: Icons.trending_down,
              valueColor: WD.danger,
              footnote: l10n.t('common.perMonth'),
            ),
            StatTile(
              label: l10n.t('res.industrial'),
              value: fmt.number(country.industrial),
              icon: Icons.factory_outlined,
            ),
            StatTile(
              label: l10n.t('res.stability'),
              value: fmt.percentLabel(country.stability / 100),
              icon: Icons.balance,
            ),
            StatTile(
              label: l10n.t('res.population'),
              value: fmt.number(country.population),
              icon: Icons.people_outline,
              footnote: l10n.t('res.bn'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: WD.surface2,
            borderRadius: BorderRadius.circular(WD.radiusSm),
            border: Border.all(color: WD.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.military_tech_outlined,
                    size: 13,
                    color: WD.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.t('select.startingForces').toUpperCase(),
                    style: text.labelSmall?.copyWith(color: WD.accent),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: l10n.t('mil.infantry'),
                      value: fmt.integer(army[0]),
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: l10n.t('mil.armor'),
                      value: fmt.integer(army[1]),
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      compact: true,
                      label: l10n.t('res.budget'),
                      value: fmt.number(country.militaryBudget, decimals: 2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!collapsed) ...[
          if (CountryLeaders.has(country.id)) ...[
            const SizedBox(height: 12),
            Text(
              (l10n.isPersian ? 'رهبران و مقامات' : 'Leaders & officials')
                  .toUpperCase(),
              style: text.labelSmall?.copyWith(color: WD.accent),
            ),
            const SizedBox(height: 6),
            LeaderStrip(leaders: CountryLeaders.of(country.id), height: 140),
          ],
          const SizedBox(height: 12),
          _ProsCons(
            strengths: strengths,
            weaknesses: weaknesses,
            strengthsLabel: l10n.t('select.strengths'),
            weaknessesLabel: l10n.t('select.weaknesses'),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('select.neighbours').toUpperCase(),
            style: text.labelSmall?.copyWith(color: WD.accent),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in country.theatres)
                _theatreChip(context, id, l10n),
            ],
          ),
        ],
      ],
    );
  }

  Widget _theatreChip(BuildContext context, String id, AppStrings l10n) {
    Country? match;
    for (final c in CountryData.build()) {
      if (c.id == id) match = c;
    }
    final label = match == null
        ? id.toUpperCase()
        : (l10n.isPersian ? match.nameFa : match.nameEn);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: WD.line),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: WD.textSecondary),
      ),
    );
  }
}

class _ProsCons extends StatelessWidget {
  const _ProsCons({
    required this.strengths,
    required this.weaknesses,
    required this.strengthsLabel,
    required this.weaknessesLabel,
  });

  final String strengths;
  final String weaknesses;
  final String strengthsLabel;
  final String weaknessesLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Block(
            icon: Icons.trending_up,
            color: WD.positive,
            label: strengthsLabel,
            body: strengths,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Block(
            icon: Icons.trending_down,
            color: WD.warning,
            label: weaknessesLabel,
            body: weaknesses,
          ),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.color,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: WD.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
