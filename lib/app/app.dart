import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import 'localization.dart';
import 'router.dart';
import 'settings.dart';
import 'theme.dart';

class WorldDominionApp extends ConsumerWidget {
  const WorldDominionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'World Dominion',
      debugShowCheckedModeBanner: false,
      theme: WD.build(
        isPersian: settings.isPersian,
        reduceMotion: !settings.animationsEnabled,
      ),
      locale: settings.locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        if (locale != null && locale.languageCode == 'fa') {
          return AppStrings.fa;
        }
        return AppStrings.en;
      },
      routerConfig: router,
    );
  }
}

/// Exposes the localized formatter to any widget in the tree.
extension AppStringsFormat on AppStrings {
  Fmt get formatter => Fmt(this);
}
