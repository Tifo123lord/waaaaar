import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../core/game_clock.dart';
import '../../core/format.dart';
import '../../models/game_event.dart';
import '../../models/game_state.dart';
import '../../widgets/common.dart';
import '../../core/campaign_controller.dart';

/// One event line in the feed. Titles/bodies are localized then interpolated
/// with the values recorded when the event was generated.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, required this.state});

  final GameEvent event;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fmt = Fmt(l10n);
    final color = switch (event.severity) {
      > 0 => WD.positive,
      < 0 => WD.danger,
      _ => WD.info,
    };
    final icon = _iconFor(event.kind);
    final params = Map<String, String>.from(event.params);
    for (final key in params.keys.toList()) {
      // Values that are themselves localization keys are translated first.
      final value = params[key]!;
      if (value.startsWith('eco.') || value.startsWith('dip.')) {
        params[key] = l10n.t(value);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(WD.radiusSm),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(event.titleKey, params),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontSize: 12.5),
                ),
                if (event.bodyKey != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.t(event.bodyKey!, params),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  '${fmt.date(GameDate(event.day))} · ${fmt.relativeDay(event.day, state.date)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(GameEventKind kind) => switch (kind) {
    GameEventKind.economy => Icons.trending_up,
    GameEventKind.construction => Icons.construction,
    GameEventKind.diplomacy => Icons.handshake_outlined,
    GameEventKind.recruitment => Icons.group_add_outlined,
    GameEventKind.battle => Icons.gps_fixed,
    GameEventKind.intelligence => Icons.visibility_outlined,
    GameEventKind.game => Icons.flag_outlined,
  };
}

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  GameEventKind? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final state = ref.watch(campaignProvider);
    if (state == null) return const Center(child: CircularProgressIndicator());

    final all = state.events.entries.reversed.toList();
    final shown = _filter == null
        ? all
        : all.where((e) => e.kind == _filter).toList();

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            children: [
              ChoiceChip(
                label: Text(l10n.t('evt.all')),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final kind in GameEventKind.values) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l10n.t('evt.kind.${kind.name}')),
                  selected: _filter == kind,
                  onSelected: (_) => setState(() => _filter = kind),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? EmptyState(
                  message: l10n.t('evt.empty'),
                  icon: Icons.receipt_long_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => Column(
                    children: [
                      EventRow(event: shown[i], state: state),
                      if (i != shown.length - 1) const Divider(height: 1),
                    ],
                  ),
                ),
        ),
        if (shown.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.t('evt.showing', {
                'n': '${shown.length}',
                'total': '${all.length}',
              }),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}
