import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vellum_engine/src/geometry.dart';
import 'package:vellum_engine/src/physics.dart';

void main() {
  group('PointerVelocityEstimator', () {
    test('returns zero until two samples exist', () {
      final PointerVelocityEstimator estimator = PointerVelocityEstimator();
      estimator.addSample(Offset.zero, 0);
      expect(estimator.estimateVelocity(), Offset.zero);
    });

    test('estimates velocity from recent samples', () {
      final PointerVelocityEstimator estimator = PointerVelocityEstimator();
      estimator.addSample(Offset.zero, 0);
      estimator.addSample(const Offset(-220, 0), 100000);

      final Offset velocity = estimator.estimateVelocity();
      expect(velocity.dx, closeTo(-2200, 0.001));
      expect(velocity.dy, 0);
    });

    test('reset clears accumulated samples', () {
      final PointerVelocityEstimator estimator = PointerVelocityEstimator();
      estimator
        ..addSample(Offset.zero, 0)
        ..addSample(const Offset(10, 0), 1000)
        ..reset();

      expect(estimator.estimateVelocity(), Offset.zero);
    });
  });

  group('decideInertia', () {
    test('commits when progress crosses the threshold', () {
      final InertiaDecision decision = decideInertia(
        progress: 0.5,
        velocityX: 0,
        direction: FlipDirection.next,
        commitThreshold: 0.38,
      );

      expect(decision.commit, isTrue);
      expect(decision.effectiveProgress, 0.5);
    });

    test('commits a fast next-page flick even at low progress', () {
      final InertiaDecision decision = decideInertia(
        progress: 0.1,
        velocityX: -900,
        direction: FlipDirection.next,
        commitThreshold: 0.38,
      );

      expect(decision.directionalVelocity, 900);
      expect(decision.commit, isTrue);
    });

    test('does not commit a slow drag below the threshold', () {
      final InertiaDecision decision = decideInertia(
        progress: 0.1,
        velocityX: 40,
        direction: FlipDirection.next,
        commitThreshold: 0.38,
      );

      expect(decision.commit, isFalse);
    });

    test('commits a fast previous-page flick in the positive direction', () {
      final InertiaDecision decision = decideInertia(
        progress: 0.1,
        velocityX: 900,
        direction: FlipDirection.prev,
        commitThreshold: 0.38,
      );

      expect(decision.directionalVelocity, 900);
      expect(decision.commit, isTrue);
    });

    test('does not commit a fast flick in the opposing direction', () {
      final InertiaDecision decision = decideInertia(
        progress: 0.1,
        velocityX: 900,
        direction: FlipDirection.next,
        commitThreshold: 0.38,
      );

      expect(decision.directionalVelocity, -900);
      expect(decision.commit, isFalse);
    });

    test('commits exactly at the progress threshold', () {
      final InertiaDecision decision = decideInertia(
        progress: 0.38,
        velocityX: 0,
        direction: FlipDirection.next,
        commitThreshold: 0.38,
      );

      expect(decision.commit, isTrue);
    });
  });

  group('computeInertiaDuration', () {
    test('stays within the documented duration range', () {
      final Duration duration = computeInertiaDuration(
        progress: 0.2,
        commit: true,
        directionalVelocity: 100,
      );

      expect(duration.inMilliseconds, inInclusiveRange(110, 560));
    });

    test('shortens as directional speed increases', () {
      final Duration slow = computeInertiaDuration(
        progress: 0.3,
        commit: true,
        directionalVelocity: 0,
      );
      final Duration fast = computeInertiaDuration(
        progress: 0.3,
        commit: true,
        directionalVelocity: 2800,
      );

      expect(fast.inMilliseconds, lessThan(slow.inMilliseconds));
    });
  });

  group('buildSpring', () {
    test('clamps stiffness and damping', () {
      final spring = buildSpring(spring: 10, damping: 1);
      expect(spring.stiffness, 80);
      expect(spring.damping, 4);

      final strong = buildSpring(spring: 4000, damping: 400);
      expect(strong.stiffness, 1200);
      expect(strong.damping, 120);
    });
  });

  group('buildBackSimulation', () {
    test('settles onto the anchor without oscillating', () {
      final SpringSimulation simulation = buildBackSimulation(
        spring: 420,
        damping: 24,
        normalizedVelocity: 0,
      );

      double previous = simulation.x(0);
      for (int i = 1; i <= 1000; i++) {
        final double current = simulation.x(i / 1000);
        expect(
          current,
          greaterThanOrEqualTo(previous - 1e-9),
          reason: 'value dipped back at t=${i / 1000}',
        );
        previous = current;
      }
      expect(previous, closeTo(1.0, 0.001));
    });

    test('never travels past the anchor for any release velocity', () {
      for (final double velocity in <double>[-4.5, -2, 0, 2, 4.5, 20]) {
        for (final double spring in <double>[10, 420, 4000]) {
          final SpringSimulation simulation = buildBackSimulation(
            spring: spring,
            damping: 1,
            normalizedVelocity: velocity,
          );

          expect(
            _maxValue(simulation),
            lessThanOrEqualTo(1 + 1e-9),
            reason: 'spring=$spring velocity=$velocity overshot the anchor',
          );
        }
      }
    });

    test('leaves an already over-damped config alone', () {
      final SpringSimulation simulation = buildBackSimulation(
        spring: 80,
        damping: 120,
        normalizedVelocity: 0,
      );

      expect(_maxValue(simulation, seconds: 40), lessThanOrEqualTo(1 + 1e-9));
      expect(simulation.x(40), closeTo(1.0, 0.001));
    });
  });
}

/// Samples the simulation densely and returns the largest value reached.
double _maxValue(SpringSimulation simulation, {int seconds = 4}) {
  double maxValue = double.negativeInfinity;
  for (int i = 0; i <= seconds * 1000; i++) {
    maxValue = math.max(maxValue, simulation.x(i / 1000));
  }
  return maxValue;
}
