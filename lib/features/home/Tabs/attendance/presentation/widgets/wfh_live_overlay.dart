import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../../core/attendance/wfh_overlay_placement.dart';

const _textShadows = <Shadow>[
  Shadow(offset: Offset(0, 1), blurRadius: 4, color: Color(0xD9000000)),
  Shadow(offset: Offset(0, 0), blurRadius: 8, color: Color(0x99000000)),
];

class WfhLiveOverlay extends StatefulWidget {
  const WfhLiveOverlay({
    super.key,
    required this.appName,
    required this.branchName,
    required this.address,
    required this.fallbackAddress,
    required this.coordinatesLabel,
    required this.timezoneLabel,
    required this.formatCapturedAt,
    required this.logo,
    this.loadingAddress = false,
    this.placement = WfhOverlayPlacement.bottom,
  });

  final String appName;
  final String? branchName;
  final String? address;
  final String fallbackAddress;
  final String coordinatesLabel;
  final String timezoneLabel;
  final String Function(DateTime at, String tzLabel) formatCapturedAt;
  final Widget logo;
  final bool loadingAddress;
  final WfhOverlayPlacement placement;

  @override
  State<WfhLiveOverlay> createState() => _WfhLiveOverlayState();
}

class _WfhLiveOverlayState extends State<WfhLiveOverlay> {
  Timer? _clockTimer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String get _displayTitle {
    final branch = widget.branchName?.trim();
    if (branch != null && branch.isNotEmpty) return branch;
    return widget.appName;
  }

  String get _addressText {
    final resolved = widget.address?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    if (widget.loadingAddress) return 'Mencari alamat…';
    return widget.fallbackAddress;
  }

  @override
  Widget build(BuildContext context) {
    final capturedAtLabel =
        widget.formatCapturedAt(_now, widget.timezoneLabel);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _logoBox(),
          const SizedBox(width: 10),
          Expanded(
            child: _textBlock(
              title: _displayTitle,
              capturedAtLabel: capturedAtLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 48, height: 48, child: widget.logo),
    );
  }

  Widget _textBlock({
    required String title,
    required String capturedAtLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            shadows: _textShadows,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _addressText,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.loadingAddress ? Colors.white70 : Colors.white,
            fontSize: 11,
            height: 1.35,
            shadows: _textShadows,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          capturedAtLabel,
          style: const TextStyle(
            color: Color(0xFFBAE6FD),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
            shadows: _textShadows,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.coordinatesLabel,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontFeatures: [FontFeature.tabularFigures()],
            shadows: _textShadows,
          ),
        ),
      ],
    );
  }
}
