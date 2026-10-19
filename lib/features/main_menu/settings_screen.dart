import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../data/save_repository.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _deleteSave() async {
    final l10n = AppStrings.of(context);
    final confirmed = await confirmAction(
      context: context,
      title: l10n.t('set.deleteSave'),
      message: l10n.t('set.deleteConfirm'),
      confirmLabel: l10n.t('common.delete'),
      cancelLabel: l10n.t('common.cancel'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await SaveRepository().delete();
    ref.invalidate(saveSummaryProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.t('set.deleted'))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final hasSave = ref.watch(saveSummaryProvider).valueOrNull != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('set.title'))),
      body: ListView(
        padding: WD.padScreen,
        children: [
          Panel(
            title: l10n.t('set.language'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LanguageOption(
                  label: l10n.t('set.langEn'),
                  subtitle: 'Left-to-right · Latin figures',
                  selected: settings.localeCode == 'en',
                  onTap: () => notifier.setLocale('en'),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  label: l10n.t('set.langFa'),
                  subtitle: 'راست‌به‌چپ · ارقام فارسی',
                  selected: settings.localeCode == 'fa',
                  onTap: () => notifier.setLocale('fa'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            title: l10n.t('set.graphics'),
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.animationsEnabled,
                  onChanged: notifier.toggleAnimations,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.t('set.animations'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    l10n.t('set.animationsNote'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Divider(height: 20),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.t('set.mapMode'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedToggle<GameMapMode>(
                  expand: true,
                  values: const [GameMapMode.political, GameMapMode.military],
                  labels: [l10n.t('map.political'), l10n.t('map.military')],
                  selected: settings.defaultMapMode,
                  onChanged: notifier.setDefaultMapMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            title: l10n.t('set.audio'),
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.soundEnabled,
                  onChanged: notifier.toggleSound,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.t('set.sound'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SwitchListTile(
                  value: settings.musicEnabled,
                  onChanged: notifier.toggleMusic,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.t('set.music'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.t('set.soundNote'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            title: l10n.t('set.data'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: hasSave ? _deleteSave : null,
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: Text(l10n.t('set.deleteSave')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasSave ? WD.danger : WD.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? WD.surface3 : Colors.transparent,
      borderRadius: BorderRadius.circular(WD.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WD.radiusSm),
            border: Border.all(color: selected ? WD.accent : WD.line),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 17,
                color: selected ? WD.accent : WD.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
