import 'package:flutter/material.dart';

import '../../../../../../core/attendance/wfh_overlay_placement.dart';

class WfhEdgeOverlay extends StatelessWidget {
  const WfhEdgeOverlay({
    super.key,
    required this.placement,
    required this.controlsHeight,
    required this.topInset,
    required this.screenHeight,
    required this.child,
  });

  final WfhOverlayPlacement placement;
  final double controlsHeight;
  final double topInset;
  final double screenHeight;
  final Widget child;

  static const _topClearance = 52.0;

  double get _stripLength =>
      screenHeight - topInset - controlsHeight - _topClearance - 16;

  @override
  Widget build(BuildContext context) {
    switch (placement) {
      case WfhOverlayPlacement.bottom:
        return Positioned(
          left: 0,
          right: 0,
          bottom: controlsHeight,
          child: child,
        );
      case WfhOverlayPlacement.left:
        return Positioned(
          left: 0,
          top: topInset + _topClearance,
          bottom: controlsHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: _stripLength,
                child: child,
              ),
            ),
          ),
        );
      case WfhOverlayPlacement.right:
        return Positioned(
          right: 0,
          top: topInset + _topClearance,
          bottom: controlsHeight,
          child: Align(
            alignment: Alignment.centerRight,
            child: RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: _stripLength,
                child: child,
              ),
            ),
          ),
        );
    }
  }
}
