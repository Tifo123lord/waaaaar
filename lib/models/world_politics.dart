/// Living-world politics: multi-nation blocs, sanctions, peace proposals,
/// great-power rivalry and per-nation AI agendas.
///
/// Everything here is plain data persisted inside [GameState]. The rules that
/// act on it live in `simulation/world_politics_engine.dart` and the AI.
library;

// ---------------------------------------------------------------------- blocs

/// Why a bloc exists; shapes what members expect from each other.
enum BlocCharter {
  /// Collective defence: an attack on one is an attack on all.
  defensive,

  /// Economic community: members share a trade bonus and never sanction each
  /// other.
  economic,

  /// Great-power sphere: a leader projects influence over client states.
  sphere,
}

/// A named multi-nation alliance.
class Bloc {
  const Bloc({
    required this.id,
    required this.nameEn,
    required this.nameFa,
    required this.leaderId,
    required this.members,
    required this.charter,
    required this.foundedDay,
    this.colorArgb = 0xFF4C7FA6,
  });

  final String id;
  final String nameEn;
  final String nameFa;

  /// The nation that founded or currently chairs the bloc.
  final String leaderId;

  /// Every member, including the leader.
  final List<String> members;
  final BlocCharter charter;
  final int foundedDay;
  final int colorArgb;

  bool contains(String id) => members.contains(id);

  bool get isDefensive => charter == BlocCharter.defensive;
  bool get isEconomic => charter == BlocCharter.economic;

  Bloc copyWith({
    String? leaderId,
    List<String>? members,
    BlocCharter? charter,
  }) => Bloc(
    id: id,
    nameEn: nameEn,
    nameFa: nameFa,
    leaderId: leaderId ?? this.leaderId,
    members: members ?? this.members,
    charter: charter ?? this.charter,
    foundedDay: foundedDay,
    colorArgb: colorArgb,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameFa': nameFa,
    'leaderId': leaderId,
    'members': members,
    'charter': charter.name,
    'foundedDay': foundedDay,
    'color': colorArgb,
  };

  static Bloc fromJson(Map<String, dynamic> json) => Bloc(
    id: json['id'] as String,
    nameEn: json['nameEn']?.toString() ?? 'Bloc',
    nameFa: json['nameFa']?.toString() ?? 'بلوک',
    leaderId: json['leaderId'] as String,
    members:
        (json['members'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    charter: BlocCharter.values.firstWhere(
      (c) => c.name == json['charter'],
      orElse: () => BlocCharter.defensive,
    ),
    foundedDay: (json['foundedDay'] as num?)?.toInt() ?? 0,
    colorArgb: (json['color'] as num?)?.toInt() ?? 0xFF4C7FA6,
  );
}

// ------------------------------------------------------------------ sanctions

/// How hard a sanction bites.
enum SanctionTier { targeted, sectoral, embargo }

/// A unilateral economic sanction imposed by [imposerId] on [targetId].
class Sanction {
  const Sanction({
    required this.id,
    required this.imposerId,
    required this.targetId,
    required this.tier,
    required this.imposedDay,
    this.reasonKey,
  });

  final String id;
  final String imposerId;
  final String targetId;
  final SanctionTier tier;
  final int imposedDay;

  /// Localization key explaining the sanction (shown in the UI).
  final String? reasonKey;

  /// Fraction of the target's resource/trade income removed by this sanction,
  /// before scaling by the imposer's economic weight.
  double get severity => switch (tier) {
    SanctionTier.targeted => 0.04,
    SanctionTier.sectoral => 0.09,
    SanctionTier.embargo => 0.16,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'imposerId': imposerId,
    'targetId': targetId,
    'tier': tier.name,
    'imposedDay': imposedDay,
    'reasonKey': reasonKey,
  };

  static Sanction fromJson(Map<String, dynamic> json) => Sanction(
    id: json['id'] as String,
    imposerId: json['imposerId'] as String,
    targetId: json['targetId'] as String,
    tier: SanctionTier.values.firstWhere(
      (t) => t.name == json['tier'],
      orElse: () => SanctionTier.targeted,
    ),
    imposedDay: (json['imposedDay'] as num?)?.toInt() ?? 0,
    reasonKey: json['reasonKey']?.toString(),
  );
}

// ---------------------------------------------------------------- peace talks

/// What a peace settlement asks of the loser.
enum PeaceTerm {
  /// Status quo ante — everyone goes home.
  whitePeace,

  /// Loser pays a lump sum.
  reparations,

  /// Loser cedes its home region to the winner.
  cession,

  /// Loser withdraws from every bloc and signs a long non-aggression pact.
  neutralisation,
}

/// A peace offer awaiting the other side's answer. AI nations answer at the
/// next pulse; the player answers through the diplomacy screen.
class PeaceOffer {
  const PeaceOffer({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.warId,
    required this.term,
    required this.offeredDay,
    this.amount = 0,
  });

  final String id;
  final String fromId;
  final String toId;
  final String warId;
  final PeaceTerm term;
  final int offeredDay;

  /// Reparation amount in credits (only for [PeaceTerm.reparations]).
  final double amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromId': fromId,
    'toId': toId,
    'warId': warId,
    'term': term.name,
    'offeredDay': offeredDay,
    'amount': amount,
  };

  static PeaceOffer fromJson(Map<String, dynamic> json) => PeaceOffer(
    id: json['id'] as String,
    fromId: json['fromId'] as String,
    toId: json['toId'] as String,
    warId: json['warId'] as String,
    term: PeaceTerm.values.firstWhere(
      (t) => t.name == json['term'],
      orElse: () => PeaceTerm.whitePeace,
    ),
    offeredDay: (json['offeredDay'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
  );
}

// ---------------------------------------------------------------- AI agendas

/// The long-term goal an AI nation is currently pursuing. Agendas are chosen
/// from the nation's doctrine and the state of the world, and they re-evaluate
/// every few pulses so the world keeps moving.
enum AiAgenda {
  /// Grow industry and infrastructure; avoid wars.
  economicMiracle,

  /// Build a defensive bloc and fortify.
  fortressState,

  /// Gather clients into a sphere of influence under its own leadership.
  hegemony,

  /// Prepare a war against a specific rival.
  revanchism,

  /// Isolate a rival through sanctions and alliances.
  containment,

  /// Keep every option open; trade with everyone, commit to no one.
  balancing,
}

/// Per-nation strategic memory that is persisted with the save.
class AiMind {
  const AiMind({
    required this.countryId,
    required this.agenda,
    required this.sinceDay,
    this.rivalId,
    this.patronId,
    this.warWeariness = 0,
    this.grudges = const {},
  });

  final String countryId;
  final AiAgenda agenda;
  final int sinceDay;

  /// Nation this one defines itself against (for containment / revanchism).
  final String? rivalId;

  /// Great power this one orbits (for client states).
  final String? patronId;

  /// 0..100; rises during war, decays in peace. High weariness makes peace
  /// acceptable and new wars unattractive.
  final double warWeariness;

  /// countryId -> grudge score (sanctions imposed, treaties broken, attacks).
  final Map<String, double> grudges;

  AiMind copyWith({
    AiAgenda? agenda,
    int? sinceDay,
    String? rivalId,
    bool clearRival = false,
    String? patronId,
    bool clearPatron = false,
    double? warWeariness,
    Map<String, double>? grudges,
  }) => AiMind(
    countryId: countryId,
    agenda: agenda ?? this.agenda,
    sinceDay: sinceDay ?? this.sinceDay,
    rivalId: clearRival ? null : (rivalId ?? this.rivalId),
    patronId: clearPatron ? null : (patronId ?? this.patronId),
    warWeariness: warWeariness ?? this.warWeariness,
    grudges: grudges ?? this.grudges,
  );

  double grudgeAgainst(String id) => grudges[id] ?? 0;

  Map<String, dynamic> toJson() => {
    'countryId': countryId,
    'agenda': agenda.name,
    'sinceDay': sinceDay,
    'rivalId': rivalId,
    'patronId': patronId,
    'warWeariness': warWeariness,
    'grudges': grudges,
  };

  static AiMind fromJson(Map<String, dynamic> json) => AiMind(
    countryId: json['countryId'] as String,
    agenda: AiAgenda.values.firstWhere(
      (a) => a.name == json['agenda'],
      orElse: () => AiAgenda.balancing,
    ),
    sinceDay: (json['sinceDay'] as num?)?.toInt() ?? 0,
    rivalId: json['rivalId']?.toString(),
    patronId: json['patronId']?.toString(),
    warWeariness: (json['warWeariness'] as num?)?.toDouble() ?? 0,
    grudges: json['grudges'] == null
        ? const {}
        : Map<String, double>.from(
            (json['grudges'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ),
          ),
  );
}

// ------------------------------------------------------------- world politics

/// Everything the living world adds on top of bilateral treaties.
class WorldPolitics {
  const WorldPolitics({
    this.blocs = const [],
    this.sanctions = const [],
    this.peaceOffers = const [],
    this.minds = const {},
    this.pendingInvites = const [],
    this.tension = 20,
  });

  final List<Bloc> blocs;
  final List<Sanction> sanctions;
  final List<PeaceOffer> peaceOffers;

  /// countryId -> strategic memory (AI nations only).
  final Map<String, AiMind> minds;

  /// Bloc invitations addressed to the player: blocId values.
  final List<BlocInvite> pendingInvites;

  /// Global tension index 0..100 — the "doomsday clock" of the campaign.
  final double tension;

  Bloc? blocOf(String countryId) {
    for (final b in blocs) {
      if (b.contains(countryId)) return b;
    }
    return null;
  }

  Bloc? blocById(String id) {
    for (final b in blocs) {
      if (b.id == id) return b;
    }
    return null;
  }

  bool sameBloc(String a, String b) {
    final ba = blocOf(a);
    return ba != null && ba.contains(b);
  }

  List<Sanction> sanctionsOn(String targetId) =>
      sanctions.where((s) => s.targetId == targetId).toList(growable: false);

  List<Sanction> sanctionsBy(String imposerId) =>
      sanctions.where((s) => s.imposerId == imposerId).toList(growable: false);

  Sanction? sanctionBetween(String imposerId, String targetId) {
    for (final s in sanctions) {
      if (s.imposerId == imposerId && s.targetId == targetId) return s;
    }
    return null;
  }

  List<PeaceOffer> offersTo(String id) =>
      peaceOffers.where((o) => o.toId == id).toList(growable: false);

  AiMind? mindOf(String id) => minds[id];

  WorldPolitics copyWith({
    List<Bloc>? blocs,
    List<Sanction>? sanctions,
    List<PeaceOffer>? peaceOffers,
    Map<String, AiMind>? minds,
    List<BlocInvite>? pendingInvites,
    double? tension,
  }) => WorldPolitics(
    blocs: blocs ?? this.blocs,
    sanctions: sanctions ?? this.sanctions,
    peaceOffers: peaceOffers ?? this.peaceOffers,
    minds: minds ?? this.minds,
    pendingInvites: pendingInvites ?? this.pendingInvites,
    tension: tension ?? this.tension,
  );

  Map<String, dynamic> toJson() => {
    'blocs': blocs.map((b) => b.toJson()).toList(),
    'sanctions': sanctions.map((s) => s.toJson()).toList(),
    'peaceOffers': peaceOffers.map((p) => p.toJson()).toList(),
    'minds': minds.map((k, v) => MapEntry(k, v.toJson())),
    'pendingInvites': pendingInvites.map((i) => i.toJson()).toList(),
    'tension': tension,
  };

  static WorldPolitics fromJson(
    Map<String, dynamic>? json, {
    required bool Function(String) knownCountry,
  }) {
    if (json == null) return const WorldPolitics();
    final blocs = <Bloc>[];
    for (final raw in (json['blocs'] as List?) ?? const []) {
      if (raw is! Map) continue;
      try {
        final b = Bloc.fromJson(Map<String, dynamic>.from(raw));
        final members = b.members.where(knownCountry).toList();
        if (members.length < 2 || !knownCountry(b.leaderId)) continue;
        blocs.add(b.copyWith(members: members));
      } catch (_) {
        // skip
      }
    }
    final sanctions = <Sanction>[];
    for (final raw in (json['sanctions'] as List?) ?? const []) {
      if (raw is! Map) continue;
      try {
        final s = Sanction.fromJson(Map<String, dynamic>.from(raw));
        if (knownCountry(s.imposerId) && knownCountry(s.targetId)) {
          sanctions.add(s);
        }
      } catch (_) {
        // skip
      }
    }
    final offers = <PeaceOffer>[];
    for (final raw in (json['peaceOffers'] as List?) ?? const []) {
      if (raw is! Map) continue;
      try {
        final o = PeaceOffer.fromJson(Map<String, dynamic>.from(raw));
        if (knownCountry(o.fromId) && knownCountry(o.toId)) offers.add(o);
      } catch (_) {
        // skip
      }
    }
    final minds = <String, AiMind>{};
    final rawMinds = json['minds'];
    if (rawMinds is Map) {
      rawMinds.forEach((k, v) {
        if (v is! Map) return;
        try {
          final m = AiMind.fromJson(Map<String, dynamic>.from(v));
          if (knownCountry(m.countryId)) minds[m.countryId] = m;
        } catch (_) {
          // skip
        }
      });
    }
    final invites = <BlocInvite>[];
    for (final raw in (json['pendingInvites'] as List?) ?? const []) {
      if (raw is! Map) continue;
      try {
        invites.add(BlocInvite.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {
        // skip
      }
    }
    return WorldPolitics(
      blocs: blocs,
      sanctions: sanctions,
      peaceOffers: offers,
      minds: minds,
      pendingInvites: invites,
      tension: ((json['tension'] as num?)?.toDouble() ?? 20).clamp(0, 100),
    );
  }
}

/// An invitation for the player to join a bloc.
class BlocInvite {
  const BlocInvite({
    required this.blocId,
    required this.fromId,
    required this.day,
  });

  final String blocId;
  final String fromId;
  final int day;

  Map<String, dynamic> toJson() => {
    'blocId': blocId,
    'fromId': fromId,
    'day': day,
  };

  static BlocInvite fromJson(Map<String, dynamic> json) => BlocInvite(
    blocId: json['blocId'] as String,
    fromId: json['fromId'] as String,
    day: (json['day'] as num?)?.toInt() ?? 0,
  );
}
