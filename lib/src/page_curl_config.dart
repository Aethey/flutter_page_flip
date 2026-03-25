import 'dart:ui';

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Book page theme — controls all visual colors of the rendered page.
// ---------------------------------------------------------------------------

@immutable
class BookTheme {
  const BookTheme({
    required this.name,
    required this.pageColor,
    this.pageColorEnd,
    required this.titleColor,
    required this.bodyColor,
    required this.pageNumberColor,
    required this.captionColor,
    this.borderColor,
    this.borderWidth = 0,
    this.vignetteOpacity = 0,
    this.edgeShadeOpacity = 0.07,
    this.backFaceTint,
    this.realisticTexture = false,
  });

  final String name;
  final Color pageColor;
  final Color? pageColorEnd;
  final Color titleColor;
  final Color bodyColor;
  final Color pageNumberColor;
  final Color captionColor;
  final Color? borderColor;
  final double borderWidth;
  final double vignetteOpacity;
  final double edgeShadeOpacity;
  final Color? backFaceTint;
  final bool realisticTexture;

  Color get effectiveBackFaceTint {
    if (backFaceTint != null) return backFaceTint!;
    final int r = (pageColor.r * 255.0).round() & 0xff;
    final int g = (pageColor.g * 255.0).round() & 0xff;
    final int b = (pageColor.b * 255.0).round() & 0xff;
    return Color.fromARGB(255, (r * 0.92).round(), (g * 0.90).round(), (b * 0.86).round());
  }

  // ---- Presets -------------------------------------------------------------

  static const BookTheme white = BookTheme(
    name: 'White',
    pageColor: Color(0xFFFFFFFF),
    titleColor: Color(0xFF1A1A1A),
    bodyColor: Color(0xFF333333),
    pageNumberColor: Color(0xFF999999),
    captionColor: Color(0xFF777777),
    borderColor: Color(0x18000000),
    borderWidth: 1.0,
    edgeShadeOpacity: 0.05,
    backFaceTint: Color(0xFFF0F0F0),
  );

  static const BookTheme black = BookTheme(
    name: 'Black',
    pageColor: Color(0xFF1A1A1A),
    titleColor: Color(0xFFE8E8E8),
    bodyColor: Color(0xFFCCCCCC),
    pageNumberColor: Color(0xFF777777),
    captionColor: Color(0xFF888888),
    edgeShadeOpacity: 0.04,
    backFaceTint: Color(0xFF2A2A2A),
  );

  static const BookTheme gray = BookTheme(
    name: 'Gray',
    pageColor: Color(0xFFE8E6E2),
    pageColorEnd: Color(0xFFDDD9D4),
    titleColor: Color(0xFF222222),
    bodyColor: Color(0xFF444444),
    pageNumberColor: Color(0xFF888888),
    captionColor: Color(0xFF777777),
    borderColor: Color(0x12000000),
    borderWidth: 1.0,
    vignetteOpacity: 0.08,
    edgeShadeOpacity: 0.06,
  );

  static const BookTheme paperYellow = BookTheme(
    name: 'Paper',
    pageColor: Color(0xFFF8F1E3),
    pageColorEnd: Color(0xFFF4EAD8),
    titleColor: Color(0xFF27221A),
    bodyColor: Color(0xFF3A3328),
    pageNumberColor: Color(0xFF6C6454),
    captionColor: Color(0xFF6C6454),
    borderColor: Color(0x1A000000),
    borderWidth: 1.4,
    vignetteOpacity: 0.20,
    edgeShadeOpacity: 0.07,
    backFaceTint: Color(0xFFEBDEC8),
  );

  static const BookTheme realistic = BookTheme(
    name: 'Realistic',
    pageColor: Color(0xFFF5ECDA),
    pageColorEnd: Color(0xFFEEE2CC),
    titleColor: Color(0xFF2A2318),
    bodyColor: Color(0xFF3D362A),
    pageNumberColor: Color(0xFF7A6E5C),
    captionColor: Color(0xFF7A6E5C),
    borderColor: Color(0x20000000),
    borderWidth: 1.2,
    vignetteOpacity: 0.25,
    edgeShadeOpacity: 0.09,
    backFaceTint: Color(0xFFE4D6BE),
    realisticTexture: true,
  );

  static const List<BookTheme> presets = [
    white,
    black,
    gray,
    paperYellow,
    realistic,
  ];
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

@immutable
class BookTypography {
  const BookTypography({
    this.horizontalPadding = 28,
    this.topPadding = 34,
    this.bottomPadding = 28,
    this.titleSize = 26,
    this.bodySize = 16,
    this.lineHeight = 1.72,
    this.paragraphSpacing = 16,
    this.pageNumberSize = 13,
  });

  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double titleSize;
  final double bodySize;
  final double lineHeight;
  final double paragraphSpacing;
  final double pageNumberSize;
}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

@immutable
class PageCurlConfig {
  const PageCurlConfig({
    this.shadowStrength = 0.90,
    this.shadowWidth = 44,
    this.highlightStrength = 0.70,
    this.spring = 420,
    this.damping = 24,
    this.commitThreshold = 0.38,
    this.curlRadiusFactor = 1.18,
    this.typography = const BookTypography(),
    this.theme = BookTheme.paperYellow,
    this.pageRatio = 0.70,
    this.edgeZoneWidth = 84,
  });

  final double shadowStrength;
  final double shadowWidth;
  final double highlightStrength;
  final double spring;
  final double damping;
  final double commitThreshold;
  final double curlRadiusFactor;
  final BookTypography typography;
  final BookTheme theme;
  final double pageRatio;
  final double edgeZoneWidth;

  PageCurlConfig copyWith({
    double? shadowStrength,
    double? shadowWidth,
    double? highlightStrength,
    double? spring,
    double? damping,
    double? commitThreshold,
    double? curlRadiusFactor,
    BookTypography? typography,
    BookTheme? theme,
    double? pageRatio,
    double? edgeZoneWidth,
  }) {
    return PageCurlConfig(
      shadowStrength: shadowStrength ?? this.shadowStrength,
      shadowWidth: shadowWidth ?? this.shadowWidth,
      highlightStrength: highlightStrength ?? this.highlightStrength,
      spring: spring ?? this.spring,
      damping: damping ?? this.damping,
      commitThreshold: commitThreshold ?? this.commitThreshold,
      curlRadiusFactor: curlRadiusFactor ?? this.curlRadiusFactor,
      typography: typography ?? this.typography,
      theme: theme ?? this.theme,
      pageRatio: pageRatio ?? this.pageRatio,
      edgeZoneWidth: edgeZoneWidth ?? this.edgeZoneWidth,
    );
  }
}
