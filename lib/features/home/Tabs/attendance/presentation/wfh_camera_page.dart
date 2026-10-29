import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/attendance/wfh_overlay_placement.dart';
import '../../../../../core/attendance/wfh_photo_composer.dart';
import '../../../../../core/attendance/wfh_tilt_detector.dart';
import 'widgets/wfh_edge_overlay.dart';
import 'widgets/wfh_live_overlay.dart';

class WfhCameraPage extends StatefulWidget {
  const WfhCameraPage({
    super.key,
    required this.stampData,
  });

  final WfhPhotoStampData stampData;

  @override
  State<WfhCameraPage> createState() => _WfhCameraPageState();
}

class _WfhCameraPageState extends State<WfhCameraPage> {
  static const _fallbackLogoAsset = 'lib/assets/logo/nexora.png';
  static const _addressTimeout = Duration(seconds: 4);
  static const _cameraUiOrientations = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];
  static const _controlsBottomPadding = 12.0;
  static const _controlsBarHeight = 76.0;
  final List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraLensDirection _lensDirection = CameraLensDirection.back;
  Widget? _logoWidget;

  String? _address;
  bool _loadingAddress = true;
  bool _capturing = false;
  bool _switchingCamera = false;
  String? _error;
  bool _initializing = false;
  late final WfhTiltDetector _tiltDetector;
  WfhOverlayPlacement _overlayPlacement = WfhOverlayPlacement.bottom;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(_cameraUiOrientations);
    _tiltDetector = WfhTiltDetector(
      onPlacementChanged: (placement) {
        if (!mounted || placement == _overlayPlacement) return;
        setState(() => _overlayPlacement = placement);
      },
    );
    _tiltDetector.start();
    _logoWidget = _buildLogoWidget();
    unawaited(_initCamera());
    unawaited(_loadAddress());
  }

  double _controlsReservedHeight(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _controlsBarHeight + _controlsBottomPadding + bottomInset + 8;
  }

  Future<void> _initCamera({CameraLensDirection? lensDirection}) async {
    if (_initializing) return;
    _initializing = true;

    if (lensDirection != null) {
      _lensDirection = lensDirection;
    }

    try {
      if (_cameras.isEmpty) {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw Exception('Kamera tidak tersedia');
        }
        _cameras.addAll(cameras);
      }

      final camera = _cameras.firstWhere(
        (item) => item.lensDirection == _lensDirection,
        orElse: () => _cameras.first,
      );
      _lensDirection = camera.lensDirection;

      final oldController = _controller;
      if (mounted) {
        setState(() {
          _controller = null;
          _error = null;
        });
      }
      await oldController?.dispose();

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _switchingCamera = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _switchingCamera = false;
      });
    } finally {
      _initializing = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _capturing || _switchingCamera || _initializing) {
      return;
    }

    final next = _lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    setState(() => _switchingCamera = true);
    await _initCamera(lensDirection: next);
  }

  Future<void> _loadAddress() async {
    try {
      final address = await WfhPhotoComposer.resolveAddress(
        widget.stampData.latitude,
        widget.stampData.longitude,
      ).timeout(
        _addressTimeout,
        onTimeout: () => _coordinatesLabel,
      );
      if (!mounted) return;
      setState(() {
        _address = address;
        _loadingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAddress = false);
    }
  }

  @override
  void dispose() {
    _tiltDetector.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    super.dispose();
  }

  String get _coordinatesLabel =>
      '${widget.stampData.latitude.toStringAsFixed(5)}, '
      '${widget.stampData.longitude.toStringAsFixed(5)}';

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }

    setState(() => _capturing = true);
    try {
      final capturedAt = DateTime.now();
      final file = await controller.takePicture();
      final result = await WfhPhotoComposer.stamp(
        sourcePath: file.path,
        data: WfhPhotoStampData(
          appName: widget.stampData.appName,
          branchName: widget.stampData.branchName,
          branchLogoUrl: widget.stampData.branchLogoUrl,
          latitude: widget.stampData.latitude,
          longitude: widget.stampData.longitude,
          capturedAt: capturedAt,
          timezoneLabel: widget.stampData.timezoneLabel,
          resolvedAddress: _address ?? _coordinatesLabel,
          overlayPlacement: _tiltDetector.placement,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
      setState(() => _capturing = false);
    }
  }

  Widget _buildLogoWidget() {
    final url = widget.stampData.branchLogoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Image.asset(
          _fallbackLogoAsset,
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(_fallbackLogoAsset, fit: BoxFit.cover);
  }

  Widget _buildPreview() {
    final controller = _controller!;
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }

    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: isPortrait ? previewSize.height : previewSize.width,
            height: isPortrait ? previewSize.width : previewSize.height,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(WfhOverlayPlacement placement) {
    return WfhLiveOverlay(
      appName: widget.stampData.appName,
      branchName: widget.stampData.branchName,
      address: _address,
      fallbackAddress: _coordinatesLabel,
      coordinatesLabel: _coordinatesLabel,
      timezoneLabel: widget.stampData.timezoneLabel,
      formatCapturedAt: WfhPhotoComposer.formatCapturedAt,
      logo: _logoWidget ?? Image.asset(_fallbackLogoAsset),
      loadingAddress: _loadingAddress,
      placement: placement,
    );
  }

  Widget _buildControlsBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: _controlsBottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildShutterButton(),
          if (_cameras.length > 1) ...[
            const SizedBox(width: 28),
            _buildFlipButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _capturing || _switchingCamera ? null : _capture,
      child: Container(
        width: _controlsBarHeight,
        height: _controlsBarHeight,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: _capturing ? Colors.white24 : Colors.white38,
        ),
        child: _capturing
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 30,
              ),
      ),
    );
  }

  Widget _buildFlipButton() {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _capturing || _switchingCamera ? null : _switchCamera,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: _switchingCamera
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.cameraswitch_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayPosition({
    required bool ready,
    required WfhOverlayPlacement placement,
    required double controlsHeight,
    required double topInset,
    required double screenHeight,
  }) {
    if (!ready) return const SizedBox.shrink();

    return WfhEdgeOverlay(
      placement: placement,
      controlsHeight: controlsHeight,
      topInset: topInset,
      screenHeight: screenHeight,
      child: _buildOverlay(placement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller != null && _controller!.value.isInitialized;
    final controlsHeight = _controlsReservedHeight(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (ready)
            RepaintBoundary(child: _buildPreview())
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Menyiapkan kamera…',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          _buildOverlayPosition(
            ready: ready,
            placement: _overlayPlacement,
            controlsHeight: controlsHeight,
            topInset: topInset,
            screenHeight: screenSize.height,
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: _buildControlsBar(),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _capturing ? null : () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
