import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_app/app/localization.dart';
import 'package:flutter_app/app/theme.dart';
import 'package:flutter_app/core/campaign_controller.dart';
import 'package:flutter_app/data/tech_tree.dart';
import 'package:flutter_app/features/nations/country_dashboard_screen.dart';
import 'package:flutter_app/features/nations/nation_stats.dart';
import 'package:flutter_app/features/nations/nations_screen.dart';
import 'package:flutter_app/models/country.dart' show kTechIndex;
import 'package:flutter_app/models/game_state.dart';
import 'package:flutter_app/models/history.dart';
import 'package:flutter_app/simulation/game_simulation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

GameState _campaign({int days = 40}) {
  final sim = GameSimulation();
  var s = sim.newCampaign('ir');
  for (var i = 0; i < days; i++) {
    s = sim.tick(s, GameSpeed.paused);
  }
  return s;
}

Widget _host(Widget child, CampaignController controller, Locale locale) =>
    ProviderScope(
      overrides: [campaignProvider.overrideWith((ref) => controller)],
      child: MaterialApp(
        theme: WD.build(isPersian: locale.languageCode == 'fa'),
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );

void main() {
  setUpAll(() async {
    for (final t in TechTree.all) {
      kTechIndex[t.id] = t;
    }
    await initializeDateFormatting('en');
    await initializeDateFormatting('fa');
  });

  test('history is sampled and world stats rank every nation', () {
    final s = _campaign();
    expect(
      s.history.raw(s.playerId, HistoryMetric.power).length,
      greaterThan(2),
    );
    expect(s.history.raw('us', HistoryMetric.treasury), isNotEmpty);
    final stats = WorldStats(s);
    for (final m in NationMetric.values) {
      final order = stats.ordered(m);
      expect(order.length, s.countries.length);
      expect(stats.rankOf(order.first, m), 1);
    }
  });

  testWidgets('country dashboard renders every tab for every nation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final state = _campaign();
    final controller = CampaignController()..loadState(state);
    for (final locale in AppStrings.supportedLocales) {
      for (final id in state.countries.keys) {
        for (var tab = 0; tab < 7; tab++) {
          await tester.pumpWidget(
            _host(
              CountryDashboardScreen(
                key: ValueKey('$id$locale$tab'),
                countryId: id,
                initialTab: tab,
              ),
              controller,
              locale,
            ),
          );
          await tester.pump();
          // Scroll through the tab body so lazily built panels are laid out.
          await tester.drag(find.byType(TabBarView), const Offset(0, -3000));
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '$id tab $tab $locale',
          );
        }
      }
    }
  });

  testWidgets('nations index renders', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final controller = CampaignController()..loadState(_campaign());
    for (final locale in AppStrings.supportedLocales) {
      await tester.pumpWidget(
        _host(const Scaffold(body: NationsScreen()), controller, locale),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
