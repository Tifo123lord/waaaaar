import '../core/balance.dart';

/// One in-progress equipment production run.
///
/// A queue entry produces [quantity] units of one [EquipmentType]; progress is
/// driven by the nation's available military production points each day, so a
/// nation with more military factories finishes the same order faster.
class ProductionOrder {
  const ProductionOrder({
    required this.type,
    required this.startedDay,
    required this.daysTotal,
    required this.quantity,
    this.progressDays = 0,
    this.completed = 0,
  });

  final EquipmentType type;
  final int startedDay;

  /// Total production days for the whole order at full output.
  final int daysTotal;

  /// Units requested.
  final int quantity;

  /// Effective production-days accumulated so far.
  final double progressDays;

  /// Units already delivered from this order.
  final int completed;

  double get fraction =>
      daysTotal <= 0 ? 1 : (progressDays / daysTotal).clamp(0.0, 1.0);

  int get daysRemaining =>
      (daysTotal - progressDays).ceil().clamp(0, daysTotal);

  int get unitsRemaining => (quantity - completed).clamp(0, quantity);

  /// Whether the whole run has been delivered.
  bool get isDone => completed >= quantity || progressDays >= daysTotal;

  /// Adds [days] of production time; deliveries are computed by the caller from
  /// [fraction] so the model stays free of economy rules.
  ProductionOrder advance(double days) => ProductionOrder(
    type: type,
    startedDay: startedDay,
    daysTotal: daysTotal,
    quantity: quantity,
    progressDays: progressDays + days,
    completed: completed,
  );

  ProductionOrder deliver(int units) => ProductionOrder(
    type: type,
    startedDay: startedDay,
    daysTotal: daysTotal,
    quantity: quantity,
    progressDays: progressDays,
    completed: (completed + units).clamp(0, quantity),
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'startedDay': startedDay,
    'daysTotal': daysTotal,
    'quantity': quantity,
    'progressDays': progressDays,
    'completed': completed,
  };

  static ProductionOrder fromJson(Map<String, dynamic> json) {
    final type = EquipmentType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => EquipmentType.smallArms,
    );
    return ProductionOrder(
      type: type,
      startedDay: (json['startedDay'] as num?)?.toInt() ?? 0,
      daysTotal: (json['daysTotal'] as num?)?.toInt() ?? 1,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      progressDays: (json['progressDays'] as num?)?.toDouble() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convenience constructor used by the simulation when a run is queued.
  static ProductionOrder queue(
    EquipmentType type, {
    required int quantity,
    required int day,
  }) {
    final spec = Balance.equipment[type]!;
    return ProductionOrder(
      type: type,
      startedDay: day,
      daysTotal: spec.days * quantity,
      quantity: quantity,
    );
  }
}
