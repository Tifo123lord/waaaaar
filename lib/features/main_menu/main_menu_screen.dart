import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../data/country_data.dart';
import '../../data/save_repository.dart';
import '../../models/country.dart';
import '../../widgets/common.dart';
import '../world_map/world_map_view.dart';

/// The premium title screen.
class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen> {
  bool _loading = false;

  Future<void> _continue() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await SaveRepository().load();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.ok) {
      final message = switch (result.failure) {
        LoadFailure.missing => 'menu.noSave',
        LoadFailure.unsupportedVersion => 'save.loadFailed',
        _ => 'save.corrupted',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).t(message))),
      );
      ref.invalidate(saveSummaryProvider);
      return;
    }

    ref.read(campaignProvider.notifier).loadState(result.state!);
    if (!mounted) return;
    context.go(Routes.campaign);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final summary = ref.watch(saveSummaryProvider);
    final hasSave = summary.valueOrNull != null;

    return Scaffold(
      body: Stack(
        children: [
          // The painted world map as a full-screen backdrop, non-interactive.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: WorldMapView(
                  selectedId: null,
                  onSelect: (_) {},
                  showLabels: false,
                  interactive: false,
                ),
              ),
            ),
          ),
          // Depth: darken the poles and edges so the title block stays legible.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.32, 0.62, 1.0],
                  colors: [
                    Color(0xE606090B),
                    Color(0x8A06090B),
                    Color(0x4006090B),
                    Color(0xEE06090B),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.95,
                  colors: [
                    Colors.transparent,
                    WD.void0.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  _TitleBlock(l10n: l10n),
                  const Spacer(flex: 2),
                  _MenuButton(
                    label: l10n.t('menu.newCampaign'),
                    icon: Icons.public,
                    primary: true,
                    onTap: () => context.push(Routes.newCampaign),
                  ),
                  const SizedBox(height: 10),
                  _MenuButton(
                    label: l10n.t('menu.continueCampaign'),
                    icon: Icons.restore,
                    enabled: hasSave && !_loading,
                    loading: _loading,
                    onTap: _continue,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MenuButton(
                          label: l10n.t('menu.settings'),
                          icon: Icons.tune,
                          onTap: () => context.push(Routes.settings),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MenuButton(
                          label: l10n.t('menu.about'),
                          icon: Icons.info_outline,
                          onTap: () => context.push(Routes.about),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SaveSlotCard(summary: summary.valueOrNull, fmt: fmt),
                  const Spacer(flex: 2),
                  _Footer(l10n: l10n),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.l10n});

  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const BrandEmblem(size: 132),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 34, height: 1, color: WD.brassDim),
            const SizedBox(width: 8),
            Icon(Icons.star, size: 8, color: WD.brass),
            const SizedBox(width: 8),
            Container(width: 34, height: 1, color: WD.brassDim),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.t('app.name'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: WD.textPrimary,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.t('app.tagline').toUpperCase(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: WD.accent,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final background = primary
        ? WD.accent
        : enabled
        ? WD.surface1.withValues(alpha: 0.88)
        : WD.surface1.withValues(alpha: 0.45);
    final foreground = primary
        ? const Color(0xFF06231C)
        : enabled
        ? WD.textPrimary
        : WD.textMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(WD.radiusSm),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WD.radiusSm),
              border: Border.all(
                color: primary
                    ? WD.accent
                    : enabled
                    ? WD.lineStrong
                    : WD.line,
              ),
            ),
            child: Row(
              children: [
                if (loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontSize: 14,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: foreground.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveSlotCard extends StatelessWidget {
  const _SaveSlotCard({required this.summary, required this.fmt});

  final SaveSummary? summary;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final text = Theme.of(context).textTheme;

    if (summary == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: WD.surface1.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(WD.radiusSm),
          border: Border.all(color: WD.line),
        ),
        child: Row(
          children: [
            Icon(Icons.save_outlined, size: 15, color: WD.textMuted),
            const SizedBox(width: 9),
            Expanded(child: Text(l10n.t('menu.noSave'), style: text.bodySmall)),
          ],
        ),
      );
    }

    Country? country;
    for (final c in CountryData.build()) {
      if (c.id == summary!.playerId) country = c;
    }
    final name = country == null
        ? summary!.playerName
        : (l10n.isPersian ? country.nameFa : country.nameEn);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WD.surface1.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: WD.accentDim),
      ),
      child: Row(
        children: [
          if (country != null)
            CountryFlag(country: country, width: 26, height: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: text.titleSmall?.copyWith(color: WD.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.date(summary!.date)} · ${fmt.money(summary!.treasury)} · '
                  '${fmt.integer(summary!.units)} ${l10n.t('res.divisions')}',
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n});

  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Column(
      children: [
        Text(
          l10n.t('menu.offlineReady'),
          textAlign: TextAlign.center,
          style: style,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('app.version'),
          style: style?.copyWith(color: WD.textMuted, letterSpacing: 1.4),
        ),
      ],
    );
  }
}
