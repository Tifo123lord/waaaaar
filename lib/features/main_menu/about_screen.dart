import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('about.title'))),
      body: ListView(
        padding: WD.padScreen,
        children: [
          Center(
            child: Column(
              children: [
                const BrandEmblem(size: 110),
                const SizedBox(height: 14),
                Text(
                  l10n.t('app.name'),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(l10n.t('app.version'), style: text.labelSmall),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('about.lead'), style: text.titleSmall),
                const SizedBox(height: 8),
                Text(l10n.t('about.body'), style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            title: l10n.t('about.scopeTitle').toUpperCase(),
            child: Text(l10n.t('about.scopeBody'), style: text.bodyMedium),
          ),
          const SizedBox(height: 12),
          Panel(
            title: l10n.t('about.notIncludedTitle').toUpperCase(),
            child: Text(
              l10n.t('about.notIncludedBody'),
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            title: l10n.t('about.dataTitle').toUpperCase(),
            child: Text(l10n.t('about.dataBody'), style: text.bodyMedium),
          ),
          const SizedBox(height: 12),
          Panel(
            title: l10n.t('about.creditsTitle').toUpperCase(),
            child: Text(l10n.t('about.creditsBody'), style: text.bodyMedium),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
