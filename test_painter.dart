import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';
import 'dart:ui' as ui;

void main() {
  test('PigioPainter does not crash', () {
    final painter = PigioPainter(
      mood: PigMood.normal,
      scarfColor: Colors.red,
    );
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(200, 200);
    
    painter.paint(canvas, size);
    expect(true, true);
  });
}
