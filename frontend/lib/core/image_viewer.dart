import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _maxScale = 8.0;
const _doubleTapScale = 2.5;

Future<void> showImageViewer(
  BuildContext context, {
  required String src,
  String? caption,
}) {
  return showGeneralDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    barrierDismissible: false,
    barrierLabel: caption ?? 'image',
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, _, _) => _Viewer(src: src, caption: caption),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.src, this.caption});

  final String src;
  final String? caption;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  final _controller = TransformationController();
  TapDownDetails? _lastTap;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed) {
      _controller.value = Matrix4.identity();
      return;
    }
    final origin = _lastTap?.localPosition;
    if (origin == null) return;
    _controller.value = Matrix4.identity()
      ..translateByDouble(
        -origin.dx * (_doubleTapScale - 1),
        -origin.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
  }

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).maybePop();

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onDoubleTapDown: (details) => _lastTap = details,
                    onDoubleTap: _toggleZoom,
                    child: InteractiveViewer(
                      transformationController: _controller,
                      maxScale: _maxScale,
                      child: Center(
                        child: Image.network(
                          widget.src,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) => const Text(
                            'image unavailable',
                            style: TextStyle(color: Colors.white70),
                          ),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(top: 8, right: 8, child: _CloseButton(onTap: close)),
                if (widget.caption != null && widget.caption!.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        color: Colors.black.withValues(alpha: 0.55),
                        child: Text(
                          widget.caption!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class ZoomBadge extends StatelessWidget {
  const ZoomBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.zoom_out_map, size: 13, color: Colors.white70),
    );
  }
}
