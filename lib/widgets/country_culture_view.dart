import 'package:flutter/material.dart';

import '../app/localization.dart';
import '../app/theme.dart';
import 'leaders_view.dart';
import '../data/country_culture.dart';
import '../models/country.dart';
import 'common.dart';

/// National coat of arms / emblem on a soft light medallion so dark emblems
/// (e.g. India) stay readable on the dark UI.
class CountryEmblem extends StatelessWidget {
  const CountryEmblem({super.key, required this.countryId, this.size = 48});

  final String countryId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFF4F1E8), Color(0xFFD9D3C2)],
        ),
        border: Border.all(color: WD.brass, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        CountryCulture.emblemAsset(countryId),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.shield, color: WD.brassDim, size: size * 0.6),
      ),
    );
  }
}

/// Hero banner: landmark photo with flag, emblem and name overlaid.
class CountryHeroBanner extends StatelessWidget {
  const CountryHeroBanner({
    super.key,
    required this.country,
    this.height = 170,
    this.onTap,
  });

  final Country country;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final fa = l10n.isPersian;
    final culture = CountryCulture.of(country.id);
    final text = Theme.of(context).textTheme;
    final landmark = culture != null && culture.landmarks.isNotEmpty
        ? culture.landmarks.first
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(WD.radiusMd),
      child: Material(
        color: WD.surface2,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (landmark != null)
                  Image.asset(
                    landmark.asset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  )
                else
                  Image.asset(
                    CountryCulture.flagAsset(country.id),
                    fit: BoxFit.cover,
                  ),
                // Flag wash at the top + dark fade at the bottom.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22000000),
                        Color(0x33000000),
                        Color(0xE6070909),
                      ],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                if (landmark != null)
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: WD.void0.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(WD.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 11,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            landmark.name(fa),
                            style: text.labelSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CountryEmblem(countryId: country.id, size: 58),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CountryFlag(
                              country: country,
                              width: 42,
                              height: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fa ? country.nameFa : country.nameEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                shadows: const [
                                  Shadow(blurRadius: 6, color: Colors.black),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onTap != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: WD.brass.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(WD.radiusSm),
                          ),
                          child: Text(
                            fa ? 'شناسنامه کشور' : 'Profile',
                            style: text.labelSmall?.copyWith(
                              color: WD.void0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of identity facts: capital, currency, language, dish, animal, motto.
class CountryFactsGrid extends StatelessWidget {
  const CountryFactsGrid({super.key, required this.country});

  final Country country;

  @override
  Widget build(BuildContext context) {
    final fa = AppStrings.of(context).isPersian;
    final c = CountryCulture.of(country.id);
    if (c == null) return const SizedBox.shrink();
    final items = <(IconData, String, String)>[
      (
        Icons.location_city,
        fa ? 'پایتخت' : 'Capital',
        fa ? country.capitalFa : country.capitalEn,
      ),
      (
        Icons.public,
        fa ? 'قاره' : 'Continent',
        fa ? c.continentFa : c.continentEn,
      ),
      (
        Icons.payments_outlined,
        fa ? 'واحد پول' : 'Currency',
        fa ? c.currencyFa : c.currencyEn,
      ),
      (
        Icons.translate,
        fa ? 'زبان رسمی' : 'Language',
        fa ? c.languageFa : c.languageEn,
      ),
      (
        Icons.restaurant,
        fa ? 'غذای ملی' : 'National dish',
        fa ? c.dishFa : c.dishEn,
      ),
      (
        Icons.pets,
        fa ? 'حیوان ملی' : 'National animal',
        fa ? c.animalFa : c.animalEn,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: _Fact(icon: it.$1, label: it.$2, value: it.$3),
              ),
            if ((fa ? c.mottoFa : c.mottoEn) != '—')
              SizedBox(
                width: box.maxWidth,
                child: _Fact(
                  icon: Icons.format_quote,
                  label: fa ? 'شعار ملی' : 'National motto',
                  value: fa ? c.mottoFa : c.mottoEn,
                  highlight: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusSm),
        border: Border.all(color: highlight ? WD.brassDim : WD.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlight ? WD.brass : WD.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: WD.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: highlight ? WD.brass : WD.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal landmark photo gallery. Tap a photo to view it full screen.
class LandmarkGallery extends StatelessWidget {
  const LandmarkGallery({
    super.key,
    required this.countryId,
    this.height = 130,
  });

  final String countryId;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fa = AppStrings.of(context).isPersian;
    final c = CountryCulture.of(countryId);
    if (c == null) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: c.landmarks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final lm = c.landmarks[i];
          return GestureDetector(
            onTap: () => _openPhoto(context, lm, fa),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(WD.radiusMd),
              child: SizedBox(
                width: height * 1.5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      lm.asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          ColoredBox(color: WD.surface3),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xCC000000)],
                          stops: [0.5, 1],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 8,
                      end: 8,
                      bottom: 7,
                      child: Text(
                        lm.name(fa),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPhoto(BuildContext context, Landmark lm, bool fa) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(WD.radiusMd),
              child: InteractiveViewer(
                child: Image.asset(lm.asset, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lm.name(fa),
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(fa ? 'بستن' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full national profile page: banner, flag + emblem showcase, facts, gallery.
class CountryProfileScreen extends StatelessWidget {
  const CountryProfileScreen({super.key, required this.country});

  final Country country;

  static Future<void> open(BuildContext context, Country country) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryProfileScreen(country: country),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fa = AppStrings.of(context).isPersian;
    final text = Theme.of(context).textTheme;
    Widget header(String s, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: WD.accent),
          const SizedBox(width: 6),
          Text(
            s.toUpperCase(),
            style: text.labelSmall?.copyWith(color: WD.accent),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fa ? 'شناسنامه ${country.nameFa}' : '${country.nameEn} profile',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: WD.padScreen,
          children: [
            CountryHeroBanner(country: country, height: 210),
            header(
              fa ? 'پرچم و نشان ملی' : 'Flag & coat of arms',
              Icons.flag_outlined,
            ),
            Row(
              children: [
                Expanded(
                  child: _Showcase(
                    label: fa ? 'پرچم' : 'Flag',
                    child: AspectRatio(
                      aspectRatio: 3 / 2,
                      child: CountryFlag(
                        country: country,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Showcase(
                    label: fa ? 'نشان ملی' : 'Emblem',
                    child: AspectRatio(
                      aspectRatio: 3 / 2,
                      child: Center(
                        child: CountryEmblem(countryId: country.id, size: 92),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            header(fa ? 'اطلاعات کشور' : 'National facts', Icons.info_outline),
            CountryFactsGrid(country: country),
            header(
              fa ? 'رهبران و مقامات' : 'Leaders & officials',
              Icons.groups_outlined,
            ),
            LeadershipPanel(
              countryId: country.id,
              title: fa ? 'ترکیب حاکمیت' : 'Government & command',
            ),
            header(
              fa ? 'جاذبه‌های دیدنی' : 'Famous landmarks',
              Icons.photo_library_outlined,
            ),
            LandmarkGallery(countryId: country.id, height: 150),
            const SizedBox(height: 14),
            Text(
              fa
                  ? 'تصاویر: ویکی‌مدیا کامنز · پرچم‌ها: flagcdn (مالکیت عمومی)'
                  : 'Photos: Wikimedia Commons · Flags: flagcdn (public domain)',
              style: text.labelSmall?.copyWith(
                color: WD.textMuted,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Showcase extends StatelessWidget {
  const _Showcase({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WD.surface2,
        borderRadius: BorderRadius.circular(WD.radiusMd),
        border: Border.all(color: WD.line),
      ),
      child: Column(
        children: [
          child,
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
