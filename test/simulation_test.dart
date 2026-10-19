import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/balance.dart';
import 'package:flutter_app/models/diplomatic_agreement.dart';
import 'package:flutter_app/core/campaign_controller.dart';
import 'package:flutter_app/simulation/game_simulation.dart';
import 'package:flutter_app/simulation/economy_engine.dart';

void main() {
  test('economy produces positive income and a real budget', () {
    final sim = GameSimulation();
    final s = sim.newCampaign('us');
    final b = const EconomyEngine().breakdown(s, 'us');
    expect(b.totalIncome, greaterThan(0));
    expect(b.totalExpenses, greaterThan(0));
    expect(s.player.treasury, greaterThan(0));
  });

  test('clock advances days and changes the world', () {
    final sim = GameSimulation();
    var s = sim.newCampaign('us');
    final t0 = s.player.treasury;
    for (var i = 0; i < 40; i++) {
      s = sim.tick(s, s.speed);
    }
    expect(s.day, 40);
    expect(s.player.treasury, isNot(t0));
    expect(s.date.year, 2027);
  });

  test('recruitment deducts cost and adds a unit', () {
    final c = CampaignController();
    c.startNewCampaign('de');
    final before = c.state!.player.treasury;
    final ok = c.recruit(UnitType.infantry);
    expect(ok, isTrue);
    expect(c.state!.unitsOf('de').length, greaterThan(0));
    expect(c.state!.player.treasury, lessThan(before));
    c.dispose();
  });

  test('construction queues, is paid for and completes', () {
    final c = CampaignController();
    c.startNewCampaign('jp');
    final ok = c.startConstruction(BuildingType.factory);
    expect(ok, isTrue);
    expect(c.state!.constructionOf('jp'), isNotEmpty);
    for (var i = 0; i < 40; i++) {
      c.advanceOneDay();
    }
    expect(c.state!.constructionOf('jp'), isEmpty);
    expect(c.state!.player.buildingCount(BuildingType.factory), greaterThan(0));
    c.dispose();
  });

  test('cannot recruit without funds', () {
    final c = CampaignController();
    c.startNewCampaign('br');
    // Drain the treasury well below any unit cost.
    var guard = 0;
    while (c.state!.player.treasury >
            Balance.units[UnitType.armor]!.cost * 0.5 &&
        guard++ < 4000) {
      c.advanceOneDay();
    }
    if (c.state!.player.treasury <= Balance.units[UnitType.armor]!.cost * 0.5) {
      expect(c.recruit(UnitType.armor), isFalse);
    }
    c.dispose();
  });

  test('battle resolves and changes military strength', () {
    final sim = GameSimulation();
    var s = sim.newCampaign('us');
    // Pick a legitimately reachable target from the dataset rather than
    // hard-coding one, so the test tracks the theatre table.
    final targets = sim.battle.availableTargets(s, 'us');
    expect(targets, isNotEmpty);
    final target = targets.first;
    expect(sim.battle.validateAttack(s, 'us', target), isNull);
    // A nation outside the theatre table must be refused.
    expect(sim.battle.validateAttack(s, 'us', 'cn'), 'bt.cannotBorder');
    s = sim.commitDeclareWar(s, target);
    expect(s.wars, isNotEmpty);
    expect(s.battles, isNotEmpty);
    var resolved = false;
    for (var i = 0; i < 60; i++) {
      s = sim.tick(s, s.speed);
      if (s.lastBattleReport != null) {
        resolved = true;
        break;
      }
    }
    expect(resolved, isTrue);
    expect(s.lastBattleReport!.attackerPowerBefore, greaterThan(0));
  });

  test('diplomacy stores agreements that affect later play', () {
    final sim = GameSimulation();
    var s = sim.newCampaign('us');
    // Repeatedly improve relations with the UK until a pact is accepted.
    var signed = false;
    for (var i = 0; i < 40 && !signed; i++) {
      s = sim.commitImproveRelations(s, 'uk');
      final v = sim.proposeAgreement(s, 'uk', AgreementType.nonAggression);
      if (v.success) {
        s = sim.commitAgreement(
          s,
          'uk',
          AgreementType.nonAggression,
          accepted: true,
        );
        signed = true;
      }
    }
    expect(
      signed,
      isTrue,
      reason: 'UK should accept a pact after relations improve',
    );
    expect(s.hasAgreement('us', 'uk', AgreementType.nonAggression), isTrue);
    // A pact must actually block an attack.
    expect(sim.battle.validateAttack(s, 'us', 'uk'), 'bt.cannotPact');
  });

  test('AI nations act and never produce invalid state', () {
    final sim = GameSimulation();
    var s = sim.newCampaign('ir');
    for (var i = 0; i < 200; i++) {
      s = sim.tick(s, s.speed);
    }
    for (final c in s.countries.values) {
      expect(c.treasury.isFinite, isTrue);
      expect(c.stability, greaterThanOrEqualTo(0));
      expect(c.stability, lessThanOrEqualTo(100));
      expect(c.population, greaterThan(0));
    }
    // The AI should have done *something* observable over 200 days.
    final aiEvents = s.events.entries.where((e) => e.countryId != 'ir');
    expect(aiEvents, isNotEmpty);
  });
}
