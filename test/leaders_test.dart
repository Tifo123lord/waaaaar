import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/data/country_data.dart';
import 'package:flutter_app/data/country_leaders.dart';

void main() {
  test('every playable nation has a complete leadership roster', () {
    for (final c in CountryData.build()) {
      final list = CountryLeaders.of(c.id);
      expect(list, isNotEmpty, reason: c.id);
      final roles = list.map((l) => l.role).toSet();
      expect(roles, contains(LeaderRole.headOfState), reason: c.id);
      expect(roles, contains(LeaderRole.foreignMinister), reason: c.id);
      expect(roles, contains(LeaderRole.defenceMinister), reason: c.id);
      expect(roles, contains(LeaderRole.chiefOfDefence), reason: c.id);
      expect(CountryLeaders.paramount(c.id), isNotNull, reason: c.id);
      for (final l in list) {
        expect(l.nameEn.trim(), isNotEmpty);
        expect(l.nameFa.trim(), isNotEmpty);
        expect(l.titleFa.trim(), isNotEmpty);
        if (l.since != null) {
          expect(l.sinceDate, isNotNull, reason: '${l.nameEn} ${l.since}');
        }
      }
    }
  });

  test('every referenced portrait is bundled', () {
    for (final p in CountryLeaders.allPortraits) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });

  test('Iran lists the Supreme Leader as paramount', () {
    final l = CountryLeaders.paramount('ir')!;
    expect(l.role, LeaderRole.supremeLeader);
  });
}
