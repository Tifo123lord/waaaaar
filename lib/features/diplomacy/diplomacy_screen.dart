import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/balance.dart';
import '../../core/campaign_controller.dart';
import '../../core/format.dart';
import '../../models/diplomatic_agreement.dart';
import '../../widgets/common.dart';
import '../../widgets/country_culture_view.dart';
import '../nations/country_dashboard_screen.dart';

class DiplomacyScreen extends ConsumerWidget {
  const DiplomacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final controller = ref.read(campaignProvider.notifier);
    final partners = controller.simulation.diplomacy.reachablePartners(
      state,
      state.playerId,
    );
    final allies = state.alliesOf(state.playerId);
    final agreements = state.agreements
        .where((a) => a.involves(state.playerId))
        .toList();

    void feedback() {
      final msg = controller.consumeMessage();
      if (!context.mounted || msg == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t(msg.messageKey, msg.params)),
          backgroundColor: msg.success ? WD.surface3 : WD.dangerDim,
        ),
      );
    }

    return ListView(
      padding: WD.padScreen,
      children: [
        Panel(
          title: l10n.t('dip.allies'),
          child: allies.isEmpty
              ? EmptyState(
                  message: l10n.t('dip.noAllies'),
                  icon: Icons.handshake_outlined,
                  compact: true,
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in allies) ...[
                      CountryFlag(
                        country: state.countries[id]!,
                        width: 24,
                        height: 16,
                      ),
                      Text(
                        l10n.isPersian
                            ? state.countries[id]!.nameFa
                            : state.countries[id]!.nameEn,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dip.agreements'),
          child: agreements.isEmpty
              ? EmptyState(
                  message: l10n.t('dip.noAgreements'),
                  icon: Icons.description_outlined,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final a in agreements) ...[
                      Row(
                        children: [
                          Tag(
                            a.type == AgreementType.alliance
                                ? l10n.t('dip.allianceLabel')
                                : l10n.t('dip.pactLabel'),
                            color: a.type == AgreementType.alliance
                                ? WD.ally
                                : WD.accent,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              l10n.isPersian
                                  ? state
                                        .countries[a.other(state.playerId)]!
                                        .nameFa
                                  : state
                                        .countries[a.other(state.playerId)]!
                                        .nameEn,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(fontSize: 12.5),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final ok = await confirmAction(
                                context: context,
                                title: l10n.t('dip.breakAgreement'),
                                message: l10n.t('dip.renounceConfirm', {
                                  'type': a.type == AgreementType.alliance
                                      ? l10n.t('dip.allianceLabel')
                                      : l10n.t('dip.pactLabel'),
                                  'name': state
                                      .countries[a.other(state.playerId)]!
                                      .nameEn,
                                }),
                                confirmLabel: l10n.t('dip.breakAgreement'),
                                cancelLabel: l10n.t('common.cancel'),
                                destructive: true,
                              );
                              if (ok) {
                                controller.renounceAgreement(a.id);
                                feedback();
                              }
                            },
                            child: Text(
                              l10n.t('dip.breakAgreement'),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: l10n.t('dip.title'),
          child: partners.isEmpty
              ? EmptyState(
                  message: l10n.t('dip.noAgreements'),
                  icon: Icons.public_off,
                )
              : Column(
                  children: [
                    for (final id in partners) ...[
                      _PartnerCard(
                        state: state,
                        id: id,
                        fmt: fmt,
                        onImprove: () {
                          controller.improveRelations(id);
                          feedback();
                        },
                        onPact: () {
                          controller.proposeAgreement(
                            id,
                            AgreementType.nonAggression,
                          );
                          feedback();
                        },
                        onAlly: () {
                          controller.proposeAgreement(
                            id,
                            AgreementType.alliance,
                          );
                          feedback();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.state,
    required this.id,
    required this.fmt,
    required this.onImprove,
    required this.onPact,
    required this.onAlly,
  });

  final dynamic state;
  final String id;
  final Fmt fmt;
  final VoidCallback onImprove;
  final VoidCallback onPact;
  final VoidCallback onAlly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final c = state.countries[id];
    final relations = (state.player.relations[id] ?? 0.0) as double;
    final atWar = state.atWarWith(state.playerId, id) as bool;
    final hasPact =
        state.hasAgreement(state.playerId, id, AgreementType.nonAggression)
            as bool;
    final hasAlly =
        state.hasAgreement(state.playerId, id, AgreementType.alliance) as bool;
    final treasury = state.player.treasury as double;

    final attitude = relations <= -45
        ? 'hostile'
        : relations <= -15
        ? 'cold'
        : relations < 20
        ? 'neutral'
        : relations < 55
        ? 'warm'
        : 'friendly';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: atWar ? WD.dangerDim : WD.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => CountryProfileScreen.open(context, c),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountryEmblem(countryId: id, size: 30),
                    const SizedBox(width: 6),
                    CountryFlag(country: c, width: 28, height: 18),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isPersian ? c.nameFa : c.nameEn,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${l10n.t('dip.personality')}: ${l10n.t('ai.${c.personality.name}')}',
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Tag(
                l10n.t('dip.attitude.$attitude'),
                color: signedColor(relations),
                filled: true,
              ),
              IconButton(
                tooltip: l10n.isPersian ? 'داشبورد کشور' : 'Nation dashboard',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                onPressed: () =>
                    CountryDashboardScreen.open(context, id, tab: 4),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('dip.relations'),
                  value: fmt.number(relations),
                  valueColor: signedColor(relations),
                ),
              ),
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('map.armyStrength'),
                  value: fmt.number(state.armyOf(id).combatScore),
                ),
              ),
              Expanded(
                child: StatTile(
                  compact: true,
                  label: l10n.t('res.treasury'),
                  value: fmt.credits(c.treasury),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Meter(
            fraction: (relations + 100) / 200,
            height: 4,
            color: signedColor(relations),
          ),
          if (atWar) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.block, size: 13, color: WD.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t('dip.atWarNoDiplomacy', {
                      'name': l10n.isPersian ? c.nameFa : c.nameEn,
                    }),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: WD.danger),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: treasury >= Balance.costImproveRelations
                        ? onImprove
                        : null,
                    child: Text(
                      l10n.t('dip.improve'),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        (!hasPact && treasury >= Balance.costNonAggression)
                        ? onPact
                        : null,
                    child: Text(
                      hasPact ? l10n.t('common.active') : l10n.t('dip.pact'),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (!hasAlly && treasury >= Balance.costAlliance)
                        ? onAlly
                        : null,
                    child: Text(
                      hasAlly
                          ? l10n.t('common.active')
                          : l10n.t('dip.alliance'),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('dip.trustPenalty'),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontSize: 9.5),
            ),
          ],
        ],
      ),
    );
  }
}
