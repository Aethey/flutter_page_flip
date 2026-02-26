import 'package:flutter/foundation.dart';

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

@immutable
class PageCurlConfig {
  const PageCurlConfig({
    this.shadowStrength = 0.90,
    this.shadowWidth = 44,
    this.highlightStrength = 0.70,
    this.spring = 420,
    this.damping = 24,
    this.commitThreshold = 0.44,
    this.curlRadiusFactor = 1.18,
    this.typography = const BookTypography(),
    this.pageRatio = 0.70,
    this.edgeZoneWidth = 62,
  });

  final double shadowStrength;
  final double shadowWidth;
  final double highlightStrength;
  final double spring;
  final double damping;
  final double commitThreshold;
  final double curlRadiusFactor;
  final BookTypography typography;
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
      pageRatio: pageRatio ?? this.pageRatio,
      edgeZoneWidth: edgeZoneWidth ?? this.edgeZoneWidth,
    );
  }
}
