import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/tech_tree.dart';
import 'models/country.dart' show kTechIndex;
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Populate the flat technology index used by the country model.
  for (final t in TechTree.all) {
    kTechIndex[t.id] = t;
  }

  // Locale data is required before any Persian number/date formatting runs.
  await initializeDateFormatting('en');
  await initializeDateFormatting('fa');

  runApp(const ProviderScope(child: WorldDominionApp()));
}
