/// A rolling sample series used by the economy / national-power charts.
///
/// One entry is recorded every [Balance.historySampleDays] in-game days for
/// every nation, so the charts always have a consistent, cheap time axis.
class HistorySeries {
  HistorySeries({
    Map<String, List<double>>? economy,
    Map<String, List<double>>? power,
    Map<String, List<double>>? industry,
    Map<String, List<double>>? treasury,
    Map<String, List<double>>? stability,
    Map<String, List<double>>? army,
    List<int>? days,
  }) : nationalEconomy = economy ?? <String, List<double>>{},
       nationalPower = power ?? <String, List<double>>{},
       nationalIndustry = industry ?? <String, List<double>>{},
       nationalTreasury = treasury ?? <String, List<double>>{},
       nationalStability = stability ?? <String, List<double>>{},
       nationalArmy = army ?? <String, List<double>>{},
       sampleDays = days ?? <int>[];

  /// Per-nation sampled series, keyed by country id.
  final Map<String, List<double>> nationalEconomy;
  final Map<String, List<double>> nationalPower;
  final Map<String, List<double>> nationalIndustry;
  final Map<String, List<double>> nationalTreasury;
  final Map<String, List<double>> nationalStability;
  final Map<String, List<double>> nationalArmy;

  /// In-game day of every global sample (shared time axis).
  final List<int> sampleDays;

  static const int _limit = 120;

  Map<String, List<double>> _map(HistoryMetric metric) => switch (metric) {
    HistoryMetric.economy => nationalEconomy,
    HistoryMetric.power => nationalPower,
    HistoryMetric.industry => nationalIndustry,
    HistoryMetric.treasury => nationalTreasury,
    HistoryMetric.stability => nationalStability,
    HistoryMetric.army => nationalArmy,
  };

  List<double> seriesOf(String id, HistoryMetric metric) =>
      _map(metric)[id] ?? const <double>[];

  /// The last sampled day, or -1 when nothing has been recorded.
  int get lastDay => sampleDays.isEmpty ? -1 : sampleDays.last;

  void markDay(int day) {
    sampleDays.add(day);
    if (sampleDays.length > _limit) sampleDays.removeAt(0);
  }

  void record(
    String id, {
    required double economy,
    required double power,
    required double industry,
    double? treasury,
    double? stability,
    double? army,
  }) {
    _push(nationalEconomy, id, economy);
    _push(nationalPower, id, power);
    _push(nationalIndustry, id, industry);
    if (treasury != null) _push(nationalTreasury, id, treasury);
    if (stability != null) _push(nationalStability, id, stability);
    if (army != null) _push(nationalArmy, id, army);
  }

  void _push(Map<String, List<double>> map, String id, double value) {
    final list = map.putIfAbsent(id, () => <double>[]);
    list.add(value);
    if (list.length > _limit) list.removeAt(0);
  }

  /// The raw series, or an empty list when there is not enough data yet.
  List<double> raw(String id, HistoryMetric metric) {
    final list = seriesOf(id, metric);
    return list.length < 2 ? const [] : list;
  }

  /// Change between the first and last sample, or 0 when unavailable.
  double delta(String id, HistoryMetric metric) {
    final list = raw(id, metric);
    if (list.isEmpty) return 0;
    return list.last - list.first;
  }

  /// The series rescaled into 0..1 for plotting.
  List<double> normalised(String id, HistoryMetric metric) {
    final list = raw(id, metric);
    if (list.isEmpty) return const [];
    var lo = list.first;
    var hi = list.first;
    for (final v in list) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = hi - lo;
    if (span.abs() < 1e-9) return List<double>.filled(list.length, 0.5);
    return [for (final v in list) ((v - lo) / span).clamp(0.0, 1.0)];
  }

  Map<String, dynamic> toJson() => {
    'economy': nationalEconomy,
    'power': nationalPower,
    'industry': nationalIndustry,
    'treasury': nationalTreasury,
    'stability': nationalStability,
    'army': nationalArmy,
    'days': sampleDays,
  };

  static HistorySeries fromJson(Map<String, dynamic> json) {
    Map<String, List<double>> read(String key) {
      final out = <String, List<double>>{};
      final raw = json[key];
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is List) {
            out[k.toString()] = [
              for (final e in v)
                if (e is num) e.toDouble(),
            ];
          }
        });
      }
      return out;
    }

    final rawDays = json['days'];
    return HistorySeries(
      economy: read('economy'),
      power: read('power'),
      industry: read('industry'),
      treasury: read('treasury'),
      stability: read('stability'),
      army: read('army'),
      days: rawDays is List
          ? [
              for (final d in rawDays)
                if (d is num) d.toInt(),
            ]
          : null,
    );
  }
}

/// Public metric selector for the charts.
enum HistoryMetric { economy, power, industry, treasury, stability, army }
