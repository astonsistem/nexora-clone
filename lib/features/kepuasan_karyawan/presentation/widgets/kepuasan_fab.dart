import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/app_navigator.dart';
import '../../../../shared/navigation/shell_insets.dart';
import '../../data/kepuasan_service.dart';
import '../kepuasan_form_page.dart';

class KepuasanFab extends StatefulWidget {
  const KepuasanFab({
    super.key,
    required this.onClosed,
  });

  final void Function({required bool submitted, required bool hideFab})
      onClosed;

  static const double size = 96;

  @override
  State<KepuasanFab> createState() => _KepuasanFabState();
}

class _KepuasanFabState extends State<KepuasanFab> {
  static const _prefsX = 'kepuasan.fab.x';
  static const _prefsY = 'kepuasan.fab.y';

  Offset? _offset;
  Offset? _grab;
  bool _moved = false;
  bool _dragging = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _restorePosition();
  }

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_prefsX);
      final y = prefs.getDouble(_prefsY);
      if (!mounted || x == null || y == null) return;
      setState(() => _offset = Offset(x, y));
    } catch (_) {}
  }

  Future<void> _persist(Offset offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsX, offset.dx);
      await prefs.setDouble(_prefsY, offset.dy);
    } catch (_) {}
  }

  Offset _defaultOffset(Size size, EdgeInsets padding) {
    return Offset(
      size.width - KepuasanFab.size - 12,
      size.height -
          padding.bottom -
          kFloatingNavClearance -
          KepuasanFab.size -
          20,
    );
  }

  Offset _clamp(Offset raw, Size size, EdgeInsets padding) {
    final minX = 4.0;
    final maxX = size.width - KepuasanFab.size - 4;
    final minY = padding.top + 4;
    final maxY = size.height -
        padding.bottom -
        kFloatingNavClearance -
        KepuasanFab.size -
        4;
    return Offset(
      raw.dx.clamp(minX, maxX < minX ? minX : maxX),
      raw.dy.clamp(minY, maxY < minY ? minY : maxY),
    );
  }

  Future<void> _openForm() async {
    if (_opening) return;
    _opening = true;
    try {
      final surveys = await KepuasanService().listActiveSurveys();
      if (!mounted) return;
      if (surveys.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada survei aktif.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onClosed(submitted: false, hideFab: true);
        return;
      }

      final nav = AppNavigator.rootKey.currentState ??
          Navigator.of(context, rootNavigator: true);
      final submitted = await nav.push<bool>(
        MaterialPageRoute(
          builder: (_) => KepuasanFormPage(surveyId: surveys.first.id),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;
      widget.onClosed(
        submitted: submitted == true,
        hideFab: submitted == true,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survei gagal dimuat.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final offset = _clamp(
      _offset ?? _defaultOffset(size, padding),
      size,
      padding,
    );

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: KepuasanFab.size,
      height: KepuasanFab.size,
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _moved = false;
            _grab = details.localPosition;
            setState(() {
              _dragging = true;
              _offset = offset;
            });
          },
          onPanUpdate: (details) {
            if (details.delta.distanceSquared > 0.25) _moved = true;
            final grab = _grab ??
                const Offset(KepuasanFab.size / 2, KepuasanFab.size / 2);
            final next = _clamp(details.globalPosition - grab, size, padding);
            if (next == _offset) return;
            setState(() => _offset = next);
          },
          onPanEnd: (_) {
            final current = _offset ?? offset;
            setState(() {
              _dragging = false;
              _grab = null;
            });
            _persist(current);
            if (!_moved) _openForm();
          },
          onPanCancel: () => setState(() {
            _dragging = false;
            _grab = null;
          }),
          child: Transform.scale(
            scale: _dragging ? 1.04 : 1.0,
            child: _FabFace(dragging: _dragging),
          ),
        ),
      ),
    );
  }
}

class _FabFace extends StatelessWidget {
  const _FabFace({required this.dragging});

  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cache = (KepuasanFab.size * dpr).round().clamp(96, 256);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dragging ? 0.22 : 0.14),
            blurRadius: dragging ? 16 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'lib/assets/logo/rate.png',
          width: KepuasanFab.size,
          height: KepuasanFab.size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          cacheWidth: cache,
          cacheHeight: cache,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFF0EA5E9),
            child: Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
      ),
    );
  }
}
