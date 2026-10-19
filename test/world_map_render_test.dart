import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/world_geometry.dart';
import 'package:flutter_app/features/world_map/world_map_view.dart';

/// Renders the real map painters off-screen into `build/map_preview_*.png`.
///
/// This is a visual smoke test: it proves the painted backdrop decodes, that
/// the nation overlays land on the right coastlines for several viewport
/// shapes, and that the two painters compose correctly.
void main() {
  late ui.Image image;

  Future<void> shoot(
    String name, {
    required Size viewport,
    required MapScaleMode mode,
    required String? selectedId,
    required List<NationGeometry> geometry,
    required MapFit fit,
    bool labels = true,
  }) async {
    final base = WorldMapPainter(
      image: image,
      fit: fit,
      geometry: geometry,
      state: null,
      selectedId: selectedId,
      layer: MapLayer.political,
    );
    final overlay = WorldMapOverlayPainter(
      fit: fit,
      geometry: geometry,
      state: null,
      selectedId: selectedId,
      labels: labels
          ? const {
              'us': 'USA',
              'cn': 'CHN',
              'ru': 'RUS',
              'ir': 'IRN',
              'uk': 'GBR',
              'fr': 'FRA',
              'de': 'DEU',
              'in': 'IND',
              'jp': 'JPN',
              'br': 'BRA',
            }
          : const {},
      persian: false,
      pulse: 0.4,
    );

    final size = fit.canvasSize;
    final recorder = ui.PictureRecorder();
    final ctx = Canvas(recorder, Offset.zero & size);
    base.paint(ctx, size);
    overlay.paint(ctx, size);
    final picture = recorder.endRecording();
    final out = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File(
      'build/map_preview_$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('world map renders and overlays align', (tester) async {
    // Image decoding and Picture.toImage are real async engine work, so they
    // must run outside the fake-async zone the tester installs by default.
    await tester.runAsync(() async {
      final data = await rootBundle.load(kWorldMapAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      image = frame.image;

      expect(image.width, 2048);
      expect(image.height, 1024);

      // --- cover mode with a tall phone-shaped viewport --------------------
      const phone = Size(400, 800);
      final phoneFit = MapFit(phone);
      // The canvas must cover the viewport on both axes.
      expect(phoneFit.canvasSize.width, greaterThanOrEqualTo(phone.width));
      expect(phoneFit.canvasSize.height, greaterThanOrEqualTo(phone.height));
      // ...and must preserve the map's 2:1 aspect exactly.
      expect(
        phoneFit.canvasSize.width / phoneFit.canvasSize.height,
        closeTo(kWorldMapAspect, 1e-9),
      );

      final geometry = buildNationGeometry(phoneFit);
      expect(geometry.length, kPlayableShapes.length);
      for (final g in geometry) {
        expect(g.rings, isNotEmpty, reason: '${g.shape.id} has no rings');
        expect(
          g.fill.getBounds().isEmpty,
          isFalse,
          reason: '${g.shape.id} has empty bounds',
        );
        // Every nation must be inside the painted map rectangle.
        expect(
          phoneFit.rect.inflate(1).overlaps(g.fill.getBounds()),
          isTrue,
          reason: '${g.shape.id} is outside the map rect',
        );
      }

      // Hit-testing must find a nation at its own label anchor.
      for (final g in geometry) {
        final p = phoneFit.toPixel(g.shape.anchor.dx, g.shape.anchor.dy);
        final hits = geometry.where((o) => o.hit(p)).toList();
        expect(
          hits,
          isNotEmpty,
          reason: '${g.shape.id} anchor not hit-testable',
        );
        // The anchor must belong to this nation (or a nation that contains it).
        expect(
          hits.any((o) => o.shape.id == g.shape.id),
          isTrue,
          reason: '${g.shape.id} anchor resolved to the wrong nation',
        );
      }

      // Empty ocean must not select anything.
      expect(
        geometry.where((g) => g.hit(phoneFit.toPixel(-140, -40))),
        isEmpty,
      );

      // --- contain mode on a landscape viewport ---------------------------
      const wide = Size(1200, 600);
      final wideFit = MapFit(wide, mode: MapScaleMode.contain);
      expect(wideFit.canvasSize, wide);
      expect(
        wideFit.canvasSize.width / wideFit.canvasSize.height,
        closeTo(kWorldMapAspect, 1e-9),
      );
      expect(wideFit.rect.width, closeTo(1200, 1e-6));
      expect(wideFit.rect.height, closeTo(600, 1e-6));

      await shoot(
        'phone_cover',
        viewport: phone,
        mode: MapScaleMode.cover,
        selectedId: 'ir',
        geometry: geometry,
        fit: phoneFit,
      );

      await shoot(
        'world_contain',
        viewport: wide,
        mode: MapScaleMode.contain,
        selectedId: 'ir',
        geometry: buildNationGeometry(wideFit),
        fit: wideFit,
      );
    });
  });
}
