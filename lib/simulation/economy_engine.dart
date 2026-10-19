import '../core/balance.dart';
import '../core/constants.dart';
import '../models/country.dart';
import '../models/game_state.dart';
import 'industry_engine.dart';

/// One line of a nation's monthly budget.
class BudgetLine {
  const BudgetLine(this.labelKey, this.amount, {this.detail});

  /// Localization key (or plain label for formula-derived rows).
  final String labelKey;
  final double amount;
  final String? detail;
}

/// The complete monthly budget of one nation.
class BudgetBreakdown {
  const BudgetBreakdown({
    required this.income,
    required this.expenses,
    required this.industrialOutput,
    required this.resourceTrade,
    required this.civilUpkeep,
    required this.militaryUpkeep,
    required this.constructionSpend,
    this.factoryOutput = 0,
    this.exports = 0,
    this.imports = 0,
    this.tradeDeals = 0,
    this.occupationIncome = 0,
    this.occupationCost = 0,
    this.sanctionLoss = 0,
  });

  final List<BudgetLine> income;
  final List<BudgetLine> expenses;
  final double industrialOutput;
  final double resourceTrade;
  final double civilUpkeep;
  final double militaryUpkeep;
  final double constructionSpend;
  final double factoryOutput;
  final double exports;
  final double imports;
  final double tradeDeals;
  final double occupationIncome;
  final double occupationCost;
  final double sanctionLoss;

  double get totalIncome => income.fold(0.0, (a, b) => a + b.amount);
  double get totalExpenses => expenses.fold(0.0, (a, b) => a + b.amount);
  double get net => totalIncome - totalExpenses;

  double get dailyIncome => totalIncome / GameConstants.daysPerMonth;
  double get dailyExpenses => totalExpenses / GameConstants.daysPerMonth;
  double get dailyNet => net / GameConstants.daysPerMonth;
}

/// The single authoritative money model.
///
/// The economy screen, the dashboard and the daily simulation tick all read
/// their numbers from here — nothing is computed twice with different formulas.
class EconomyEngine {
  const EconomyEngine();

  static const IndustryEngine industry = IndustryEngine();

  double industrialOutputOf(Country c) =>
      c.industrial * Balance.incomePerIndustrial;

  double infrastructureMultiplier(Country c) =>
      1 + (c.infrastructure / 100) * Balance.infrastructureIncomeWeight;

  double stabilityMultiplier(Country c) =>
      Balance.stabilityFloor + (c.stability / 100) * Balance.stabilityWeight;

  double monthlyIncomeOf(Country c) {
    final base = industrialOutputOf(c) * infrastructureMultiplier(c);
    final stability = stabilityMultiplier(c);
    // Active war economies are taxed and disrupted.
    final warDrag = c.relations['__war'] ?? 1.0;
    return (base * stability + c.resourceIncome) * warDrag;
  }

  BudgetBreakdown breakdown(GameState state, String countryId) {
    final c = state.countries[countryId]!;
    final army = state.armyOf(countryId);
    final projects = state.constructionOf(countryId);
    final activeWars = state.wars.where((w) => w.involves(countryId)).length;
    final occupation = industry.occupationOf(state, countryId);
    final shortage = industry.shortagePenalty(state, c);
    final pressure = state.sanctionPressureOn(countryId);

    final industrialOutput =
        industrialOutputOf(c) *
        infrastructureMultiplier(c) *
        stabilityMultiplier(c) *
        c.techIncomeMultiplier;
    final warDisruption = 1 - (activeWars * 0.04).clamp(0.0, 0.18);
    // Enemy-held homeland and missing raw materials both cut output.
    final output =
        industrialOutput *
        warDisruption *
        (1 - occupation.homeLoss * 0.6) *
        (1 - shortage);

    final factories = industry.civilianOutput(state, c);
    final trade = industry.tradeFlows(state, countryId);
    final resourceTrade = c.resourceIncome * (1 - pressure);
    final sanctionLoss = c.resourceIncome * pressure;

    final civilUpkeep =
        c.population *
        Balance.upkeepPerMillion *
        (0.6 + c.infrastructure / 160);

    final militaryUpkeep = army.monthlyMaintenance;

    // Construction is billed as a monthly instalment; only the days still
    // remaining on each project inside the coming month are charged.
    var constructionSpend = 0.0;
    for (final order in projects) {
      final spec = Balance.buildings[order.type]!;
      final billedDays = order.daysRemaining
          .clamp(0, GameConstants.daysPerMonth)
          .toDouble();
      constructionSpend += spec.cost / spec.days * billedDays;
    }

    return BudgetBreakdown(
      income: [
        BudgetLine('eco.industrialOutput', output),
        if (factories > 0) BudgetLine('eco.factoryOutput', factories),
        BudgetLine('eco.resourceTrade', resourceTrade),
        if (trade.exports > 0) BudgetLine('eco.exports', trade.exports),
        if (trade.tradeDeals > 0)
          BudgetLine('eco.tradeDeals', trade.tradeDeals),
        if (occupation.income > 0)
          BudgetLine('eco.occupationIncome', occupation.income),
      ],
      expenses: [
        BudgetLine('eco.civilUpkeep', civilUpkeep),
        BudgetLine('eco.militaryUpkeep', militaryUpkeep),
        if (trade.imports > 0) BudgetLine('eco.imports', trade.imports),
        if (occupation.cost > 0)
          BudgetLine('eco.occupationCost', occupation.cost),
        if (constructionSpend > 0)
          BudgetLine('eco.constructionSpend', constructionSpend),
      ],
      industrialOutput: output,
      resourceTrade: resourceTrade,
      civilUpkeep: civilUpkeep,
      militaryUpkeep: militaryUpkeep,
      constructionSpend: constructionSpend,
      factoryOutput: factories,
      exports: trade.exports,
      imports: trade.imports,
      tradeDeals: trade.tradeDeals,
      occupationIncome: occupation.income,
      occupationCost: occupation.cost,
      sanctionLoss: sanctionLoss,
    );
  }

  /// Income/expense figures shown in the UI (monthly).
  double monthlyIncome(GameState s, String id) => breakdown(s, id).totalIncome;
  double monthlyExpenses(GameState s, String id) =>
      breakdown(s, id).totalExpenses;

  /// Manpower ceiling derived from population and stability.
  double manpowerCapacityOf(Country c) =>
      c.population *
      GameConstants.manpowerPerMillionPopulation *
      (0.7 + c.stability / 250);

  /// Total combat power the army screen displays.
  double armyStrength(GameState s, String id) => s.armyOf(id).totalPower;

  /// Composite national power used by the AI to judge other nations.
  double powerScore(GameState s, String id) {
    final c = s.countries[id]!;
    final army = s.armyOf(id);
    return c.industrial * 1.4 +
        c.infrastructure * 0.5 +
        army.combatScore * 0.9 +
        c.stability * 1.2 +
        c.population * 0.18 +
        c.treasury / 22000;
  }

  /// Applies one day of economic activity to a single nation.
  ///
  /// Returns the updated country. Never allows the treasury to fall outside the
  /// demo's safety rails and never produces negative income.
  Country applyDay(GameState state, String countryId) {
    final c = state.countries[countryId]!;
    final budget = breakdown(state, countryId);

    var treasury = c.treasury + budget.dailyIncome - budget.dailyExpenses;

    // Stability drifts toward the doctrine equilibrium, and falls while at war.
    var equilibrium = Balance.stabilityEquilibrium;
    final atWar = state.wars.any((w) => w.involves(countryId));
    if (atWar) equilibrium -= 12;
    if (budget.net < 0) {
      equilibrium -= (budget.net / 4000).clamp(0.0, 18);
    }
    equilibrium += (c.infrastructure - 60) / 12;
    // Food shortages, sanctions and foreign occupation all erode order.
    equilibrium -= industry.shortageOf(state, c, ResourceType.food) * 20;
    equilibrium -= state.sanctionPressureOn(countryId) * 18;
    equilibrium -= industry.occupationOf(state, countryId).homeLoss * 25;
    equilibrium = equilibrium.clamp(10.0, 88.0);

    var stability =
        c.stability + (equilibrium - c.stability) * Balance.stabilityDrift;

    if (atWar) stability -= Balance.wartimeStabilityDrain;

    // Bankruptcy erodes political order; surplus slowly restores it.
    if (treasury < 0) {
      stability -= 0.05;
    } else if (treasury > 200000) {
      stability += 0.02;
    }

    // Industrial capacity creeps up with strong infrastructure.
    final industrialDrift =
        (c.infrastructure - 55) / 100 * 0.004 * (stability / 70);

    treasury = _clampTreasury(treasury);
    stability = stability.clamp(
      GameConstants.minStability,
      GameConstants.maxStability,
    );
    final industrial = (c.industrial + industrialDrift).clamp(
      GameConstants.minIndustrial,
      GameConstants.maxIndustrial,
    );

    return c.copyWith(
      treasury: treasury,
      stability: stability,
      industrial: industrial,
    );
  }

  double _clampTreasury(double v) =>
      v.clamp(GameConstants.minTreasury, GameConstants.maxTreasury);

  /// Monthly figures used on the country-selection preview.
  double previewMonthlyIncome(Country c) =>
      industrialOutputOf(c) *
          infrastructureMultiplier(c) *
          stabilityMultiplier(c) +
      c.civilianFactories * Balance.civilianFactoryOutput +
      c.resourceIncome;
}
