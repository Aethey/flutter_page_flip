import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:page_example/main.dart' as app;

const int _pageCount = 3;
const int _measuredCycles = 5;
const int _flipsPerCycle = 4;
const double _frameBudgetMillis = 16.0;

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets(
    'profiles repeated page curl animations',
    (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(milliseconds: 16));

      expect(find.text('Page 1/$_pageCount'), findsOneWidget);

      // Complete one unmeasured round trip so image decoding, page
      // rasterization, and shader setup do not dominate the steady-state run.
      await _runRoundTrip(tester);

      await binding.watchPerformance(() async {
        for (int cycle = 0; cycle < _measuredCycles; cycle++) {
          await _runRoundTrip(tester);
        }
      }, reportKey: 'page_curl_animation');

      final Map<String, dynamic> performance =
          binding.reportData!['page_curl_animation'] as Map<String, dynamic>;
      _addDerivedMetrics(performance);

      final Size logicalSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      binding.reportData!['page_curl_metadata'] = <String, dynamic>{
        'captured_at_utc': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'dart_version': Platform.version,
        'logical_width': logicalSize.width,
        'logical_height': logicalSize.height,
        'device_pixel_ratio': tester.view.devicePixelRatio,
        'page_count': _pageCount,
        'warmup_flips': _flipsPerCycle,
        'measured_flips': _measuredCycles * _flipsPerCycle,
        'frame_budget_millis': _frameBudgetMillis,
      };

      expect(find.text('Page 1/$_pageCount'), findsOneWidget);
    },
    semanticsEnabled: false,
    timeout: Timeout.none,
  );
}

Future<void> _runRoundTrip(WidgetTester tester) async {
  await _flipTo(tester, icon: Icons.chevron_right, targetPage: 2);
  await _flipTo(tester, icon: Icons.chevron_right, targetPage: 3);
  await _flipTo(tester, icon: Icons.chevron_left, targetPage: 2);
  await _flipTo(tester, icon: Icons.chevron_left, targetPage: 1);
}

Future<void> _flipTo(
  WidgetTester tester, {
  required IconData icon,
  required int targetPage,
}) async {
  final Finder button = find.byIcon(icon);
  expect(button, findsOneWidget);

  await tester.tap(button);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );

  expect(find.text('Page $targetPage/$_pageCount'), findsOneWidget);
}

void _addDerivedMetrics(Map<String, dynamic> performance) {
  final List<int> buildMicros =
      (performance['frame_build_times'] as List<dynamic>).cast<int>();
  final List<int> rasterMicros =
      (performance['frame_rasterizer_times'] as List<dynamic>).cast<int>();
  final int frameCount = performance['frame_count'] as int;
  final int missedBuild = performance['missed_frame_build_budget_count'] as int;
  final int missedRaster =
      performance['missed_frame_rasterizer_budget_count'] as int;

  performance['50th_percentile_frame_build_time_millis'] = _percentileMillis(
    buildMicros,
    0.50,
  );
  performance['50th_percentile_frame_rasterizer_time_millis'] =
      _percentileMillis(rasterMicros, 0.50);
  performance['missed_frame_build_budget_percent'] =
      frameCount == 0 ? 0.0 : missedBuild * 100 / frameCount;
  performance['missed_frame_rasterizer_budget_percent'] =
      frameCount == 0 ? 0.0 : missedRaster * 100 / frameCount;
}

double _percentileMillis(List<int> values, double percentile) {
  if (values.isEmpty) {
    return 0;
  }
  final List<int> sorted = List<int>.of(values)..sort();
  final int index = ((sorted.length - 1) * percentile).round();
  return sorted[index] / 1000;
}
