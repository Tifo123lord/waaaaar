/// Real-world leadership of every nation in the campaign: supreme leader,
/// head of state, deputy, head of government, foreign minister, defence
/// minister and the top military commanders.
///
/// The roster lives in the generated `country_leaders_data.dart`
/// (see `tool/leaders/`). Portraits are bundled under `assets/leaders/`.
library;

part 'country_leaders_data.dart';

/// The office a [Leader] holds. Order here is the display order.
enum LeaderRole {
  supremeLeader,
  headOfState,
  deputyHeadOfState,
  headOfGovernment,
  foreignMinister,
  defenceMinister,
  chiefOfDefence,
  serviceCommander,
}

/// Broad grouping used to section the leadership panel.
enum LeaderGroup { executive, cabinet, military }

extension LeaderRoleX on LeaderRole {
  LeaderGroup get group => switch (this) {
    LeaderRole.supremeLeader ||
    LeaderRole.headOfState ||
    LeaderRole.deputyHeadOfState ||
    LeaderRole.headOfGovernment => LeaderGroup.executive,
    LeaderRole.foreignMinister ||
    LeaderRole.defenceMinister => LeaderGroup.cabinet,
    LeaderRole.chiefOfDefence ||
    LeaderRole.serviceCommander => LeaderGroup.military,
  };
}

class Leader {
  const Leader(
    this.role,
    this.titleEn,
    this.titleFa,
    this.nameEn,
    this.nameFa, {
    this.rankEn,
    this.rankFa,
    this.portrait,
    this.since,
    this.hereditary = false,
  });

  final LeaderRole role;

  /// The country-specific title of the office, e.g. "Chancellor".
  final String titleEn, titleFa;
  final String nameEn, nameFa;

  /// Military rank, when the officeholder is a serving officer.
  final String? rankEn, rankFa;

  /// Bundled portrait asset, or null when no free photo exists.
  final String? portrait;

  /// ISO date (yyyy-mm-dd) the officeholder took this post.
  final String? since;

  /// True for monarchs (no term of office).
  final bool hereditary;

  String title(bool fa) => fa ? titleFa : titleEn;
  String name(bool fa) => fa ? nameFa : nameEn;
  String? rank(bool fa) => fa ? rankFa : rankEn;

  /// Name with the military rank prefixed, e.g. "Gen. Dan Caine".
  String fullName(bool fa) {
    final r = rank(fa);
    return r == null ? name(fa) : '$r ${name(fa)}';
  }

  DateTime? get sinceDate => since == null ? null : DateTime.tryParse(since!);

  /// Initials for the portrait placeholder.
  String get initials {
    final parts = nameEn
        .replaceAll(RegExp(r'[^A-Za-zÀ-ž\s-]'), '')
        .split(RegExp(r'[\s-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class CountryLeaders {
  CountryLeaders._();

  /// The date the roster was last verified against public sources.
  static const String verifiedOn = '2026-10-19';

  /// Every officeholder of [countryId], in display order (empty if unknown).
  static List<Leader> of(String countryId) {
    final list = _kLeaders[countryId];
    if (list == null) return const [];
    return [...list]..sort((a, b) => a.role.index.compareTo(b.role.index));
  }

  static bool has(String countryId) => _kLeaders.containsKey(countryId);

  static Iterable<String> get countryIds => _kLeaders.keys;

  /// The person who actually holds supreme power: the Supreme Leader where one
  /// exists, else the head of government in a parliamentary monarchy or
  /// republic with a ceremonial president, else the head of state.
  static Leader? paramount(String countryId) {
    final list = of(countryId);
    if (list.isEmpty) return null;
    Leader? find(LeaderRole r) {
      for (final l in list) {
        if (l.role == r) return l;
      }
      return null;
    }

    return find(LeaderRole.supremeLeader) ??
        (_executiveHog.contains(countryId)
            ? find(LeaderRole.headOfGovernment)
            : null) ??
        find(LeaderRole.headOfState) ??
        list.first;
  }

  /// Nations whose head of government, not head of state, wields executive
  /// power (parliamentary systems and absolute-monarchy crown princes).
  static const Set<String> _executiveHog = {
    'ca',
    'uk',
    'de',
    'it',
    'es',
    'nl',
    'se',
    'no',
    'pl',
    'gr',
    'il',
    'et',
    'in',
    'pk',
    'jp',
    'th',
    'au',
    'sa',
  };

  /// Every distinct portrait asset referenced by the roster.
  static Set<String> get allPortraits => {
    for (final list in _kLeaders.values)
      for (final l in list)
        if (l.portrait != null) l.portrait!,
  };
}
