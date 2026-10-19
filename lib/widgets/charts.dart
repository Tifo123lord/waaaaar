import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// One plotted series for [TrendChart].
class ChartSeries {
  const ChartSeries({
    required this.values,
    required this.color,
    this.label,
    this.fill = true,
    this.dashed = false,
  });

  final List<double> values;
  final Color color;
  final String? label;
  final bool fill;
  final bool dashed;
}

/// A lightweight line chart with a filled area, grid and min/max guides.
///
/// Every series is scaled into a shared value range so two nations can be
/// compared on the same axis.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.series,
    this.height = 120,
    this.formatValue,
    this.emptyLabel = '—',
  });

  final List<ChartSeries> series;
  final double height;
  final String Function(double value)? formatValue;
  final String emptyLabel;

  bool get _hasData => series.any((s) => s.values.length >= 2);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!_hasData) {
      return SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.show_chart, size: 22, color: WD.textMuted),
              const SizedBox(height: 6),
              Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: text.labelSmall,
              ),
            ],
          ),
        ),
      );
    }
    var lo = double.infinity;
    var hi = -double.infinity;
    for (final s in series) {
      for (final v in s.values) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    final fmt = formatValue ?? (v) => v.toStringAsFixed(0);
    final labels = series.where((s) => s.label != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _TrendPainter(series: series, lo: lo, hi: hi),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmt(hi), style: text.labelSmall?.copyWith(fontSize: 9)),
                  Text(
                    fmt((hi + lo) / 2),
                    style: text.labelSmall?.copyWith(fontSize: 9),
                  ),
                  Text(fmt(lo), style: text.labelSmall?.copyWith(fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
        if (labels.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final s in labels)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 3, color: s.color),
                    const SizedBox(width: 5),
                    Text(
                      s.label!,
                      style: text.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.series, required this.lo, required this.hi});

  final List<ChartSeries> series;
  final double lo;
  final double hi;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = WD.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    for (final s in series) {
      if (s.values.length < 2) continue;
      final n = s.values.length;
      final pts = <Offset>[
        for (var i = 0; i < n; i++)
          Offset(
            size.width * i / (n - 1),
            size.height -
                ((s.values[i] - lo) / span).clamp(0.0, 1.0) *
                    (size.height - 4) -
                2,
          ),
      ];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (s.fill) {
        final area = Path.from(path)
          ..lineTo(pts.last.dx, size.height)
          ..lineTo(pts.first.dx, size.height)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withValues(alpha: 0.32),
                s.color.withValues(alpha: 0.02),
              ],
            ).createShader(Offset.zero & size),
        );
      }
      final stroke = Paint()
        ..color = s.color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      if (s.dashed) {
        for (final metric in path.computeMetrics()) {
          var d = 0.0;
          while (d < metric.length) {
            canvas.drawPath(metric.extractPath(d, d + 5), stroke);
            d += 9;
          }
        }
      } else {
        canvas.drawPath(path, stroke);
      }
      canvas.drawCircle(pts.last, 3, Paint()..color = s.color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.series != series || old.lo != lo || old.hi != hi;
}

/// A horizontal labelled bar, used for breakdowns and rankings.
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.color = WD.accent,
    this.leading,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;
  final Widget? leading;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WD.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: highlight
            ? BoxDecoration(
                color: WD.brass.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(WD.radiusSm),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 7)],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: highlight ? WD.brass : WD.textSecondary,
                      fontWeight: highlight ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: text.titleSmall?.copyWith(
                    fontSize: 12,
                    color: highlight ? WD.brass : WD.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  Container(height: 4, color: WD.surface3),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: Container(height: 4, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A two-sided bar for signed values (relations -100..100).
class SignedBar extends StatelessWidget {
  const SignedBar({
    super.key,
    required this.value,
    this.max = 100,
    this.height = 6,
  });

  final double value;
  final double max;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = (value / max).clamp(-1.0, 1.0);
    final color = f >= 0 ? WD.positive : WD.danger;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final half = box.maxWidth / 2;
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: WD.surface3,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              PositionedDirectional(
                start: f >= 0 ? half : half + f * half,
                width: f.abs() * half,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              PositionedDirectional(
                start: half - 0.5,
                width: 1,
                top: 0,
                bottom: 0,
                child: Container(color: WD.textMuted),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A compact radial gauge for 0..1 values.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.fraction,
    required this.label,
    required this.value,
    this.color = WD.accent,
    this.size = 74,
  });

  final double fraction;
  final String label;
  final String value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(fraction.clamp(0.0, 1.0), color),
            child: Center(
              child: Text(
                value,
                style: text.titleSmall?.copyWith(
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(5);
    final bg = Paint()
      ..color = WD.surface3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawArc(r, math.pi * 0.75, math.pi * 1.5, false, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, math.pi * 0.75, math.pi * 1.5 * fraction, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Radar (spider) chart comparing up to two profiles across N axes (0..1).
class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.axes,
    required this.primary,
    this.secondary,
    this.primaryColor = WD.brass,
    this.secondaryColor = WD.info,
    this.size = 220,
  });

  final List<String> axes;
  final List<double> primary;
  final List<double>? secondary;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          axes: axes,
          primary: primary,
          secondary: secondary,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          labelStyle:
              Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                color: WD.textSecondary,
              ) ??
              const TextStyle(fontSize: 9.5, color: WD.textSecondary),
          direction: Directionality.of(context),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
    required this.labelStyle,
    required this.direction,
  });

  final List<String> axes;
  final List<double> primary;
  final List<double>? secondary;
  final Color primaryColor;
  final Color secondaryColor;
  final TextStyle labelStyle;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) return;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 26;
    Offset at(int i, double f) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      return center + Offset(math.cos(a), math.sin(a)) * radius * f;
    }

    final grid = Paint()
      ..color = WD.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final o = at(i, ring / 4);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      p.close();
      canvas.drawPath(p, grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, at(i, 1), grid);
      final tp = TextPainter(
        text: TextSpan(text: axes[i], style: labelStyle),
        textDirection: direction,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 80);
      final o = at(i, 1.16);
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    void shape(List<double> values, Color color) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final v = i < values.length ? values[i].clamp(0.04, 1.0) : 0.04;
        final o = at(i, v);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      p.close();
      canvas.drawPath(p, Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    if (secondary != null) shape(secondary!, secondaryColor);
    shape(primary, primaryColor);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}
