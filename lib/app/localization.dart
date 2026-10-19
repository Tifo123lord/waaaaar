import 'package:flutter/material.dart';

/// Localization for WORLD DOMINION.
///
/// Persian is a first-class locale: `MaterialApp` is given `Locale('fa')`, so
/// `Directionality` becomes RTL automatically and Flutter performs real
/// bidirectional text shaping. Strings are never reversed by hand.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static const Locale en = Locale('en');
  static const Locale fa = Locale('fa');

  static const List<Locale> supportedLocales = [en, fa];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  bool get isPersian => locale.languageCode == 'fa';

  /// Numeric script hint used by the formatters.
  String get numberLocale => isPersian ? 'fa' : 'en';

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? const AppStrings(en);

  /// Looks up [key] and substitutes `{token}` placeholders from [args].
  String t(String key, [Map<String, String>? args]) {
    // Missing translations fall back to a readable, non-lorem label so the UI
    // never shows raw keys during a demo.
    var value =
        _strings[locale.languageCode]?[key] ??
        _strings['en']![key] ??
        _humanize(key);
    if (args != null && args.isNotEmpty) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }

  bool has(String key) =>
      _strings[locale.languageCode]?.containsKey(key) ??
      _strings['en']!.containsKey(key);

  static String _humanize(String key) {
    final tail = key.split('.').last;
    final spaced = tail.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Persian month names for the fictional 2027 campaign calendar.
  static const List<String> monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> monthsFa = [
    'ژانویه',
    'فوریه',
    'مارس',
    'آوریل',
    'مه',
    'ژوئن',
    'ژوئیه',
    'اوت',
    'سپتامبر',
    'اکتبر',
    'نوامبر',
    'دسامبر',
  ];

  List<String> get months => isPersian ? monthsFa : monthsEn;

  static const Map<String, Map<String, String>> _strings = {
    'en': _en,
    'fa': _fa,
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'fa';

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

// ---------------------------------------------------------------------------
// English
// ---------------------------------------------------------------------------

const Map<String, String> _en = {
  'app.name': 'WORLD DOMINION',
  'app.tagline': 'Grand Strategy Simulation',
  'app.version': 'DEMO 0.2.0',
  'app.disclaimer':
      'All statistics are fictionalized demo values authored for gameplay '
      'balance. They are not presented as real national data.',

  // Main menu
  'menu.newCampaign': 'New Campaign',
  'menu.continueCampaign': 'Continue Campaign',
  'menu.settings': 'Settings',
  'menu.about': 'About',
  'menu.noSave': 'No saved campaign',
  'menu.session': 'Session',
  'menu.offlineReady': 'Offline · no account required',

  // Common
  'common.cancel': 'Cancel',
  'common.confirm': 'Confirm',
  'common.close': 'Close',
  'common.back': 'Back',
  'common.retry': 'Retry',
  'common.apply': 'Apply',
  'common.delete': 'Delete',
  'common.ok': 'Understood',
  'common.continue': 'Continue',
  'common.none': 'None',
  'common.inactive': 'Inactive',
  'common.active': 'Active',
  'common.total': 'Total',
  'common.perMonth': '/month',
  'common.perDay': '/day',
  'common.day': 'Day',
  'common.cost': 'Cost',
  'common.available': 'Available',
  'common.locked': 'Locked',
  'common.dismiss': 'Dismiss',
  'common.you': 'You',
  'common.noneYet': 'Nothing here yet',
  'abbr.thousand': 'K',
  'abbr.million': 'M',
  'time.today': 'today',
  'time.yesterday': 'yesterday',
  'time.daysAgo': '{n} days ago',
  'time.monthsAgo': '{n} months ago',

  // Resources
  'res.treasury': 'Treasury',
  'res.income': 'Monthly Income',
  'res.expenses': 'Monthly Expenses',
  'res.net': 'Net Balance',
  'res.army': 'Army Strength',
  'res.population': 'Population',
  'res.stability': 'Stability',
  'res.industrial': 'Industrial Capacity',
  'res.infrastructure': 'Infrastructure',
  'res.manpower': 'Manpower',
  'res.territory': 'Territory',
  'res.budget': 'Military Funding',
  'res.million': 'M',
  'res.bn': 'M people',
  'res.divisions': 'divisions',

  // Country selection
  'select.title': 'Select Your Nation',
  'select.subtitle': 'Choose a power to command',
  'select.search': 'Search nations',
  'select.list': 'List',
  'select.map': 'Map',
  'select.start': 'Start Campaign',
  'select.preview': 'Nation Preview',
  'select.strengths': 'Strengths',
  'select.weaknesses': 'Weaknesses',
  'select.capital': 'Capital',
  'select.doctrine': 'Doctrine',
  'select.tapHint': 'Tap a country, or use the searchable list below.',
  'select.noResults': 'No nation matches that search.',
  'select.startingForces': 'Starting Forces',
  'select.neighbours': 'Reachable Theatres',

  // Navigation
  'nav.dashboard': 'Command',
  'nav.map': 'World Map',
  'nav.economy': 'Economy',
  'nav.military': 'Military',
  'nav.diplomacy': 'Diplomacy',
  'nav.events': 'Events',
  'nav.save': 'Save',
  'nav.mainMenu': 'Main Menu',

  // Clock
  'clock.paused': 'Paused',
  'clock.normal': 'Normal',
  'clock.fast': 'Fast',
  'clock.pause': 'Pause simulation',
  'clock.resume': 'Resume simulation',
  'clock.speed': 'Speed',
  'clock.stepDay': 'Advance one day',
  'nav.operations': 'Operations',
  'nav.campaign': 'Command',

  // Dashboard
  'dash.title': 'National Command',
  'dash.overview': 'Strategic Overview',
  'dash.recentEvents': 'Recent Events',
  'dash.activeWars': 'Active Wars',
  'dash.noWars': 'No active conflicts',
  'dash.treaties': 'Treaties',
  'dash.noTreaties': 'No standing agreements',
  'dash.construction': 'Construction Queue',
  'dash.idle': 'No building projects underway',
  'dash.stabilityTrend': 'Stability',
  'dash.battleActive': 'Battle in progress',
  'dash.quickActions': 'Quick Actions',
  'dash.economySnapshot': 'Economy Snapshot',
  'dash.militarySnapshot': 'Military Snapshot',
  'dash.viewAll': 'View all',
  'dash.report': 'Field Report',

  // Map
  'map.title': 'World Map',
  'map.political': 'Political',
  'map.military': 'Military',
  'map.legend': 'Legend',
  'map.you': 'Your nation',
  'map.ally': 'Ally',
  'map.war': 'At war',
  'map.neutral': 'Neutral',
  'map.unclaimed': 'Unclaimed',
  'map.territoryControlled': 'Controlled by',
  'map.closeUp': 'Country dossier',
  'map.resetView': 'Reset view',
  'map.zoomIn': 'Zoom in',
  'map.zoomOut': 'Zoom out',
  'map.instructions': 'Drag to pan · pinch or scroll to zoom · tap a nation',
  'map.relations': 'Relations',
  'map.armyStrength': 'Army',
  'map.pact': 'Non-aggression pact',
  'map.alliance': 'Alliance',
  'map.atWarTag': 'AT WAR',
  'map.selectHint': 'Select a nation to inspect it',

  // Economy
  'eco.title': 'Economy',
  'eco.incomeBreakdown': 'Income Breakdown',
  'eco.expenseBreakdown': 'Expense Breakdown',
  'eco.industrialOutput': 'Industrial output',
  'eco.resourceTrade': 'Resource & trade',
  'eco.resourceIncome': 'Resource trade',
  'eco.civilUpkeep': 'Civil upkeep',
  'eco.militaryUpkeep': 'Military maintenance',
  'eco.constructionSpend': 'Construction orders',
  'eco.projects': 'Infrastructure Projects',
  'eco.build': 'Build',
  'eco.upgradeInfra': 'Upgrade infrastructure',
  'eco.building': 'Under construction',
  'eco.completed': 'Completed',
  'eco.built': 'Built',
  'eco.daysLeft': '{n} days remaining',
  'eco.readyIn': 'Ready in {n} days',
  'eco.budgetTitle': 'Military Funding',
  'eco.budgetHint':
      'Higher funding strengthens your army but raises monthly maintenance.',
  'eco.budgetLow': 'Austerity',
  'eco.budgetNormal': 'Standard',
  'eco.budgetHigh': 'High',
  'eco.budgetTotal': 'War Economy',
  'eco.incomeProjection': 'Projected monthly balance if nothing changes',
  'eco.insufficient': 'Insufficient treasury — {need} required.',
  'eco.queued': '{name} queued. Ready in {n} days.',
  'eco.alreadyBuilding': 'You are already building this type of project.',
  'eco.factory.name': 'Factory',
  'eco.factory.desc':
      'Adds {a} industrial capacity. Industry drives national income.',
  'eco.infrastructure.name': 'Infrastructure',
  'eco.infrastructure.desc':
      'Upgrades roads and grids: +{a} infrastructure, +{b} industrial capacity. '
      'Infrastructure multiplies all other income.',
  'eco.militaryFactory.name': 'Military Factory',
  'eco.militaryFactory.desc':
      'Reduces recruitment cost by {a}% and adds {b} industrial capacity.',
  'eco.fortification.name': 'Fortification Line',
  'eco.fortification.desc':
      'Grants +{a}% defensive strength to formations fighting at home.',

  // Military
  'mil.title': 'Armed Forces',
  'mil.recruit': 'Recruitment',
  'mil.infantry': 'Infantry Division',
  'mil.armor': 'Armoured Division',
  'mil.infantry.desc':
      'Cost-effective line formation. Strong on defence and attrition warfare.',
  'mil.armor.desc':
      'Expensive breakthrough formation. High attack, high maintenance.',
  'mil.recruitBtn': 'Recruit',
  'mil.recruited': '{name} raised in {region}.',
  'mil.capacityFull': 'Manpower exhausted. Population limits your army size.',
  'mil.insufficient': 'Insufficient treasury — {need} required.',
  'mil.roster': 'Order of Battle',
  'mil.empty': 'No formations raised yet. Recruit your first division above.',
  'mil.totalStrength': 'Total Combat Power',
  'mil.readiness': 'Readiness',
  'mil.maintenance': 'Monthly Maintenance',
  'mil.homeRegion': 'Stationed',
  'mil.experience': 'Experience',
  'mil.formation': 'Formation',
  'mil.type': 'Type',
  'mil.power': 'Power',
  'mil.disband': 'Disband',
  'mil.disbandConfirm': 'Disband {name}? The formation is lost permanently.',
  'mil.attritionNote':
      'Damaged formations recover 1% of combat power per day while at peace.',
  'mil.discount': '{n}% recruitment discount from military factories',
  'mil.manpowerUse': 'Manpower committed',
  'mil.maxManpower': 'Total available manpower',
  'mil.deployHint': 'New formations are raised in your home territory.',

  // Battle
  'bt.title': 'Military Operations',
  'bt.selectTarget': 'Select Target Nation',
  'bt.noTargets': 'No nation is currently reachable for military action.',
  'bt.assessment': 'Battle Assessment',
  'bt.attacker': 'Attacker',
  'bt.defender': 'Defender',
  'bt.estimatedChance': 'Estimated Chance of Victory',
  'bt.ourStrength': 'Your committed strength',
  'bt.theirStrength': 'Defender strength',
  'bt.expectedLosses': 'Expected losses',
  'bt.supply': 'Supply',
  'bt.supplyGood': 'Good',
  'bt.supplyStrained': 'Strained',
  'bt.supplyCritical': 'Critical',
  'bt.declare': 'Launch Offensive',
  'bt.sueForPeace': 'Sue for Peace',
  'bt.front': 'Front',
  'bt.inProgress': 'Battle in progress at {region}',
  'bt.progress': 'Battle progress',
  'bt.roundLog': 'Engagement Log',
  'bt.awaiting': 'Awaiting next simulation tick…',
  'bt.report': 'Battle Report',
  'bt.outcome.win': 'VICTORY',
  'bt.outcome.loss': 'DEFEAT',
  'bt.narrative.win':
      '{attacker} broke through {defender}\'s lines at {region}. '
      'The defender\'s field forces are routed.',
  'bt.narrative.loss':
      '{attacker}\'s offensive at {region} was repulsed. '
      '{defender} held the line.',
  'bt.lossesUs': 'Your losses',
  'bt.lossesThem': 'Enemy losses',
  'bt.remainingUs': 'Your remaining strength',
  'bt.remainingThem': 'Remaining enemy strength',
  'bt.loot': 'War reparations seized',
  'bt.territoryGained': '{region} has been occupied.',
  'bt.territoryHeld': 'No territory changed hands.',
  'bt.acknowledge': 'Acknowledge',
  'bt.cannotAlly': 'You cannot attack an ally.',
  'bt.cannotPact':
      'A non-aggression pact forbids this attack. Renounce it first.',
  'bt.cannotBorder': 'This nation is not in a reachable theatre.',
  'bt.noArmy': 'You have no combat-ready formations.',
  'bt.warOngoing': 'You are already fighting {name}.',
  'bt.peaceMade': 'Peace signed with {name}.',
  'bt.peaceRejected': '{name} refuses peace while it holds the advantage.',
  'bt.warDeclared': 'War declared on {name}.',
  'bt.battleJoined': 'Contact! Battle begins at {region}.',
  'bt.round': 'Round {n}',
  'bt.log.clash': 'Round {n}: {a} {ap} vs {d} {dp}',
  'bt.log.attackerGaining': 'Round {n}: your forces gain ground',
  'bt.log.defenderGaining': 'Round {n}: the defender counter-attacks',
  'bt.log.steady': 'Round {n}: exchange of fire, lines hold',

  // Diplomacy
  'dip.title': 'Diplomacy',
  'dip.relations': 'Bilateral Relations',
  'dip.improve': 'Improve Relations',
  'dip.improved': 'Relations with {name} improved to {value}.',
  'dip.pact': 'Non-Aggression Pact',
  'dip.alliance': 'Alliance',
  'dip.proposed': 'Proposal sent to {name}',
  'dip.accepted': '{name} accepted.',
  'dip.rejected': '{name} rejected the proposal.',
  'dip.alreadyExists': 'That agreement is already in force.',
  'dip.agreements': 'Standing Agreements',
  'dip.noAgreements': 'No agreements signed yet.',
  'dip.allies': 'Allies',
  'dip.noAllies': 'No allies',
  'dip.costLine': 'Cost: {cost}',
  'dip.personality': 'Doctrine',
  'dip.attitude': 'Attitude',
  'dip.attitude.hostile': 'Hostile',
  'dip.attitude.cold': 'Cold',
  'dip.attitude.neutral': 'Neutral',
  'dip.attitude.warm': 'Warm',
  'dip.attitude.friendly': 'Friendly',
  'dip.needsRelations': 'Requires relations of at least {n}.',
  'dip.atWarNoDiplomacy':
      'You are at war with {name}. Negotiation is impossible.',
  'dip.signWith': 'Sign with {name}',
  'dip.treaty.signed': 'Treaty signed with {name}',
  'dip.breakAgreement': 'Renounce',
  'dip.renounceConfirm': 'Renounce the {type} with {name}?',
  'dip.renounced': 'Agreement with {name} renounced',
  'dip.trustPenalty': 'Renouncing a treaty damages relations.',
  'dip.pactLabel': 'Non-aggression',
  'dip.allianceLabel': 'Alliance',

  'ai.expansionist': 'Expansionist',
  'ai.industrialist': 'Industrialist',
  'ai.defensive': 'Defensive',
  'ai.opportunist': 'Opportunist',

  // Events
  'evt.title': 'Event Feed',
  'evt.all': 'All',
  'evt.empty': 'No events recorded yet. Advance the simulation to see reports.',
  'evt.filter': 'Filter',
  'evt.showing': 'Showing {n} of {total} records',
  'evt.kind.economy': 'Economy',
  'evt.kind.construction': 'Construction',
  'evt.kind.diplomacy': 'Diplomacy',
  'evt.kind.recruitment': 'Military',
  'evt.kind.battle': 'War',
  'evt.kind.intelligence': 'Intelligence',
  'evt.kind.game': 'System',

  // Event templates
  'evt.econ.title': 'Economic growth in {country}',
  'evt.econ.body':
      '{country} expanded its industrial output. Treasury now {treasury}.',
  'evt.build.title': '{building} completed in {country}',
  'evt.build.body':
      '{building} came online, adding {amount} to national capability.',
  'evt.research.title': 'Research programme advanced in {country}',
  'evt.research.body': 'Civil laboratories in {country} reported progress.',
  'evt.dip.title': '{type} signed: {a} and {b}',
  'evt.dip.body': 'Relations between {a} and {b} are now {value}.',
  'evt.recruit.title': '{country} raised new formations',
  'evt.recruit.body':
      '{count} new division(s) joined the {country} order of battle.',
  'evt.battle.title': 'Battle concluded at {region}',
  'evt.battle.body':
      '{winner} prevailed over {loser}. {losses} combat power lost.',
  'evt.war.title': 'War: {a} attacks {b}',
  'evt.war.body': 'Fighting has begun in {region}.',
  'evt.peace.title': 'Peace between {a} and {b}',
  'evt.peace.body': 'Hostilities at {region} have ceased.',
  'evt.ai.title': '{country} expanded its army',
  'evt.ai.body': '{country} is investing in military capability.',
  'evt.tension.title': 'Rising tension between {a} and {b}',
  'evt.tension.body': 'Relations have fallen to {value}.',
  'evt.game.title': 'Campaign started',
  'evt.game.body': 'You now command {country}.',

  // Settings
  'set.title': 'Settings',
  'set.audio': 'Audio',
  'set.sound': 'Sound effects',
  'set.music': 'Music',
  'set.soundNote': 'The demo ships with no audio assets — kept for future use.',
  'set.language': 'Language',
  'set.langEn': 'English',
  'set.langFa': 'فارسی (Persian)',
  'set.graphics': 'Graphics & Motion',
  'set.animations': 'Interface animations',
  'set.animationsNote':
      'Disabling animations reduces motion and lowers battery usage.',
  'set.mapMode': 'Default map mode',
  'set.data': 'Save Data',
  'set.deleteSave': 'Delete saved campaign',
  'set.deleteConfirm': 'Delete the saved campaign? This cannot be undone.',
  'set.deleted': 'Saved campaign deleted.',
  'set.restartRequired': 'Language applied immediately.',

  // About
  'about.title': 'About',
  'about.lead': 'WORLD DOMINION is a grand strategy simulation.',
  'about.body':
      'You take command of one of ten major powers and steer it through '
      'economics, diplomacy and war. Every figure you see is produced by a '
      'single running simulation — income, construction, recruitment, battles '
      'and the decisions of rival nations all advance together on the game clock.',
  'about.scopeTitle': 'This build',
  'about.scopeBody':
      'DEMO 0.2.0 is the first playable slice. It contains the world map, the '
      'campaign dashboard and clock, the economy, army management, one '
      'turn-based battle system, basic diplomacy, rival AI and save/load.',
  'about.notIncludedTitle': 'Not yet included',
  'about.notIncludedBody':
      'Multiplayer, online accounts, espionage, technology trees, naval '
      'warfare and province-level borders are planned for later versions.',
  'about.dataTitle': 'About the data',
  'about.dataBody':
      'Country statistics are fictionalized demo values balanced for gameplay. '
      'Map coastlines and national outlines are derived from the Natural Earth '
      '1:50m public-domain dataset and simplified for legibility on a phone.',
  'about.creditsTitle': 'Credits',
  'about.creditsBody':
      'Typography: Inter (SIL OFL 1.1) and Vazirmatn (SIL OFL 1.1). '
      'Cartography: Natural Earth (public domain). Built with Flutter.',

  // Save / load
  'save.title': 'Save Campaign',
  'save.saved': 'Campaign saved · {date}',
  'save.failed': 'Could not save the campaign.',
  'save.loaded': 'Campaign restored.',
  'save.loadFailed': 'The save file could not be read.',
  'save.corrupted': 'Save data was invalid and has been ignored.',
  'save.slotTitle': 'Save Slot',
  'save.lastSaved': 'Last saved {date}',
  'save.neverSaved': 'Never saved',
  'save.overwrite': 'Overwrite saved campaign?',
  'save.autosave': 'Autosave',
  'save.details': 'Saved Progress',
  'save.backToMenu': 'Return to Main Menu',
  'save.quitConfirm':
      'Return to the main menu? Unsaved progress since your last save is kept in '
      'this session only.',
};

// ---------------------------------------------------------------------------
// Persian (فارسی)
// ---------------------------------------------------------------------------

const Map<String, String> _fa = {
  'app.name': 'فرمانروایی جهان',
  'app.tagline': 'شبیه‌سازی استراتژی بزرگ',
  'app.version': 'نسخه نمایشی ۰.۲.۰',
  'app.disclaimer':
      'همه آمار این نسخه، مقادیر نمایشی و ساختگی برای توازن گیم‌پلی هستند و '
      'به‌عنوان آمار رسمی هیچ کشوری ارائه نمی‌شوند.',

  'menu.newCampaign': 'کارزار جدید',
  'menu.continueCampaign': 'ادامه کارزار',
  'menu.settings': 'تنظیمات',
  'menu.about': 'درباره',
  'menu.noSave': 'کارزاری ذخیره نشده است',
  'menu.session': 'نشست',
  'menu.offlineReady': 'آفلاین · بدون نیاز به حساب کاربری',

  'common.cancel': 'انصراف',
  'common.confirm': 'تأیید',
  'common.close': 'بستن',
  'common.back': 'بازگشت',
  'common.retry': 'تلاش مجدد',
  'common.apply': 'اعمال',
  'common.delete': 'حذف',
  'common.ok': 'متوجه شدم',
  'common.continue': 'ادامه',
  'common.none': 'هیچ‌کدام',
  'common.inactive': 'غیرفعال',
  'common.active': 'فعال',
  'common.total': 'مجموع',
  'common.perMonth': 'در ماه',
  'common.perDay': 'در روز',
  'common.day': 'روز',
  'common.cost': 'هزینه',
  'common.available': 'موجود',
  'common.locked': 'قفل',
  'common.dismiss': 'بستن',
  'common.you': 'شما',
  'common.noneYet': 'هنوز موردی ثبت نشده',
  'abbr.thousand': 'هزار',
  'abbr.million': 'میلیون',
  'time.today': 'امروز',
  'time.yesterday': 'دیروز',
  'time.daysAgo': '{n} روز پیش',
  'time.monthsAgo': '{n} ماه پیش',

  'res.treasury': 'خزانه',
  'res.income': 'درآمد ماهانه',
  'res.expenses': 'هزینه‌های ماهانه',
  'res.net': 'تراز خالص',
  'res.army': 'توان ارتش',
  'res.population': 'جمعیت',
  'res.stability': 'ثبات سیاسی',
  'res.industrial': 'ظرفیت صناعی',
  'res.infrastructure': 'زیرساخت',
  'res.manpower': 'نیروی انسانی',
  'res.territory': 'قلمرو',
  'res.budget': 'بودجه نظامی',
  'res.million': 'میلیون',
  'res.bn': 'میلیون نفر',
  'res.divisions': 'لشکر',

  'select.title': 'کشور خود را انتخاب کنید',
  'select.subtitle': 'یک قدرت را برای فرماندهی برگزینید',
  'select.search': 'جست‌وجوی کشور',
  'select.list': 'فهرست',
  'select.map': 'نقشه',
  'select.start': 'آغاز کارزار',
  'select.preview': 'پیش‌نمای کشور',
  'select.strengths': 'نقاط قوت',
  'select.weaknesses': 'نقاط ضعف',
  'select.capital': 'پایتخت',
  'select.doctrine': 'دکترین',
  'select.tapHint': 'کشور را روی نقشه بزنید یا از فهرست جست‌وجو استفاده کنید.',
  'select.noResults': 'کشوری با این جست‌وجو یافت نشد.',
  'select.startingForces': 'نیروهای آغازین',
  'select.neighbours': 'تئاترهای قابل دسترس',

  'nav.dashboard': 'فرماندهی',
  'nav.map': 'نقشه جهان',
  'nav.economy': 'اقتصاد',
  'nav.military': 'ارتش',
  'nav.diplomacy': 'دیپلماسی',
  'nav.events': 'رویدادها',
  'nav.save': 'ذخیره',
  'nav.mainMenu': 'منوی اصلی',

  'clock.paused': 'توقف',
  'clock.normal': 'عادی',
  'clock.fast': 'سریع',
  'clock.pause': 'توقف شبیه‌سازی',
  'clock.resume': 'ادامه شبیه‌سازی',
  'clock.speed': 'سرعت',
  'clock.stepDay': 'یک روز جلو برو',
  'nav.operations': 'عملیات',
  'nav.campaign': 'فرماندهی',

  'dash.title': 'فرماندهی ملی',
  'dash.overview': 'نمای راهبردی',
  'dash.recentEvents': 'رویدادهای اخیر',
  'dash.activeWars': 'جنگ‌های فعال',
  'dash.noWars': 'درگیری فعالی وجود ندارد',
  'dash.treaties': 'پیمان‌ها',
  'dash.noTreaties': 'توافق فعالی وجود ندارد',
  'dash.construction': 'صف ساخت‌وساز',
  'dash.idle': 'پروژه ساختمانی در جریان نیست',
  'dash.stabilityTrend': 'ثبات',
  'dash.battleActive': 'نبردی در جریان است',
  'dash.quickActions': 'کنش‌های سریع',
  'dash.economySnapshot': 'نمای اقتصاد',
  'dash.militarySnapshot': 'نمای ارتش',
  'dash.viewAll': 'مشاهده همه',
  'dash.report': 'گزارش میدانی',

  'map.title': 'نقشه جهان',
  'map.political': 'سیاسی',
  'map.military': 'نظامی',
  'map.legend': 'راهنما',
  'map.you': 'کشور شما',
  'map.ally': 'متحد',
  'map.war': 'در جنگ',
  'map.neutral': 'بی‌طرف',
  'map.unclaimed': 'بدون حاکمیت',
  'map.territoryControlled': 'تحت کنترل',
  'map.closeUp': 'پرونده کشور',
  'map.resetView': 'بازنشانی نمایش',
  'map.zoomIn': 'بزرگ‌نمایی',
  'map.zoomOut': 'کوچک‌نمایی',
  'map.instructions':
      'برای جابه‌جایی بکشید · برای بزرگ‌نمایی دو انگشت یا چرخ ماوس · کشور را لمس کنید',
  'map.relations': 'روابط',
  'map.armyStrength': 'ارتش',
  'map.pact': 'پیمان عدم تجاوز',
  'map.alliance': 'اتحاد',
  'map.atWarTag': 'در جنگ',
  'map.selectHint': 'برای بررسی، یک کشور را انتخاب کنید',

  'eco.title': 'اقتصاد',
  'eco.incomeBreakdown': 'تفکیک درآمد',
  'eco.expenseBreakdown': 'تفکیک هزینه',
  'eco.industrialOutput': 'تولید صناعی',
  'eco.resourceTrade': 'منابع و تجارت',
  'eco.resourceIncome': 'تجارت منابع',
  'eco.civilUpkeep': 'هزینه‌های کشوری',
  'eco.militaryUpkeep': 'نگهداری ارتش',
  'eco.constructionSpend': 'سفارش‌های ساخت‌وساز',
  'eco.projects': 'پروژه‌های زیرساختی',
  'eco.build': 'ساخت',
  'eco.upgradeInfra': 'ارتقای زیرساخت',
  'eco.building': 'در حال ساخت',
  'eco.completed': 'تکمیل شد',
  'eco.built': 'ساخته‌شده',
  'eco.daysLeft': '{n} روز باقی‌مانده',
  'eco.readyIn': 'آماده تا {n} روز',
  'eco.budgetTitle': 'بودجه نظامی',
  'eco.budgetHint':
      'بودجه بیشتر ارتش را تقویت می‌کند اما هزینه ماهانه را بالا می‌برد.',
  'eco.budgetLow': 'ریاضت',
  'eco.budgetNormal': 'استاندارد',
  'eco.budgetHigh': 'بالا',
  'eco.budgetTotal': 'اقتصاد جنگی',
  'eco.incomeProjection': 'تراز ماهانه پیش‌بینی‌شده در صورت عدم تغییر',
  'eco.insufficient': 'خزانه کافی نیست — {need} لازم است.',
  'eco.queued': '{name} در صف قرار گرفت. آماده تا {n} روز.',
  'eco.alreadyBuilding': 'در حال ساخت همین نوع پروژه هستید.',
  'eco.factory.name': 'کارخانه',
  'eco.factory.desc': '{a} ظرفیت صناعی می‌افزاید. صنعت موتور درآمد ملی است.',
  'eco.infrastructure.name': 'زیرساخت',
  'eco.infrastructure.desc':
      'جاده‌ها و شبکه‌ها را ارتقا می‌دهد: {a}+ زیرساخت و {b}+ ظرفیت صناعی. '
      'زیرساخت سایر درآمدها را چند برابر می‌کند.',
  'eco.militaryFactory.name': 'کارخانه نظامی',
  'eco.militaryFactory.desc':
      'هزینه جذب نیرو را {a}٪ کاهش می‌دهد و {b} ظرفیت صناعی می‌افزاید.',
  'eco.fortification.name': 'خط استحکامات',
  'eco.fortification.desc':
      'به یگان‌هایی که در خاک خود می‌جنگند {a}٪ قدرت دفاعی می‌دهد.',

  'mil.title': 'نیروهای مسلح',
  'mil.recruit': 'جذب نیرو',
  'mil.infantry': 'لشکر پیاده‌نظام',
  'mil.armor': 'لشکر زرهی',
  'mil.infantry.desc':
      'یگان خط مقدم با هزینه مناسب. قوی در دفاع و جنگ فرسایشی.',
  'mil.armor.desc':
      'یگان نفوذی گران‌قیمت. توان تهاجمی بالا، هزینه نگهداری بالا.',
  'mil.recruitBtn': 'جذب',
  'mil.recruited': '{name} در {region} تشکیل شد.',
  'mil.capacityFull':
      'نیروی انسانی تمام شد. جمعیت، سقف ارتش شما را تعیین می‌کند.',
  'mil.insufficient': 'خزانه کافی نیست — {need} لازم است.',
  'mil.roster': 'ترکیب نیروها',
  'mil.empty':
      'هنوز یگانی تشکیل نشده است. نخستین لشکر خود را از بالا جذب کنید.',
  'mil.totalStrength': 'توان رزمی کل',
  'mil.readiness': 'آمادگی',
  'mil.maintenance': 'هزینه نگهداری ماهانه',
  'mil.homeRegion': 'استقرار',
  'mil.experience': 'تجربه',
  'mil.formation': 'یگان',
  'mil.type': 'نوع',
  'mil.power': 'توان',
  'mil.disband': 'انحلال',
  'mil.disbandConfirm':
      'یگان {name} منحل شود؟ این یگان برای همیشه از دست می‌رود.',
  'mil.attritionNote':
      'یگان‌های آسیب‌دیده در زمان صلح روزانه ۱٪ توان رزمی خود را بازیابی می‌کنند.',
  'mil.discount': '{n}٪ تخفیف جذب به‌دلیل کارخانه‌های نظامی',
  'mil.manpowerUse': 'نیروی انسانی به‌کاررفته',
  'mil.maxManpower': 'نیروی انسانی در دسترس',
  'mil.deployHint': 'یگان‌های جدید در خاک خودی تشکیل می‌شوند.',

  'bt.title': 'عملیات نظامی',
  'bt.selectTarget': 'کشور هدف را انتخاب کنید',
  'bt.noTargets': 'در حال حاضر کشور قابل دسترسی برای اقدام نظامی وجود ندارد.',
  'bt.assessment': 'برآورد نبرد',
  'bt.attacker': 'مهاجم',
  'bt.defender': 'مدافع',
  'bt.estimatedChance': 'برآورد احتمال پیروزی',
  'bt.ourStrength': 'توان اعزامی شما',
  'bt.theirStrength': 'توان مدافع',
  'bt.expectedLosses': 'تلفات مورد انتظار',
  'bt.supply': 'تدارکات',
  'bt.supplyGood': 'مناسب',
  'bt.supplyStrained': 'تحت فشار',
  'bt.supplyCritical': 'بحرانی',
  'bt.declare': 'آغاز تهاجم',
  'bt.sueForPeace': 'درخواست صلح',
  'bt.front': 'جبهه',
  'bt.inProgress': 'نبرد در {region} جریان دارد',
  'bt.progress': 'پیشرفت نبرد',
  'bt.roundLog': 'گزارش درگیری',
  'bt.awaiting': 'در انتظار تیک بعدی شبیه‌سازی…',
  'bt.report': 'گزارش نبرد',
  'bt.outcome.win': 'پیروزی',
  'bt.outcome.loss': 'شکست',
  'bt.narrative.win':
      '{attacker} خطوط {defender} را در {region} شکست. '
      'نیروهای میدانی مدافع متلاشی شدند.',
  'bt.narrative.loss':
      'تهاجم {attacker} در {region} دفع شد. {defender} خط را حفظ کرد.',
  'bt.lossesUs': 'تلفات شما',
  'bt.lossesThem': 'تلفات دشمن',
  'bt.remainingUs': 'توان باقی‌مانده شما',
  'bt.remainingThem': 'توان باقی‌مانده دشمن',
  'bt.loot': 'غرامت جنگی به‌دست‌آمده',
  'bt.territoryGained': '{region} اشغال شد.',
  'bt.territoryHeld': 'هیچ سرزمینی جابه‌جا نشد.',
  'bt.acknowledge': 'تأیید',
  'bt.cannotAlly': 'نمی‌توانید به متحد خود حمله کنید.',
  'bt.cannotPact': 'پیمان عدم تجاوز مانع این حمله است. نخست آن را لغو کنید.',
  'bt.cannotBorder': 'این کشور در تئاتر قابل دسترس شما نیست.',
  'bt.noArmy': 'یگان آماده رزم ندارید.',
  'bt.warOngoing': 'شما از قبل با {name} در حال جنگ هستید.',
  'bt.peaceMade': 'صلح با {name} امضا شد.',
  'bt.peaceRejected': '{name} تا زمانی که برتری دارد صلح را نمی‌پذیرد.',
  'bt.warDeclared': 'به {name} اعلان جنگ شد.',
  'bt.battleJoined': 'برخورد! نبرد در {region} آغاز شد.',
  'bt.round': 'دور {n}',
  'bt.log.clash': 'دور {n}: {a} {ap} در برابر {d} {dp}',
  'bt.log.attackerGaining': 'دور {n}: نیروهای شما پیشروی می‌کنند',
  'bt.log.defenderGaining': 'دور {n}: مدافع ضدحمله می‌کند',
  'bt.log.steady': 'دور {n}: تبادل آتش، خطوط پابرجاست',

  'dip.title': 'دیپلماسی',
  'dip.relations': 'روابط دوجانبه',
  'dip.improve': 'بهبود روابط',
  'dip.improved': 'روابط با {name} به {value} رسید.',
  'dip.pact': 'پیمان عدم تجاوز',
  'dip.alliance': 'اتحاد',
  'dip.proposed': 'پیشنهاد برای {name} ارسال شد',
  'dip.accepted': '{name} پذیرفت.',
  'dip.rejected': '{name} پیشنهاد را رد کرد.',
  'dip.alreadyExists': 'این توافق از قبل برقرار است.',
  'dip.agreements': 'توافق‌های فعال',
  'dip.noAgreements': 'هنوز توافقی امضا نشده است.',
  'dip.allies': 'متحدان',
  'dip.noAllies': 'متحدی وجود ندارد',
  'dip.costLine': 'هزینه: {cost}',
  'dip.personality': 'دکترین',
  'dip.attitude': 'نگرش',
  'dip.attitude.hostile': 'خصمانه',
  'dip.attitude.cold': 'سرد',
  'dip.attitude.neutral': 'بی‌طرف',
  'dip.attitude.warm': 'گرم',
  'dip.attitude.friendly': 'دوستانه',
  'dip.needsRelations': 'نیازمند روابط حداقل {n} است.',
  'dip.atWarNoDiplomacy': 'شما با {name} در جنگ هستید. مذاکره امکان‌پذیر نیست.',
  'dip.signWith': 'امضا با {name}',
  'dip.treaty.signed': 'پیمان با {name} امضا شد',
  'dip.breakAgreement': 'لغو',
  'dip.renounceConfirm': '{type} با {name} لغو شود؟',
  'dip.renounced': 'توافق با {name} لغو شد',
  'dip.trustPenalty': 'لغو پیمان به روابط آسیب می‌زند.',
  'dip.pactLabel': 'عدم تجاوز',
  'dip.allianceLabel': 'اتحاد',

  'ai.expansionist': 'توسعه‌طلب',
  'ai.industrialist': 'صنعت‌گرا',
  'ai.defensive': 'تدافعی',
  'ai.opportunist': 'فرصت‌طلب',

  'evt.title': 'جریان رویدادها',
  'evt.all': 'همه',
  'evt.empty':
      'رویدادی ثبت نشده است. شبیه‌سازی را پیش ببرید تا گزارش‌ها را ببینید.',
  'evt.filter': 'پالایش',
  'evt.showing': 'نمایش {n} از {total} رکورد',
  'evt.kind.economy': 'اقتصاد',
  'evt.kind.construction': 'ساخت‌وساز',
  'evt.kind.diplomacy': 'دیپلماسی',
  'evt.kind.recruitment': 'نظامی',
  'evt.kind.battle': 'جنگ',
  'evt.kind.intelligence': 'اطلاعات',
  'evt.kind.game': 'سامانه',

  'evt.econ.title': 'رشد اقتصادی در {country}',
  'evt.econ.body':
      '{country} تولید صناعی خود را افزایش داد. خزانه اکنون {treasury}.',
  'evt.build.title': '{building} در {country} تکمیل شد',
  'evt.build.body':
      '{building} به بهره‌برداری رسید و {amount} به توان ملی افزود.',
  'evt.research.title': 'پیشرفت برنامه پژوهشی در {country}',
  'evt.research.body': 'آزمایشگاه‌های غیرنظامی {country} پیشرفت گزارش کردند.',
  'evt.dip.title': '{type} امضا شد: {a} و {b}',
  'evt.dip.body': 'روابط میان {a} و {b} اکنون {value} است.',
  'evt.recruit.title': '{country} یگان‌های تازه تشکیل داد',
  'evt.recruit.body': '{count} لشکر تازه به ترکیب نیروهای {country} افزوده شد.',
  'evt.battle.title': 'نبرد در {region} پایان یافت',
  'evt.battle.body':
      '{winner} بر {loser} پیروز شد. {losses} توان رزمی از دست رفت.',
  'evt.war.title': 'جنگ: {a} به {b} حمله کرد',
  'evt.war.body': 'درگیری در {region} آغاز شد.',
  'evt.peace.title': 'صلح میان {a} و {b}',
  'evt.peace.body': 'خصومت در {region} متوقف شد.',
  'evt.ai.title': '{country} ارتش خود را گسترش داد',
  'evt.ai.body': '{country} در توان نظامی سرمایه‌گذاری می‌کند.',
  'evt.tension.title': 'افزایش تنش میان {a} و {b}',
  'evt.tension.body': 'روابط به {value} کاهش یافت.',
  'evt.game.title': 'کارزار آغاز شد',
  'evt.game.body': 'اکنون فرماندهی {country} با شماست.',

  'set.title': 'تنظیمات',
  'set.audio': 'صدا',
  'set.sound': 'جلوه‌های صوتی',
  'set.music': 'موسیقی',
  'set.soundNote':
      'این نسخه هیچ فایل صوتی ندارد — این گزینه برای نسخه‌های آینده نگه داشته شده است.',
  'set.language': 'زبان',
  'set.langEn': 'English',
  'set.langFa': 'فارسی',
  'set.graphics': 'گرافیک و پویانمایی',
  'set.animations': 'پویانمایی رابط کاربری',
  'set.animationsNote':
      'خاموش‌کردن پویانمایی حرکت را کم و مصرف باتری را پایین می‌آورد.',
  'set.mapMode': 'حالت پیش‌فرض نقشه',
  'set.data': 'داده‌های ذخیره',
  'set.deleteSave': 'حذف کارزار ذخیره‌شده',
  'set.deleteConfirm': 'کارزار ذخیره‌شده حذف شود؟ این کار بازگشت‌پذیر نیست.',
  'set.deleted': 'کارزار ذخیره‌شده حذف شد.',
  'set.restartRequired': 'زبان بلافاصله اعمال شد.',

  'about.title': 'درباره',
  'about.lead': 'فرمانروایی جهان یک شبیه‌سازی استراتژی بزرگ است.',
  'about.body':
      'فرماندهی یکی از ده قدرت بزرگ را بر عهده می‌گیرید و آن را در اقتصاد، '
      'دیپلماسی و جنگ هدایت می‌کنید. هر عددی که می‌بینید از یک شبیه‌سازی زنده '
      'می‌آید — درآمد، ساخت‌وساز، جذب نیرو، نبردها و تصمیم رقیبان همگی با '
      'ساعت بازی پیش می‌روند.',
  'about.scopeTitle': 'این نسخه',
  'about.scopeBody':
      'نسخه نمایشی ۰.۲.۰ نخستین بخش قابل بازی است: نقشه جهان، میز فرماندهی و '
      'ساعت بازی، اقتصاد، مدیریت ارتش، یک سامانه نبرد نوبتی، دیپلماسی پایه، '
      'هوش مصنوعی رقیبان و ذخیره/بارگذاری.',
  'about.notIncludedTitle': 'هنوز گنجانده نشده',
  'about.notIncludedBody':
      'بازی چندنفره، حساب آنلاین، جاسوسی، درخت فناوری، جنگ دریایی و مرزهای '
      'استانی برای نسخه‌های بعدی برنامه‌ریزی شده‌اند.',
  'about.dataTitle': 'درباره داده‌ها',
  'about.dataBody':
      'آمار کشورها مقادیر نمایشی و ساختگی و متوازن‌شده برای گیم‌پلی‌اند. '
      'خطوط ساحلی و مرزهای کشورها از مجموعه داده عمومی Natural Earth (مقیاس ۱:۵۰m) '
      'گرفته و برای خوانایی روی گوشی ساده‌سازی شده‌اند.',
  'about.creditsTitle': 'اعتبارها',
  'about.creditsBody':
      'قلم‌ها: Inter (SIL OFL 1.1) و Vazirmatn (SIL OFL 1.1). '
      'نقشه‌نگاری: Natural Earth (مالکیت عمومی). ساخته‌شده با Flutter.',

  'save.title': 'ذخیره کارزار',
  'save.saved': 'کارزار ذخیره شد · {date}',
  'save.failed': 'ذخیره کارزار ممکن نشد.',
  'save.loaded': 'کارزار بازگردانی شد.',
  'save.loadFailed': 'فایل ذخیره خوانده نشد.',
  'save.corrupted': 'داده ذخیره نامعتبر بود و نادیده گرفته شد.',
  'save.slotTitle': 'جایگاه ذخیره',
  'save.lastSaved': 'آخرین ذخیره {date}',
  'save.neverSaved': 'هرگز ذخیره نشده',
  'save.overwrite': 'کارزار ذخیره‌شده بازنویسی شود؟',
  'save.autosave': 'ذخیره خودکار',
  'save.details': 'پیشرفت ذخیره‌شده',
  'save.backToMenu': 'بازگشت به منوی اصلی',
  'save.quitConfirm':
      'به منوی اصلی بازگردیم؟ پیشرفت ذخیره‌نشده فقط در همین نشست باقی می‌ماند.',
};
