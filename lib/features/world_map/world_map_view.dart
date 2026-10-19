import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/country_data.dart';
import '../../data/world_geometry.dart';
import '../../models/country.dart';
import '../../models/game_state.dart';
import '../../models/region.dart';

/// Which information layer the map paints.
enum MapLayer { political, military }

/// How the 2:1 painted map is placed inside a viewport of arbitrary shape.
enum MapScaleMode {
  /// Scale so the map fills the viewport completely, cropping the overflow.
  /// Used by the interactive map, where the user pans to see the rest.
  cover,

  /// Fit the whole world inside the viewport, letterboxing the remainder.
  /// Used for decorative backdrops where seeing the entire world matters.
  contain,
}

/// Asset path of the painted world-map backdrop.
const String kWorldMapAsset = 'assets/map/world_map_base.png';

/// Natural aspect ratio of the painted backdrop (2:1 equirectangular).
const double kWorldMapAspect = WorldProjection.aspect;

final Map<String, Country> _countryById = {
  for (final c in CountryData.build()) c.id: c,
};

/// Places the 2:1 painted map inside an arbitrarily shaped viewport without
/// ever distorting it, and converts lon/lat degrees into canvas pixels.
class MapFit {
  const MapFit._(this.canvasSize, this.rect);

  /// Builds the layout for [viewport] under the requested [mode].
  ///
  /// In [MapScaleMode.cover] the canvas is the 2:1 rectangle that covers the
  /// viewport, so it is larger than the viewport on one axis and the user pans
  /// along that axis. In [MapScaleMode.contain] the canvas equals the viewport
  /// and the map is letterboxed inside it.
  factory MapFit(
    Size viewport, {
    MapScaleMode mode = MapScaleMode.cover,
    double aspect = kWorldMapAspect,
  }) {
    if (mode == MapScaleMode.contain) {
      var w = viewport.width;
      var h = w / aspect;
      if (h > viewport.height) {
        h = viewport.height;
        w = h * aspect;
      }
      return MapFit._(
        viewport,
        Rect.fromCenter(
          center: Offset(viewport.width / 2, viewport.height / 2),
          width: w,
          height: h,
        ),
      );
    }
    var w = viewport.height * aspect;
    var h = viewport.height;
    if (w < viewport.width) {
      w = viewport.width;
      h = viewport.width / aspect;
    }
    final canvas = Size(w, h);
    return MapFit._(canvas, Offset.zero & canvas);
  }

  /// Size of the painted child surface.
  final Size canvasSize;

  /// Where the 2:1 image sits inside [canvasSize].
  final Rect rect;

  Offset toPixel(double lon, double lat) {
    final u = WorldProjection.toUnit(lon, lat);
    return Offset(rect.left + u.dx * rect.width, rect.top + u.dy * rect.height);
  }
}

/// Prepared geometry for one nation on one canvas size.
class NationGeometry {
  NationGeometry(this.shape, this.fill, this.rings, this.bounds);

  final MapShape shape;

  /// Merged path used for filling, stroking and clipping.
  final Path fill;

  /// One path per ring, used for hit-testing so a tap on any landmass counts.
  final List<Path> rings;

  final Rect bounds;

  bool hit(Offset point) {
    if (!bounds.contains(point)) return false;
    for (final ring in rings) {
      if (ring.contains(point)) return true;
    }
    return false;
  }
}

/// Builds the canvas-space geometry for every playable nation.
///
/// Called once per canvas size by [WorldMapView], and reused directly by the
/// map render test so the shipped surface can be inspected off-screen.
List<NationGeometry> buildNationGeometry(MapFit fit) {
  final geo = <NationGeometry>[];
  for (final shape in kPlayableShapes) {
    final merged = Path();
    final rings = <Path>[];
    var bounds = Rect.zero;
    var first = true;
    for (final ring in shape.rings) {
      final pts = <Offset>[for (final p in ring) fit.toPixel(p[0], p[1])];
      if (pts.length < 3) continue;
      final path = Path()..addPolygon(pts, true);
      rings.add(path);
      merged.addPath(path, Offset.zero);
      final b = path.getBounds();
      bounds = first ? b : bounds.expandToInclude(b);
      first = false;
    }
    if (rings.isEmpty) continue;
    // A little tolerance so thin coastal nations stay comfortable to tap.
    geo.add(NationGeometry(shape, merged, rings, bounds.inflate(6)));
  }
  return geo;
}

/// How a nation should be tinted on the current layer.
class _NationStyle {
  const _NationStyle({
    this.tint,
    this.alpha = 0.0,
    this.halo = false,
    this.edge = 0.0,
    this.edgeWidth = 1.0,
  });

  /// Fill colour, or null for "no fill".
  final Color? tint;

  final double alpha;

  /// Whether to add a soft rim glow around the outline.
  final bool halo;

  /// Alpha of a crisp outline drawn on top of the fill.
  final double edge;

  final double edgeWidth;
}

/// The interactive world map.
///
/// A painted, geographically accurate world map is the base surface (see
/// `assets/map/world_map_base.png`); live game state is layered on top as
/// geographically exact nation overlays. Panning and zooming are handled by
/// [InteractiveViewer] and taps are resolved against the real outlines.
///
/// The surface is split into two painters — a static one (backdrop + tinting)
/// and an animated one (selection halo, battle markers, labels) — so the pulsing
/// animation never forces the expensive base layer to repaint.
class WorldMapView extends StatefulWidget {
  const WorldMapView({
    super.key,
    required this.selectedId,
    required this.onSelect,
    this.state,
    this.layer = MapLayer.political,
    this.showLabels = true,
    this.scaleMode = MapScaleMode.cover,
    this.interactive = true,
    this.onResetView,
  });

  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Null while choosing a nation for a new campaign.
  final GameState? state;

  final MapLayer layer;
  final bool showLabels;
  final MapScaleMode scaleMode;

  /// When false, gesturing and the on-map zoom buttons are disabled.
  final bool interactive;

  final VoidCallback? onResetView;

  @override
  State<WorldMapView> createState() => _WorldMapViewState();
}

class _WorldMapViewState extends State<WorldMapView>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _pulse;

  ui.Image? _image;
  bool _imageFailed = false;

  MapFit? _fit;
  List<NationGeometry> _geometry = const [];
  Size? _canvasSize;
  Size? _viewport;

  /// Whether the pulse is currently running, so we only start and stop the
  /// controller on transitions instead of leaving it ticking for nothing.
  bool _pulsing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
      value: 0.5,
    );
    _loadBackdrop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadBackdrop() async {
    try {
      final data = await rootBundle.load(kWorldMapAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _imageFailed = true);
    }
  }

  /// True when the painted backdrop could not be decoded.
  bool get backdropFailed => _imageFailed;

  void _syncLayout(Size viewport) {
    final fit = MapFit(viewport, mode: widget.scaleMode);
    final canvas = fit.canvasSize;
    if (canvas != _canvasSize) {
      _canvasSize = canvas;
      _geometry = buildNationGeometry(fit);
    }
    _fit = fit;
    if (_viewport != viewport) {
      _viewport = viewport;
      // Re-centre after the frame; setting the transform during build would
      // bounce back into the widget tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centreView();
      });
    }
  }

  /// Centres the (possibly larger) canvas inside the viewport, and keeps the
  /// map inside its own bounds so no empty space can be panned into view.
  void _centreView() {
    final canvas = _canvasSize;
    final viewport = _viewport;
    if (canvas == null || viewport == null) return;
    final scale = _controller.value.getMaxScaleOnAxis();
    final dx = (viewport.width - canvas.width * scale) / 2;
    final dy = (viewport.height - canvas.height * scale) / 2;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  String? _hitTest(Offset point) {
    // Reverse order so nations drawn last win overlapping taps.
    for (final g in _geometry.reversed) {
      if (g.hit(point)) return g.shape.id;
    }
    return null;
  }

  void _resetView() {
    _centreView();
    widget.onResetView?.call();
  }

  void _zoomBy(double factor) {
    final viewport = _viewport;
    if (viewport == null) return;
    final current = _controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 8.0);
    final ratio = next / current;
    if (ratio == 1.0) return;
    // Zoom about the centre of the viewport, then clamp back into bounds.
    final centre = Offset(viewport.width / 2, viewport.height / 2);
    final zoomed = Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1)
      ..multiply(_controller.value);
    _controller.value = _clampToBounds(zoomed, next);
  }

  /// Keeps the scaled canvas covering the viewport after a programmatic zoom.
  Matrix4 _clampToBounds(Matrix4 value, double scale) {
    final canvas = _canvasSize;
    final viewport = _viewport;
    if (canvas == null || viewport == null) return value;
    final scaledW = canvas.width * scale;
    final scaledH = canvas.height * scale;
    final minX = math.min(0.0, viewport.width - scaledW);
    final minY = math.min(0.0, viewport.height - scaledH);
    final tx = value.storage[12].clamp(minX, 0.0);
    final ty = value.storage[13].clamp(minY, 0.0);
    value.storage[12] = tx;
    value.storage[13] = ty;
    return value;
  }

  Map<String, String> _labels() {
    final persian = AppStrings.of(context).isPersian;
    final live = widget.state?.countries;
    final out = <String, String>{};
    for (final shape in kPlayableShapes) {
      final country = live?[shape.id] ?? _countryById[shape.id];
      if (country == null) continue;
      out[shape.id] = persian ? country.shortFa : country.shortEn;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final hasBattle = widget.state?.battles.isNotEmpty ?? false;
    // Only animate when something on screen genuinely pulses.
    final animate = !reduceMotion && (hasBattle || widget.selectedId != null);

    // Keep the controller running only while it is actually being drawn.
    // A permanently repeating controller would repaint forever and would also
    // stop widget tests from ever settling.
    if (animate != _pulsing) {
      _pulsing = animate;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (animate) {
          _pulse.repeat(reverse: true);
        } else {
          _pulse.stop();
          _pulse.value = 0.5;
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _syncLayout(viewport);
        final fit = _fit!;
        final labels = widget.showLabels ? _labels() : const <String, String>{};

        final base = CustomPaint(
          painter: WorldMapPainter(
            image: _image,
            fit: fit,
            geometry: _geometry,
            state: widget.state,
            selectedId: widget.selectedId,
            layer: widget.layer,
          ),
        );

        Widget overlay(double pulse) => CustomPaint(
          painter: WorldMapOverlayPainter(
            fit: fit,
            geometry: _geometry,
            state: widget.state,
            selectedId: widget.selectedId,
            labels: labels,
            persian: l10n.isPersian,
            pulse: pulse,
          ),
        );

        final child = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final id = _hitTest(details.localPosition);
            if (id != null) widget.onSelect(id);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              base,
              if (animate)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => overlay(_pulse.value),
                )
              else
                overlay(0.5),
            ],
          ),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                // Even when gestures are disabled the InteractiveViewer is
                // still used, because it gives us the exact centring of the
                // (possibly oversized) canvas that cover mode requires.
                child: InteractiveViewer(
                  transformationController: _controller,
                  constrained: false,
                  panEnabled: widget.interactive,
                  scaleEnabled: widget.interactive,
                  minScale: 1.0,
                  maxScale: 8.0,
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox(
                    width: fit.canvasSize.width,
                    height: fit.canvasSize.height,
                    child: child,
                  ),
                ),
              ),
            ),
            if (widget.interactive)
              Positioned(
                right: 10,
                bottom: 10,
                child: Column(
                  children: [
                    _MapButton(
                      icon: Icons.add,
                      onTap: () => _zoomBy(1.4),
                      tooltip: l10n.t('map.zoomIn'),
                    ),
                    const SizedBox(height: 6),
                    _MapButton(
                      icon: Icons.remove,
                      onTap: () => _zoomBy(1 / 1.4),
                      tooltip: l10n.t('map.zoomOut'),
                    ),
                    const SizedBox(height: 6),
                    _MapButton(
                      icon: Icons.center_focus_strong_outlined,
                      onTap: _resetView,
                      tooltip: l10n.t('map.resetView'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: WD.surface2.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(WD.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(WD.radiusSm),
          child: Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WD.radiusSm),
              border: Border.all(color: WD.lineStrong),
            ),
            child: Icon(icon, size: 16, color: WD.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Static layer
// ---------------------------------------------------------------------------

/// Paints the painted backdrop plus the political / military tinting.
///
/// Repainted only when the image, the selection, the layer or the game state
/// changes — never on animation frames.
class WorldMapPainter extends CustomPainter {
  WorldMapPainter({
    required this.image,
    required this.fit,
    required this.geometry,
    required this.state,
    required this.selectedId,
    required this.layer,
  });

  final ui.Image? image;
  final MapFit fit;
  final List<NationGeometry> geometry;
  final GameState? state;
  final String? selectedId;
  final MapLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackdrop(canvas, size);
    _paintNationTints(canvas);
    _paintOccupation(canvas);
    _paintBorders(canvas);
  }

  /// Regions held by a foreign power: tinted in the occupier's colour and
  /// hatched, so conquest is visible on every layer.
  void _paintOccupation(Canvas canvas) {
    final current = state;
    if (current == null) return;
    final occupied = current.regions.values.where((r) => r.isOccupied);
    if (occupied.isEmpty) return;
    for (final r in occupied) {
      final region = WorldRegions.byId(r.id);
      if (region == null) continue;
      final path = Path();
      for (final ring in region.rings) {
        final pts = <Offset>[for (final p in ring) fit.toPixel(p[0], p[1])];
        if (pts.length >= 3) path.addPolygon(pts, true);
      }
      final byPlayer = r.controllerId == current.playerId;
      final lostByPlayer = r.ownerId == current.playerId;
      final ally = current.alliesOf(current.playerId).contains(r.controllerId);
      final color = byPlayer
          ? WD.brass
          : lostByPlayer || current.atWarWith(current.playerId, r.controllerId)
          ? WD.danger
          : ally
          ? WD.ally
          : WD.warning;
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.34));
      final bounds = path.getBounds();
      canvas.save();
      canvas.clipPath(path);
      final hatch = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 1.1;
      for (var x = bounds.left - bounds.height;
          x < bounds.right;
          x += 6) {
        canvas.drawLine(
          Offset(x, bounds.bottom),
          Offset(x + bounds.height, bounds.top),
          hatch,
        );
      }
      canvas.restore();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final img = image;
    final r = fit.rect;
    if (img == null) {
      // While the asset decodes, hold the ocean tone so there is no flash.
      canvas.drawRect(Offset.zero & size, Paint()..color = WD.mapVoid);
      return;
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      r,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _paintNationTints(Canvas canvas) {
    for (final g in geometry) {
      final style = _styleFor(g.shape.id);
      final tint = style.tint;
      if (tint == null || style.alpha <= 0.001) continue;

      if (style.halo) {
        // Rim glow outside the real outline. Stacking a few strokes of
        // decreasing alpha gives the feathered look without a blur pass.
        canvas.drawPath(
          g.fill,
          Paint()
            ..color = tint.withValues(alpha: style.alpha * 0.13)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11,
        );
        canvas.drawPath(
          g.fill,
          Paint()
            ..color = tint.withValues(alpha: style.alpha * 0.24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
        canvas.drawPath(
          g.fill,
          Paint()
            ..color = tint.withValues(alpha: style.alpha * 0.40)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }

      canvas.drawPath(
        g.fill,
        Paint()..color = tint.withValues(alpha: style.alpha),
      );

      if (style.edge > 0) {
        canvas.drawPath(
          g.fill,
          Paint()
            ..color = tint.withValues(alpha: style.edge)
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.edgeWidth,
        );
      }
    }
  }

  void _paintBorders(Canvas canvas) {
    final hairline = Paint()
      ..color = WD.mapBorder.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (final g in geometry) {
      canvas.drawPath(g.fill, hairline);
    }
  }

  _NationStyle _styleFor(String id) {
    final current = state;
    final isSelected = id == selectedId;

    // --- Nation-picking mode: the painted map carries the visuals and the
    // --- chosen nation is lit up.
    if (current == null) {
      if (isSelected) {
        return const _NationStyle(
          tint: WD.brass,
          alpha: 0.30,
          halo: true,
          edge: 0.85,
        );
      }
      return const _NationStyle(edge: 0.16);
    }

    final isPlayer = id == current.playerId;
    final atWar = current.atWarWith(current.playerId, id);
    final ally = current.alliesOf(current.playerId).contains(id);
    final occupied =
        layer == MapLayer.military &&
        current.regions.values.any((r) => r.ownerId == id && r.isOccupied);

    if (layer == MapLayer.military) {
      if (isPlayer) {
        return _NationStyle(
          tint: WD.brass,
          alpha: isSelected ? 0.40 : 0.28,
          halo: isSelected,
          edge: 0.34,
        );
      }
      if (occupied || atWar) {
        return _NationStyle(
          tint: WD.danger,
          alpha: isSelected ? 0.44 : (occupied ? 0.32 : 0.26),
          halo: isSelected,
          edge: 0.26,
        );
      }
      if (ally) {
        return _NationStyle(
          tint: WD.ally,
          alpha: isSelected ? 0.30 : 0.18,
          edge: 0.22,
        );
      }
      // Shade by relative army strength so the layer reads as military.
      final score = current.armyOf(id).combatScore;
      final strongest = _strongestArmy(current);
      final t = strongest <= 0 ? 0.0 : (score / strongest).clamp(0.0, 1.0);
      return _NationStyle(
        tint: WD.accent,
        alpha: (0.06 + t * 0.24) * (isSelected ? 1.5 : 1.0),
        halo: isSelected,
        edge: 0.18,
      );
    }

    // --- Political layer.
    if (isPlayer) {
      return _NationStyle(
        tint: WD.brass,
        alpha: isSelected ? 0.42 : 0.28,
        halo: true,
        edge: 0.40,
        edgeWidth: 1.4,
      );
    }
    if (atWar) {
      return _NationStyle(
        tint: WD.danger,
        alpha: isSelected ? 0.42 : 0.26,
        halo: isSelected,
        edge: 0.28,
      );
    }
    if (ally) {
      return _NationStyle(
        tint: WD.ally,
        alpha: isSelected ? 0.34 : 0.20,
        halo: isSelected,
        edge: 0.24,
      );
    }
    if (isSelected) {
      return const _NationStyle(
        tint: WD.brass,
        alpha: 0.26,
        halo: true,
        edge: 0.85,
      );
    }
    return const _NationStyle(edge: 0.18);
  }

  double _strongestArmy(GameState current) {
    var best = 0.0;
    for (final id in current.countries.keys) {
      final score = current.armyOf(id).combatScore;
      if (score > best) best = score;
    }
    return best;
  }

  @override
  bool shouldRepaint(covariant WorldMapPainter old) {
    return old.image != image ||
        old.fit.canvasSize != fit.canvasSize ||
        old.selectedId != selectedId ||
        old.layer != layer ||
        old.geometry != geometry ||
        !identical(old.state, state) ||
        old.state?.revision != state?.revision;
  }
}

// ---------------------------------------------------------------------------
// Animated layer
// ---------------------------------------------------------------------------

/// Paints the pulsing selection halo, active-battle markers and nation labels.
class WorldMapOverlayPainter extends CustomPainter {
  WorldMapOverlayPainter({
    required this.fit,
    required this.geometry,
    required this.state,
    required this.selectedId,
    required this.labels,
    required this.persian,
    required this.pulse,
  });

  final MapFit fit;
  final List<NationGeometry> geometry;
  final GameState? state;
  final String? selectedId;
  final Map<String, String> labels;
  final bool persian;
  final double pulse;

  String get _family => persian ? 'Vazirmatn' : 'Inter';

  @override
  void paint(Canvas canvas, Size size) {
    _paintSelection(canvas);
    _paintBattleMarkers(canvas);
    _paintLabels(canvas);
  }

  void _paintSelection(Canvas canvas) {
    final selected = selectedId;
    if (selected == null) return;
    for (final g in geometry) {
      if (g.shape.id != selected) continue;
      canvas.drawPath(
        g.fill,
        Paint()
          ..color = WD.brass.withValues(alpha: 0.10 + pulse * 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
      canvas.drawPath(
        g.fill,
        Paint()
          ..color = WD.brass.withValues(alpha: 0.22 + pulse * 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      canvas.drawPath(
        g.fill,
        Paint()
          ..color = WD.brass
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  void _paintBattleMarkers(Canvas canvas) {
    final current = state;
    if (current == null) return;
    for (final battle in current.battles) {
      final region = battle.defenderId;
      MapShape? shape;
      for (final g in geometry) {
        if (g.shape.id == region) shape = g.shape;
      }
      if (shape == null) continue;
      final anchor = fit.toPixel(shape.anchor.dx, shape.anchor.dy);
      canvas.drawCircle(
        anchor,
        10 + pulse * 8,
        Paint()
          ..color = WD.danger.withValues(alpha: 0.42 * (1 - pulse * 0.7))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      canvas.drawCircle(anchor, 3.8, Paint()..color = WD.danger);
      final cross = Paint()
        ..color = WD.danger
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(anchor.translate(-7, 0), anchor.translate(7, 0), cross);
      canvas.drawLine(anchor.translate(0, -7), anchor.translate(0, 7), cross);
    }
  }

  void _paintLabels(Canvas canvas) {
    for (final g in geometry) {
      final text = labels[g.shape.id];
      if (text == null) continue;
      final anchor = fit.toPixel(g.shape.anchor.dx, g.shape.anchor.dy);
      final isSelected = g.shape.id == selectedId;
      final style = TextStyle(
        fontFamily: _family,
        fontSize: isSelected ? 12.5 : 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: isSelected ? WD.brass : WD.textPrimary,
      );
      final direction = persian ? TextDirection.rtl : TextDirection.ltr;

      // A dark halo pass keeps the label readable over any terrain.
      final halo = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(
            color: const Color(0xCC000000),
            shadows: const [
              Shadow(color: Color(0xF2000000), blurRadius: 6),
              Shadow(color: Color(0xB3000000), blurRadius: 14),
            ],
          ),
        ),
        textDirection: direction,
      )..layout();
      halo.paint(canvas, anchor - Offset(halo.width / 2, halo.height / 2));

      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
      )..layout();
      painter.paint(
        canvas,
        anchor - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WorldMapOverlayPainter old) {
    return old.selectedId != selectedId ||
        old.persian != persian ||
        old.pulse != pulse ||
        old.geometry != geometry ||
        old.labels.length != labels.length ||
        !identical(old.state, state) ||
        old.state?.revision != state?.revision;
  }
}

/// A legend describing the current colour coding.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.layer, this.state});

  final MapLayer layer;
  final GameState? state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    final entries = <(Color, String)>[
      (WD.brass.withValues(alpha: 0.62), l10n.t('map.you')),
      if (layer == MapLayer.political)
        (WD.ally.withValues(alpha: 0.58), l10n.t('map.ally')),
      if (state != null) (WD.danger.withValues(alpha: 0.58), l10n.t('map.war')),
      if (layer == MapLayer.military)
        (WD.accent.withValues(alpha: 0.5), l10n.t('map.armyStrength')),
    ];

    return Wrap(
      spacing: 11,
      runSpacing: 6,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: WD.lineStrong, width: 0.8),
                ),
              ),
              const SizedBox(width: 5),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}
