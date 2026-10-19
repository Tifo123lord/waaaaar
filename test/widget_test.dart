import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/features/world_map/world_map_view.dart';

/// Pumps a fixed number of frames. Used instead of [WidgetTester.pumpAndSettle]
/// wherever a selection is live, because the selection halo animates by design
/// and would never "settle".
Future<void> pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('App boots to the main menu', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WorldDominionApp()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('the main menu paints the map backdrop', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: WorldDominionApp()));
    await pumpFrames(tester);

    // The title screen uses the painted map as a non-interactive backdrop.
    final map = find.byType(WorldMapView);
    expect(map, findsWidgets);
    final widget = tester.widget<WorldMapView>(map.first);
    expect(widget.interactive, isFalse);
    expect(widget.showLabels, isFalse);
  });
}
