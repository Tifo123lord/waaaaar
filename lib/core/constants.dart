/// Global, non-localized constants for WORLD DOMINION (DEMO 0.2.0).
library;

class GameConstants {
  GameConstants._();

  static const String appNameEn = 'World Dominion';
  static const String appNameFa = 'فرمانروایی جهان';
  static const String version = 'DEMO 0.2.0';
  static const int saveFormatVersion = 1;

  static const String saveSlotKey = 'wd.save.slot0.v1';
  static const String settingsKey = 'wd.settings.v1';

  /// Simulation uses 30-day months so a monthly figure maps cleanly onto days.
  static const int daysPerMonth = 30;

  /// Campaign start date.
  static const int startYear = 2027;
  static const int startMonth = 1;
  static const int startDay = 1;

  /// Real milliseconds between simulation ticks.
  static const int tickMsNormal = 900;
  static const int tickMsFast = 260;

  /// Currency label.
  static const String currency = 'Cr';

  /// Manpower is expressed in millions of people.
  static const double manpowerPerMillionPopulation = 0.012;

  /// Simulation safety rails so the demo can never produce invalid state.
  static const double minTreasury = -250000;
  static const double maxTreasury = 25000000;
  static const double minStability = 0;
  static const double maxStability = 100;
  static const double minRelations = -100;
  static const double maxRelations = 100;
  static const double minIndustrial = 5;
  static const double maxIndustrial = 400;

  /// How many in-game days pass between AI decision pulses.
  static const int aiPulseDays = 10;

  /// Maximum events retained in the feed.
  static const int maxEventLog = 120;
}
