import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../models/country.dart';
import '../../models/diplomatic_agreement.dart';
import '../../models/game_state.dart';
import '../../widgets/common.dart';
import '../country_selection/country_selection_screen.dart' show CountryDossier;
import '../../widgets/country_culture_view.dart';
import '../nations/country_dashboard_screen.dart';
import 'world_map_view.dart';

/// In-campaign world map: political / military layers, country dossiers.
class WorldMapScreen extends ConsumerStatefulWidget {
  const WorldMapScreen({super.key});

  @override
  ConsumerState<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends ConsumerState<WorldMapScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final state = ref.watch(campaignProvider);
    final settings = ref.watch(settingsProvider);
    final layer = settings.defaultMapMode == GameMapMode.military
        ? MapLayer.military
        : MapLayer.political;

    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final selected = _selectedId == null ? null : state.countries[_selectedId!];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedToggle<GameMapMode>(
                  expand: true,
                  values: const [GameMapMode.political, GameMapMode.military],
                  labels: [l10n.t('map.political'), l10n.t('map.military')],
                  selected: settings.defaultMapMode,
                  onChanged: ref
                      .read(settingsProvider.notifier)
                      .setDefaultMapMode,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: WD.mapVoid,
              borderRadius: BorderRadius.circular(WD.radiusMd),
              border: Border.all(color: WD.lineStrong),
            ),
            child: WorldMapView(
              state: state,
              layer: layer,
              selectedId: _selectedId,
              onSelect: (id) => setState(() => _selectedId = id),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: MapLegend(layer: layer, state: state),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              Icon(Icons.pan_tool_outlined, size: 12, color: WD.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.t('map.instructions'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
        if (selected != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: WD.surface1,
              border: Border(top: BorderSide(color: WD.line)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.t('map.closeUp').toUpperCase(),
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: WD.accent),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _selectedId = null),
                      ),
                    ],
                  ),
                  CountryHeroBanner(
                    country: selected,
                    height: 120,
                    onTap: () => CountryProfileScreen.open(context, selected),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () =>
                        CountryDashboardScreen.open(context, selected.id),
                    icon: const Icon(Icons.dashboard_outlined, size: 16),
                    label: Text(
                      l10n.isPersian
                          ? 'داشبورد کامل ${selected.nameFa}'
                          : 'Full ${selected.nameEn} dashboard',
                    ),
                  ),
                  const SizedBox(height: 10),
                  CountryDossier(country: selected),
                  const SizedBox(height: 10),
                  _RelationsRow(
                    state: state,
                    country: selected,
                    fmt: fmt,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.t('map.selectHint'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _RelationsRow extends StatelessWidget {
  const _RelationsRow({
    required this.state,
    required this.country,
    required this.fmt,
    required this.l10n,
  });

  final GameState state;
  final Country country;
  final Fmt fmt;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    final relation = state.player.relations[country.id] ?? 0;
    final atWar = state.atWarWith(state.playerId, country.id);
    final ally = state.alliesOf(state.playerId).contains(country.id);
    final pact = state.hasAgreement(
      state.playerId,
      country.id,
      AgreementType.nonAggression,
    );

    return Container(
      padding: const EdgeInsets.all(11),
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
              Text(
                l10n.t('map.relations').toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: WD.accent),
              ),
              const Spacer(),
              if (atWar) Tag(l10n.t('map.atWarTag'), color: WD.danger),
              if (ally) Tag(l10n.t('map.alliance'), color: WD.ally),
              if (pact && !ally) Tag(l10n.t('map.pact'), color: WD.accent),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('map.relations'),
                  value: fmt.number(relation),
                  valueColor: signedColor(relation),
                  footnote: l10n.t('dip.attitude.${_attitude(relation)}'),
                ),
              ),
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('map.armyStrength'),
                  value: fmt.number(state.armyOf(country.id).combatScore),
                ),
              ),
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('res.stability'),
                  value: fmt.percentLabel(country.stability / 100),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _attitude(double r) {
    if (r <= -45) return 'hostile';
    if (r <= -15) return 'cold';
    if (r < 20) return 'neutral';
    if (r < 55) return 'warm';
    return 'friendly';
  }
}
