import '../core/balance.dart';

/// The research tree.
///
/// Five branches × three tiers, hand-authored so the demo always has a legible
/// progression: tier 2 requires any tier 1 tech of the same branch, tier 3
/// requires the named tier 2 prerequisite. Effects are small, additive
/// percentages so no single technology can break the balance tables.
class TechTree {
  TechTree._();

  static const List<TechSpec> all = [
    // ------------------------------------------------------------ industry
    TechSpec(
      id: 'ind_assembly',
      branch: TechBranch.industry,
      tier: 1,
      days: 90,
      cost: 18000,
      requires: [],
      industrial: 4,
      factoryOutputPct: 0.06,
    ),
    TechSpec(
      id: 'ind_massprod',
      branch: TechBranch.industry,
      tier: 2,
      days: 150,
      cost: 42000,
      requires: ['ind_assembly'],
      industrial: 7,
      factoryOutputPct: 0.10,
    ),
    TechSpec(
      id: 'ind_automation',
      branch: TechBranch.industry,
      tier: 3,
      days: 240,
      cost: 88000,
      requires: ['ind_massprod'],
      industrial: 12,
      factoryOutputPct: 0.16,
      infrastructure: 3,
    ),
    // ------------------------------------------------------------ military
    TechSpec(
      id: 'mil_smallarms',
      branch: TechBranch.military,
      tier: 1,
      days: 80,
      cost: 16000,
      requires: [],
      attackPct: 0.06,
      defensePct: 0.05,
    ),
    TechSpec(
      id: 'mil_armor',
      branch: TechBranch.military,
      tier: 2,
      days: 140,
      cost: 38000,
      requires: ['mil_smallarms'],
      attackPct: 0.11,
      defensePct: 0.07,
    ),
    TechSpec(
      id: 'mil_doc',
      branch: TechBranch.military,
      tier: 3,
      days: 220,
      cost: 76000,
      requires: ['mil_armor'],
      attackPct: 0.16,
      defensePct: 0.13,
    ),
    // ----------------------------------------------------------- logistics
    TechSpec(
      id: 'log_rail',
      branch: TechBranch.logistics,
      tier: 1,
      days: 70,
      cost: 14000,
      requires: [],
      supplyBonus: 0.10,
      infrastructure: 2,
    ),
    TechSpec(
      id: 'log_motor',
      branch: TechBranch.logistics,
      tier: 2,
      days: 130,
      cost: 34000,
      requires: ['log_rail'],
      supplyBonus: 0.14,
      infrastructure: 4,
    ),
    TechSpec(
      id: 'log_airlift',
      branch: TechBranch.logistics,
      tier: 3,
      days: 210,
      cost: 70000,
      requires: ['log_motor'],
      supplyBonus: 0.18,
      infrastructure: 6,
    ),
    // ------------------------------------------------------------- economy
    TechSpec(
      id: 'eco_tax',
      branch: TechBranch.economy,
      tier: 1,
      days: 75,
      cost: 15000,
      requires: [],
      incomePct: 0.06,
    ),
    TechSpec(
      id: 'eco_trade',
      branch: TechBranch.economy,
      tier: 2,
      days: 135,
      cost: 36000,
      requires: ['eco_tax'],
      incomePct: 0.10,
      infrastructure: 2,
    ),
    TechSpec(
      id: 'eco_finance',
      branch: TechBranch.economy,
      tier: 3,
      days: 220,
      cost: 74000,
      requires: ['eco_trade'],
      incomePct: 0.16,
      infrastructure: 4,
    ),
    // ------------------------------------------------------------- science
    TechSpec(
      id: 'sci_labs',
      branch: TechBranch.science,
      tier: 1,
      days: 90,
      cost: 20000,
      requires: [],
      researchPct: 0.18,
      incomePct: 0.02,
    ),
    TechSpec(
      id: 'sci_computing',
      branch: TechBranch.science,
      tier: 2,
      days: 160,
      cost: 46000,
      requires: ['sci_labs'],
      researchPct: 0.28,
      factoryOutputPct: 0.06,
    ),
    TechSpec(
      id: 'sci_ai',
      branch: TechBranch.science,
      tier: 3,
      days: 250,
      cost: 95000,
      requires: ['sci_computing'],
      researchPct: 0.40,
      factoryOutputPct: 0.12,
      industrial: 6,
    ),
  ];

  static TechSpec? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static List<TechSpec> ofBranch(TechBranch branch) =>
      all.where((t) => t.branch == branch).toList(growable: false);
}
