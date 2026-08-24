import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/physics.dart';

import 'geometry.dart';

class PointerVelocityEstimator {
  PointerVelocityEstimator({
    this.maxSamples = 10,
    this.maxAge = const Duration(milliseconds: 140),
  });

  final int maxSamples;
  final Duration maxAge;
  final List<_VelocitySample> _samples = <_VelocitySample>[];

  void reset() {
    _samples.clear();
  }

  void addSample(Offset position, int timestampMicros) {
    _samples.add(_VelocitySample(position, timestampMicros));

    while (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }

    final int cutoff = timestampMicros - maxAge.inMicroseconds;
    while (_samples.length > 2 && _samples.first.timestampMicros < cutoff) {
      _samples.removeAt(0);
    }
  }

  Offset estimateVelocity() {
    if (_samples.length < 2) {
      return Offset.zero;
    }

    double totalWeight = 0;
    Offset weightedVelocity = Offset.zero;

    for (int i = 1; i < _samples.length; i++) {
      final _VelocitySample prev = _samples[i - 1];
      final _VelocitySample current = _samples[i];

      final int dtMicros = current.timestampMicros - prev.timestampMicros;
      if (dtMicros <= 0) {
        continue;
      }

      final double dtSeconds = dtMicros / Duration.microsecondsPerSecond;
      final Offset velocity = (current.position - prev.position) / dtSeconds;

      final double weight = i / (_samples.length - 1);
      weightedVelocity += velocity * weight;
      totalWeight += weight;
    }

    if (totalWeight <= 0) {
      return Offset.zero;
    }
    return weightedVelocity / totalWeight;
  }
}

class InertiaDecision {
  const InertiaDecision({
    required this.commit,
    required this.directionalVelocity,
    required this.duration,
    required this.effectiveProgress,
  });

  final bool commit;
  final double directionalVelocity;
  final Duration duration;
  final double effectiveProgress;
}

InertiaDecision decideInertia({
  required double progress,
  required double velocityX,
  required FlipDirection direction,
  required double commitThreshold,
}) {
  final double directionalVelocity =
      direction == FlipDirection.next ? -velocityX : velocityX;

  final double velocityProgressBoost =
      (directionalVelocity / 2200.0).clamp(-0.40, 0.40);
  final double effectiveProgress =
      (progress + velocityProgressBoost).clamp(0.0, 1.0);

  final bool commit =
      effectiveProgress >= commitThreshold ||
      directionalVelocity > 720 ||
      (directionalVelocity > 280 &&
          effectiveProgress >= commitThreshold * 0.78);

  final Duration duration = computeInertiaDuration(
    progress: progress,
    commit: commit,
    directionalVelocity: directionalVelocity,
  );

  return InertiaDecision(
    commit: commit,
    directionalVelocity: directionalVelocity,
    duration: duration,
    effectiveProgress: effectiveProgress,
  );
}

Duration computeInertiaDuration({
  required double progress,
  required bool commit,
  required double directionalVelocity,
}) {
  final double remaining = commit ? (1 - progress) : progress;
  final double speed = directionalVelocity.abs().clamp(0, 2800);

  final double baseMs = 170 + 430 * remaining;
  final double speedFactor = 1 - (speed / 2800) * 0.55;

  final int ms = (baseMs * speedFactor).clamp(110, 560).round();
  return Duration(milliseconds: ms);
}

SpringDescription buildSpring({
  required double spring,
  required double damping,
}) {
  return SpringDescription(
    mass: 1,
    stiffness: spring.clamp(80, 1200),
    damping: damping.clamp(4, 120),
  );
}

SpringSimulation buildBackSimulation({
  required double spring,
  required double damping,
  required double normalizedVelocity,
}) {
  final SpringDescription tuned =
      buildSpring(spring: spring, damping: damping);

  // The simulation drives a lerp towards the anchored corner, so values above
  // 1 have no geometry to map onto. An under-damped spring would oscillate
  // around 1 and the clamped result flickers at the corner, so keep the back
  // animation at least critically damped and let it settle monotonically.
  final double criticalDamping = 2 * math.sqrt(tuned.stiffness * tuned.mass);
  final SpringDescription springDescription = tuned.damping >= criticalDamping
      ? tuned
      : SpringDescription(
          mass: tuned.mass,
          stiffness: tuned.stiffness,
          damping: criticalDamping,
        );

  return SpringSimulation(
    springDescription,
    0,
    1,
    normalizedVelocity.clamp(-5, 5),
    tolerance: const Tolerance(
      distance: 0.0008,
      velocity: 0.0008,
      time: 0.01,
    ),
  );
}

int nowMicros() => DateTime.now().microsecondsSinceEpoch;

class _VelocitySample {
  const _VelocitySample(this.position, this.timestampMicros);

  final Offset position;
  final int timestampMicros;
}
