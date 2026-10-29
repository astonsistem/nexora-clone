import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import 'wfh_overlay_placement.dart';

class WfhTiltDetector {
  WfhTiltDetector({this.onPlacementChanged});

  final void Function(WfhOverlayPlacement placement)? onPlacementChanged;

  StreamSubscription<AccelerometerEvent>? _subscription;
  WfhOverlayPlacement _placement = WfhOverlayPlacement.bottom;

  WfhOverlayPlacement get placement => _placement;

  void start() {
    _subscription ??= accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_handleAccelerometer);
  }

  void _handleAccelerometer(AccelerometerEvent event) {
    final absX = event.x.abs();
    final absY = event.y.abs();

    if (absX < 2.5 && absY < 2.5) return;

    final WfhOverlayPlacement next;
    if (absX > absY + 2.5) {
      next = event.x > 0
          ? WfhOverlayPlacement.left
          : WfhOverlayPlacement.right;
    } else if (absY > absX + 2.5) {
      next = WfhOverlayPlacement.bottom;
    } else {
      return;
    }

    if (next == _placement) return;
    _placement = next;
    onPlacementChanged?.call(next);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() => stop();
}
