import '../../core/balance.dart';
import '../../models/game_state.dart';
import '../../models/world_politics.dart';
import '../../simulation/economy_engine.dart';

/// Every metric the nation dashboards can rank on.
enum NationMetric {
  power,
  income,
  net,
  treasury,
  industry,
  army,
  population,
  stability,
  infrastructure,
  territory,
  techs,
}

/// A flat, read-only snapshot of one nation's headline numbers.
class NationSnapshot {
  const NationSnapshot({required this.id, required this.values});

  final String id;
  final Map<NationMetric, double> values;

  double operator [](NationMetric m) => values[m] ?? 0;
}

/// Computes world-wide snapshots and rankings from one [GameState].
///
/// Everything is derived from the same engines the simulation uses, so the
/// dashboards can never disagree with the economy or military screens.
class WorldStats {
  WorldStats(this.state, {EconomyEngine economy = const EconomyEngine()})
    : _economy = economy {
    for (final id in state.countries.keys) {
      final c = state.countries[id]!;
      final budget = _economy.breakdown(state, id);
      _snapshots[id] = NationSnapshot(
        id: id,
        values: {
          NationMetric.power: _economy.powerScore(state, id),
          NationMetric.income: budget.totalIncome,
          NationMetric.net: budget.net,
          NationMetric.treasury: c.treasury,
          NationMetric.industry: c.industrial,
          NationMetric.army: state.armyOf(id).combatScore,
          NationMetric.population: c.population,
          NationMetric.stability: c.stability,
          NationMetric.infrastructure: c.infrastructure,
          NationMetric.territory: state.territoryCountOf(id).toDouble(),
          NationMetric.techs: c.techs.length.toDouble(),
        },
      );
      _budgets[id] = budget;
    }
  }

  final GameState state;
  final EconomyEngine _economy;
  final Map<String, NationSnapshot> _snapshots = {};
  final Map<String, BudgetBreakdown> _budgets = {};
  final Map<NationMetric, List<String>> _orderCache = {};

  NationSnapshot of(String id) => _snapshots[id]!;
  BudgetBreakdown budgetOf(String id) => _budgets[id]!;

  int get count => _snapshots.length;

  /// Country ids ordered best-first for [metric].
  List<String> ordered(NationMetric metric) =>
      _orderCache.putIfAbsent(metric, () {
        final ids = _snapshots.keys.toList();
        ids.sort(
          (a, b) => _snapshots[b]![metric].compareTo(_snapshots[a]![metric]),
        );
        return ids;
      });

  /// 1-based world rank of [id] for [metric].
  int rankOf(String id, NationMetric metric) => ordered(metric).indexOf(id) + 1;

  double maxOf(NationMetric metric) {
    var m = 0.0;
    for (final s in _snapshots.values) {
      if (s[metric] > m) m = s[metric];
    }
    return m;
  }

  double averageOf(NationMetric metric) {
    if (_snapshots.isEmpty) return 0;
    var total = 0.0;
    for (final s in _snapshots.values) {
      total += s[metric];
    }
    return total / _snapshots.length;
  }

  /// Share of world total for [metric], 0..1.
  double shareOf(String id, NationMetric metric) {
    var total = 0.0;
    for (final s in _snapshots.values) {
      total += s[metric].clamp(0, double.infinity);
    }
    if (total <= 0) return 0;
    return (of(id)[metric].clamp(0, double.infinity)) / total;
  }

  /// Radar profile (0..1 per axis) used by the comparison chart.
  List<double> radarProfile(String id) => [
    for (final m in radarAxes) _norm(id, m),
  ];

  static const List<NationMetric> radarAxes = [
    NationMetric.income,
    NationMetric.industry,
    NationMetric.army,
    NationMetric.stability,
    NationMetric.infrastructure,
    NationMetric.population,
  ];

  double _norm(String id, NationMetric m) {
    final max = maxOf(m);
    if (max <= 0) return 0;
    return (of(id)[m] / max).clamp(0.0, 1.0);
  }

  /// Overall "tier" of a nation derived from its power rank.
  NationTier tierOf(String id) {
    final rank = rankOf(id, NationMetric.power);
    final f = rank / count;
    if (rank <= 3) return NationTier.superpower;
    if (f <= 0.25) return NationTier.greatPower;
    if (f <= 0.6) return NationTier.regionalPower;
    return NationTier.minorPower;
  }
}

enum NationTier { superpower, greatPower, regionalPower, minorPower }

/// Bilingual labels used by the nation dashboards.
///
/// Kept local to the feature so the shared localization table stays focused
/// on the core screens.
class NationLabels {
  NationLabels(this.fa);

  final bool fa;

  String metric(NationMetric m) => switch (m) {
    NationMetric.power => fa ? 'قدرت ملی' : 'National power',
    NationMetric.income => fa ? 'درآمد ماهانه' : 'Monthly income',
    NationMetric.net => fa ? 'تراز خالص' : 'Net balance',
    NationMetric.treasury => fa ? 'خزانه' : 'Treasury',
    NationMetric.industry => fa ? 'ظرفیت صنعتی' : 'Industry',
    NationMetric.army => fa ? 'توان ارتش' : 'Army strength',
    NationMetric.population => fa ? 'جمعیت' : 'Population',
    NationMetric.stability => fa ? 'ثبات' : 'Stability',
    NationMetric.infrastructure => fa ? 'زیرساخت' : 'Infrastructure',
    NationMetric.territory => fa ? 'قلمرو' : 'Territory',
    NationMetric.techs => fa ? 'فناوری‌ها' : 'Technologies',
  };

  String metricShort(NationMetric m) => switch (m) {
    NationMetric.power => fa ? 'قدرت' : 'Power',
    NationMetric.income => fa ? 'درآمد' : 'Income',
    NationMetric.net => fa ? 'تراز' : 'Net',
    NationMetric.treasury => fa ? 'خزانه' : 'Treasury',
    NationMetric.industry => fa ? 'صنعت' : 'Industry',
    NationMetric.army => fa ? 'ارتش' : 'Army',
    NationMetric.population => fa ? 'جمعیت' : 'People',
    NationMetric.stability => fa ? 'ثبات' : 'Stability',
    NationMetric.infrastructure => fa ? 'زیرساخت' : 'Infra',
    NationMetric.territory => fa ? 'قلمرو' : 'Territory',
    NationMetric.techs => fa ? 'فناوری' : 'Tech',
  };

  String tier(NationTier t) => switch (t) {
    NationTier.superpower => fa ? 'ابرقدرت' : 'Superpower',
    NationTier.greatPower => fa ? 'قدرت بزرگ' : 'Great power',
    NationTier.regionalPower => fa ? 'قدرت منطقه‌ای' : 'Regional power',
    NationTier.minorPower => fa ? 'قدرت کوچک' : 'Minor power',
  };

  String resource(ResourceType r) => switch (r) {
    ResourceType.oil => fa ? 'نفت' : 'Oil',
    ResourceType.steel => fa ? 'فولاد' : 'Steel',
    ResourceType.aluminium => fa ? 'آلومینیوم' : 'Aluminium',
    ResourceType.rubber => fa ? 'لاستیک' : 'Rubber',
    ResourceType.food => fa ? 'غذا' : 'Food',
    ResourceType.energy => fa ? 'انرژی' : 'Energy',
  };

  String equipment(EquipmentType e) => switch (e) {
    EquipmentType.smallArms => fa ? 'سلاح سبک' : 'Small arms',
    EquipmentType.artillery => fa ? 'توپخانه' : 'Artillery',
    EquipmentType.armor => fa ? 'زرهی' : 'Armour',
    EquipmentType.aircraft => fa ? 'هواپیما' : 'Aircraft',
  };

  String branch(TechBranch b) => switch (b) {
    TechBranch.industry => fa ? 'صنعت' : 'Industry',
    TechBranch.military => fa ? 'نظامی' : 'Military',
    TechBranch.logistics => fa ? 'لجستیک' : 'Logistics',
    TechBranch.economy => fa ? 'اقتصاد' : 'Economy',
    TechBranch.science => fa ? 'علم' : 'Science',
  };

  String tech(String id) {
    const names = <String, List<String>>{
      'ind_assembly': ['Assembly lines', 'خط مونتاژ'],
      'ind_massprod': ['Mass production', 'تولید انبوه'],
      'ind_automation': ['Automation', 'خودکارسازی'],
      'mil_smallarms': ['Modern small arms', 'سلاح سبک مدرن'],
      'mil_armor': ['Armoured warfare', 'جنگ زرهی'],
      'mil_doc': ['Combined-arms doctrine', 'دکترین تسلیحات ترکیبی'],
      'log_rail': ['Rail logistics', 'لجستیک ریلی'],
      'log_motor': ['Motorised supply', 'تدارکات موتوری'],
      'log_airlift': ['Strategic airlift', 'پل هوایی راهبردی'],
      'eco_tax': ['Tax reform', 'اصلاح مالیاتی'],
      'eco_trade': ['Trade networks', 'شبکه‌های تجاری'],
      'eco_finance': ['Modern finance', 'مالیه مدرن'],
      'sci_labs': ['National laboratories', 'آزمایشگاه‌های ملی'],
      'sci_computing': ['Computing', 'رایانش'],
      'sci_ai': ['Artificial intelligence', 'هوش مصنوعی'],
    };
    final n = names[id];
    if (n == null) return id;
    return fa ? n[1] : n[0];
  }

  String agenda(AiAgenda a) => switch (a) {
    AiAgenda.economicMiracle => fa ? 'معجزه اقتصادی' : 'Economic miracle',
    AiAgenda.fortressState => fa ? 'دژ ملی' : 'Fortress state',
    AiAgenda.hegemony => fa ? 'هژمونی' : 'Hegemony',
    AiAgenda.revanchism => fa ? 'انتقام‌جویی' : 'Revanchism',
    AiAgenda.containment => fa ? 'مهار رقیب' : 'Containment',
    AiAgenda.balancing => fa ? 'موازنه' : 'Balancing',
  };

  String charter(BlocCharter c) => switch (c) {
    BlocCharter.defensive => fa ? 'دفاعی' : 'Defensive',
    BlocCharter.economic => fa ? 'اقتصادی' : 'Economic',
    BlocCharter.sphere => fa ? 'حوزه نفوذ' : 'Sphere',
  };

  String sanctionTier(SanctionTier t) => switch (t) {
    SanctionTier.targeted => fa ? 'هدفمند' : 'Targeted',
    SanctionTier.sectoral => fa ? 'بخشی' : 'Sectoral',
    SanctionTier.embargo => fa ? 'تحریم کامل' : 'Embargo',
  };

  String sector(String code) {
    final base = code.replaceAll(RegExp(r'\d'), '');
    final suffix = code.length > base.length
        ? ' ${code.substring(base.length)}'
        : '';
    final name = switch (base) {
      'c' => fa ? 'مرکزی' : 'Central',
      'n' => fa ? 'شمالی' : 'North',
      's' => fa ? 'جنوبی' : 'South',
      'e' => fa ? 'شرقی' : 'East',
      'w' => fa ? 'غربی' : 'West',
      'ne' => fa ? 'شمال شرقی' : 'North-east',
      'nw' => fa ? 'شمال غربی' : 'North-west',
      'se' => fa ? 'جنوب شرقی' : 'South-east',
      'sw' => fa ? 'جنوب غربی' : 'South-west',
      _ => code.toUpperCase(),
    };
    return '$name$suffix';
  }
}
