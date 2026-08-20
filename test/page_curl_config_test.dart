import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/page_curl.dart';

void main() {
  group('PageCurlConfig', () {
    test('copyWith replaces only provided fields', () {
      const PageCurlConfig original = PageCurlConfig();
      final PageCurlConfig updated = original.copyWith(
        shadowStrength: 0.5,
        theme: BookTheme.black,
        pageRatio: 0.8,
      );

      expect(updated.shadowStrength, 0.5);
      expect(updated.theme, BookTheme.black);
      expect(updated.pageRatio, 0.8);
      expect(updated.shadowWidth, original.shadowWidth);
      expect(updated.damping, original.damping);
      expect(updated.typography.bodySize, original.typography.bodySize);
    });
  });

  group('BookTheme', () {
    test('exposes the documented presets', () {
      expect(
        BookTheme.presets,
        containsAll(<BookTheme>[
          BookTheme.white,
          BookTheme.black,
          BookTheme.gray,
          BookTheme.paperYellow,
          BookTheme.realistic,
        ]),
      );
    });

    test('uses an explicit back-face tint when provided', () {
      expect(BookTheme.white.effectiveBackFaceTint, const Color(0xFFF0F0F0));
    });

    test('derives a back-face tint from the page color when omitted', () {
      const BookTheme theme = BookTheme.gray;
      expect(theme.backFaceTint, isNull);
      expect(theme.effectiveBackFaceTint, isNot(theme.pageColor));
      expect(theme.effectiveBackFaceTint.a, 1.0);
    });
  });
}
