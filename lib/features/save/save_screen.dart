import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../data/save_repository.dart';
import '../../widgets/common.dart';

class SaveScreen extends ConsumerWidget {
  const SaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final controller = ref.read(campaignProvider.notifier);
    final summary = ref.watch(saveSummaryProvider).valueOrNull;

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: l10n.t('save.slotTitle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValueRow(
                label: l10n.t('evt.kind.game'),
                value: l10n.t('common.active'),
              ),
              KeyValueRow(
                label: l10n.t('common.day'),
                value: fmt.date(state.date),
              ),
              KeyValueRow(
                label: l10n.t('res.treasury'),
                value: fmt.money(state.player.treasury),
              ),
              KeyValueRow(
                label: l10n.t('res.army'),
                value: fmt.number(state.armyOf(state.playerId).combatScore),
              ),
              KeyValueRow(
                label: l10n.t('res.territory'),
                value: fmt.integer(state.territoryCountOf(state.playerId)),
              ),
              KeyValueRow(
                label: l10n.t('dash.treaties'),
                value: fmt.integer(
                  state.agreements
                      .where((a) => a.involves(state.playerId))
                      .length,
                ),
              ),
              const Divider(height: 16),
              Text(
                summary == null
                    ? l10n.t('save.neverSaved')
                    : l10n.t('save.lastSaved', {'date': summary.savedAtIso}),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final ok = await controller.saveCampaign();
            ref.invalidate(saveSummaryProvider);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.t(ok ? 'save.saved' : 'save.failed', {
                    'date': fmt.date(state.date),
                  }),
                ),
                backgroundColor: ok ? WD.surface3 : WD.dangerDim,
              ),
            );
          },
          icon: const Icon(Icons.save_outlined, size: 17),
          label: Text(l10n.t('save.title')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await confirmAction(
              context: context,
              title: l10n.t('set.deleteSave'),
              message: l10n.t('set.deleteConfirm'),
              confirmLabel: l10n.t('common.delete'),
              cancelLabel: l10n.t('common.cancel'),
              destructive: true,
            );
            if (!confirmed) return;
            await SaveRepository().delete();
            ref.invalidate(saveSummaryProvider);
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.t('set.deleted'))));
          },
          icon: const Icon(Icons.delete_outline, size: 17),
          label: Text(l10n.t('set.deleteSave')),
          style: OutlinedButton.styleFrom(foregroundColor: WD.danger),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await confirmAction(
              context: context,
              title: l10n.t('save.backToMenu'),
              message: l10n.t('save.quitConfirm'),
              confirmLabel: l10n.t('common.confirm'),
              cancelLabel: l10n.t('common.cancel'),
            );
            if (!confirmed) return;
            controller.endCampaign();
            ref.invalidate(saveSummaryProvider);
            if (context.mounted) context.go(Routes.menu);
          },
          icon: const Icon(Icons.logout, size: 17),
          label: Text(l10n.t('save.backToMenu')),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
