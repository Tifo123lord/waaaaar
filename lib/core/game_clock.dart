import '../models/game_event.dart';

/// Convert between an absolute simulation day index and a calendar date.
///
/// Day 0 == 1 January [startYear]. Months are fixed at 30 days in the demo so
/// that monthly budget figures map onto daily ticks exactly.
class GameDate implements Comparable<GameDate> {
  const GameDate(this.totalDay);

  final int totalDay;

  static const int startYear = 2027;
  static const int daysPerMonth = 30;
  static const int monthsPerYear = 12;

  int get year => startYear + totalDay ~/ (daysPerMonth * monthsPerYear);
  int get month =>
      1 + (totalDay % (daysPerMonth * monthsPerYear)) ~/ daysPerMonth;
  int get day => 1 + totalDay % daysPerMonth;

  /// 1..360 within the fictional year.
  int get dayOfYear => totalDay % (daysPerMonth * monthsPerYear) + 1;

  GameDate addDays(int days) => GameDate(totalDay + days);

  @override
  int compareTo(GameDate other) => totalDay.compareTo(other.totalDay);

  @override
  bool operator ==(Object other) =>
      other is GameDate && other.totalDay == totalDay;

  @override
  int get hashCode => totalDay.hashCode;
}

/// The demo event factory. Every entry corresponds to a real state change.
class EventLog {
  EventLog(this._events);

  final List<GameEvent> _events;
  int _seq = 0;

  List<GameEvent> get entries => List.unmodifiable(_events);

  List<GameEvent> recent(int count) {
    final start = _events.length - count;
    if (start <= 0) return List.unmodifiable(_events);
    return List.unmodifiable(_events.sublist(start));
  }

  GameEvent add({
    required GameEventKind kind,
    required int day,
    required String titleKey,
    String? bodyKey,
    Map<String, String> params = const {},
    String? countryId,
    double? amount,
    int severity = 0,
    int limit = 120,
  }) {
    final event = GameEvent(
      id: 'ev${day}_${_seq++}',
      kind: kind,
      day: day,
      titleKey: titleKey,
      bodyKey: bodyKey,
      params: params,
      countryId: countryId,
      amount: amount,
      severity: severity,
    );
    _events.add(event);
    if (_events.length > limit) {
      _events.removeRange(0, _events.length - limit);
    }
    return event;
  }

  List<Map<String, dynamic>> toJson() =>
      _events.map((e) => e.toJson()).toList(growable: false);
}
