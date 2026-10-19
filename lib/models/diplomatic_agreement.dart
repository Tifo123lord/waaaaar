/// Bilateral treaty kinds.
///
/// * [nonAggression] — neither side may attack the other.
/// * [defencePact] — non-aggression **plus** an obligation to join a war in
///   which the partner is the defender.
/// * [alliance] — full alliance: mutual defence and shared blocs/wars.
/// * [trade] — reserved for trade deals.
/// * [sanction] — legacy; sanctions now live in `WorldPolitics.sanctions`.
enum AgreementType { nonAggression, defencePact, alliance, trade, sanction }

/// A bilateral treaty stored in the game state. Treaties persist across saves
/// and are consulted by the battle and AI engines.
class DiplomaticAgreement {
  const DiplomaticAgreement({
    required this.id,
    required this.type,
    required this.a,
    required this.b,
    required this.signedDay,
  });

  final String id;
  final AgreementType type;
  final String a;
  final String b;
  final int signedDay;

  bool involves(String countryId) => a == countryId || b == countryId;

  String other(String countryId) => a == countryId ? b : a;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'a': a,
    'b': b,
    'signedDay': signedDay,
  };

  static DiplomaticAgreement fromJson(Map<String, dynamic> json) {
    return DiplomaticAgreement(
      id: json['id'] as String,
      type: AgreementType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AgreementType.nonAggression,
      ),
      a: json['a'] as String,
      b: json['b'] as String,
      signedDay: (json['signedDay'] as num).toInt(),
    );
  }
}
