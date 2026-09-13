import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class TextColorDetector {
  /// Analyzes pixels within [rect] of [image] to detect the foreground text ink color.
  static Color detectTextColor(img.Image image, Rect rect) {
    final left = rect.left.clamp(0, image.width - 1).toInt();
    final top = rect.top.clamp(0, image.height - 1).toInt();
    final right = rect.right.clamp(0, image.width).toInt();
    final bottom = rect.bottom.clamp(0, image.height).toInt();

    if (right <= left || bottom <= top) return Colors.black;

    final pixels = <img.Pixel>[];
    // Sample every 2nd pixel for speed
    for (int y = top; y < bottom; y += 2) {
      for (int x = left; x < right; x += 2) {
        pixels.add(image.getPixel(x, y));
      }
    }
    if (pixels.isEmpty) return Colors.black;

    // Calculate average luminance
    double totalLum = 0;
    for (final p in pixels) {
      totalLum += p.luminanceNormalized;
    }
    final avgLum = totalLum / pixels.length;

    final textPixels = <img.Pixel>[];
    if (avgLum > 0.45) {
      // Light background: text is darker pixels
      for (final p in pixels) {
        if (p.luminanceNormalized < avgLum - 0.12) {
          textPixels.add(p);
        }
      }
    } else {
      // Dark background: text is lighter pixels
      for (final p in pixels) {
        if (p.luminanceNormalized > avgLum + 0.12) {
          textPixels.add(p);
        }
      }
    }

    if (textPixels.isEmpty) {
      // Sort and pick top 25% contrast pixels
      pixels.sort((a, b) => a.luminanceNormalized.compareTo(b.luminanceNormalized));
      final count = math.max(1, (pixels.length * 0.25).toInt());
      if (avgLum > 0.45) {
        textPixels.addAll(pixels.take(count));
      } else {
        textPixels.addAll(pixels.reversed.take(count));
      }
    }

    double rSum = 0, gSum = 0, bSum = 0;
    for (final p in textPixels) {
      rSum += p.r;
      gSum += p.g;
      bSum += p.b;
    }
    final n = textPixels.length;
    final r = (rSum / n).round().clamp(0, 255);
    final g = (gSum / n).round().clamp(0, 255);
    final b = (bSum / n).round().clamp(0, 255);

    return Color.fromARGB(255, r, g, b);
  }

  /// Maps font name string to Flutter font family and weight.
  static ({String? fontFamily, FontWeight fontWeight, FontStyle fontStyle}) detectFontProperties(
    String? fontName, {
    bool isBold = false,
    bool isItalic = false,
  }) {
    if (fontName == null || fontName.isEmpty) {
      return (
        fontFamily: null,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      );
    }

    final lower = fontName.toLowerCase();
    String? family;
    if (lower.contains('courier') || lower.contains('mono') || lower.contains('consolas')) {
      family = 'monospace';
    } else if (lower.contains('times') || lower.contains('serif') || lower.contains('georgia')) {
      family = 'serif';
    } else if (lower.contains('helvetica') || lower.contains('arial') || lower.contains('sans') || lower.contains('roboto')) {
      family = 'sans-serif';
    }

    final bold = isBold || lower.contains('bold') || lower.contains('black') || lower.contains('heavy');
    final italic = isItalic || lower.contains('italic') || lower.contains('oblique');

    return (
      fontFamily: family,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
  }
}
