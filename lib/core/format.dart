import 'package:intl/intl.dart';

import '../app/localization.dart';
import '../core/constants.dart';
import '../core/game_clock.dart';

/// Locale-aware number, currency and date formatting.
///
/// Persian uses the Persian-Arabic digit set via `intl`'s locale data — digits
/// are never substituted by hand.
class Fmt {
  Fmt(this.strings);

  final AppStrings strings;

  static const Map<String, List<String>> _persianDigits = {
    'fa': ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'],
  };

  /// Localizes digits for locales whose numbering system differs from Latin.
  String digits(String input) {
    final set = _persianDigits[strings.locale.languageCode];
    if (set == null) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final code = ch.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        buffer.write(set[code - 0x30]);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// Compact currency: 1.24M, 812K, 940.
  String credits(double value, {bool compact = true}) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    String body;
    if (!compact) {
      body = NumberFormat.decimalPattern(_intlLocale).format(abs.round());
    } else if (abs >= 1000000) {
      body = '${_fixed(abs / 1000000, 2)}${strings.t('abbr.million')}';
    } else if (abs >= 10000) {
      body = '${_fixed(abs / 1000, 1)}${strings.t('abbr.thousand')}';
    } else {
      body = NumberFormat.decimalPattern(_intlLocale).format(abs.round());
    }
    return digits('$sign$body');
  }

  String creditsExact(double value) =>
      digits(NumberFormat.decimalPattern(_intlLocale).format(value.round()));

  /// Signed currency, used for balances and reports.
  String creditsSigned(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${credits(value)}';
  }

  String number(double value, {int decimals = 0}) {
    final format = NumberFormat.decimalPatternDigits(
      locale: _intlLocale,
      decimalDigits: decimals,
    );
    return digits(format.format(value));
  }

  String integer(num value) =>
      digits(NumberFormat.decimalPattern(_intlLocale).format(value.round()));

  String percent(double fraction, {int decimals = 0}) =>
      '${number(fraction * 100, decimals: decimals)}٪';

  String get _percentSign => strings.isPersian ? '٪' : '%';

  String percentLabel(double fraction, {int decimals = 0}) =>
      '${number(fraction * 100, decimals: decimals)}$_percentSign';

  String money(double value) => '${credits(value)} ${GameConstants.currency}';

  String moneySigned(double value) =>
      '${creditsSigned(value)} ${GameConstants.currency}';

  /// e.g. "14 March 2027" / "۱۴ مارس ۲۰۲۷"
  String date(GameDate date) {
    final months = strings.months;
    final monthName = months[(date.month - 1) % months.length];
    return '${integer(date.day)} $monthName ${integer(date.year)}';
  }

  /// e.g. "Mar 2027" / "مارس ۲۰۲۷"
  String monthYear(GameDate date) {
    final months = strings.months;
    final short = months[(date.month - 1) % months.length];
    return '$short ${integer(date.year)}';
  }

  String relativeDay(int day, GameDate now) {
    final delta = now.totalDay - day;
    if (delta <= 0) return strings.t('time.today');
    if (delta == 1) return strings.t('time.yesterday');
    if (delta < 30) {
      return strings.t('time.daysAgo', {'n': integer(delta)});
    }
    final months = delta ~/ GameConstants.daysPerMonth;
    return strings.t('time.monthsAgo', {'n': integer(months)});
  }

  String population(double millions) =>
      '${number(millions, decimals: millions >= 100 ? 0 : 1)} ${strings.t('res.bn')}';

  String _fixed(double value, int decimals) =>
      value.toStringAsFixed(decimals).replaceAll(RegExp(r'\.0+$'), '');

  String get _intlLocale => strings.isPersian
      ? 'fa_IR'
      : Intl.canonicalizedLocale(strings.locale.toLanguageTag());
}

extension FmtContext on AppStrings {
  Fmt get fmt => Fmt(this);
}
