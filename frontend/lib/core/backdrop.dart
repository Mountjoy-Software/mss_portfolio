import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const _linkDistance = 150.0;
const _areaPerNode = 22000.0;
const _minNodes = 18;
const _driftSpeed = 42.0;
const _lineAlpha = 0.28;
const _dotAlpha = 0.55;

class GlowVignette extends StatelessWidget {
  const GlowVignette({this.strength = 1, this.radius = 0.95, super.key});

  final double strength;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glow = scheme.primary.withValues(
      alpha: ((scheme.brightness == Brightness.dark ? 0.30 : 0.34) * strength)
          .clamp(0.0, 1.0),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: radius,
          colors: [glow, glow.withValues(alpha: 0.0)],
          stops: const [0.0, 0.7],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _Node {
  _Node({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double r;
}

class ConstellationField extends StatefulWidget {
  const ConstellationField({
    this.lineAlpha = _lineAlpha,
    this.dotAlpha = _dotAlpha,
    super.key,
  });

  final double lineAlpha;
  final double dotAlpha;

  @override
  State<ConstellationField> createState() => _ConstellationFieldState();
}

class _ConstellationFieldState extends State<ConstellationField>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  final _nodes = <_Node>[];
  final _repaint = ValueNotifier(0);

  late final Ticker _ticker;
  Size _size = Size.zero;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticker.muted = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  _Node _randomNode(Size size) => _Node(
    x: _random.nextDouble() * size.width,
    y: _random.nextDouble() * size.height,
    vx: (_random.nextDouble() - 0.5) * _driftSpeed,
    vy: (_random.nextDouble() - 0.5) * _driftSpeed,
    r: 1 + _random.nextDouble() * 1.4,
  );

  void _resize(Size size) {
    final previous = _size;
    _size = size;
    final target = max(
      _minNodes,
      (size.width * size.height / _areaPerNode).round(),
    );

    if (_nodes.isEmpty) {
      for (var i = 0; i < target; i++) {
        _nodes.add(_randomNode(size));
      }
      return;
    }

    if (previous.width > 0 && previous.height > 0) {
      final scaleX = size.width / previous.width;
      final scaleY = size.height / previous.height;
      for (final node in _nodes) {
        node.x *= scaleX;
        node.y *= scaleY;
      }
    }

    while (_nodes.length > target) {
      _nodes.removeLast();
    }
    while (_nodes.length < target) {
      _nodes.add(_randomNode(size));
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (_nodes.isEmpty || dt <= 0 || dt > 0.25) return;
    for (final n in _nodes) {
      n.x += n.vx * dt;
      n.y += n.vy * dt;
      if (n.x < 0 || n.x > _size.width) n.vx = -n.vx;
      if (n.y < 0 || n.y > _size.height) n.vy = -n.vy;
    }
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isFinite && size != _size) _resize(size);
        return CustomPaint(
          size: size,
          painter: _ConstellationPainter(
            nodes: _nodes,
            lineColor: dark ? const Color(0xFFF0A868) : const Color(0xFFC2410C),
            dotColor: dark ? const Color(0xFFF7C9A3) : const Color(0xFFE65C20),
            lineAlpha: widget.lineAlpha,
            dotAlpha: widget.dotAlpha,
            repaint: _repaint,
          ),
        );
      },
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.nodes,
    required this.lineColor,
    required this.dotColor,
    required this.lineAlpha,
    required this.dotAlpha,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_Node> nodes;
  final Color lineColor;
  final Color dotColor;
  final double lineAlpha;
  final double dotAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..strokeWidth = 1;
    final dot = Paint()..color = dotColor.withValues(alpha: dotAlpha);

    for (var i = 0; i < nodes.length; i++) {
      final a = Offset(nodes[i].x, nodes[i].y);
      for (var j = i + 1; j < nodes.length; j++) {
        final b = Offset(nodes[j].x, nodes[j].y);
        final dist = (a - b).distance;
        if (dist >= _linkDistance) continue;
        line.color = lineColor.withValues(
          alpha: lineAlpha * (1 - dist / _linkDistance),
        );
        canvas.drawLine(a, b, line);
      }
    }
    for (final n in nodes) {
      canvas.drawCircle(Offset(n.x, n.y), n.r, dot);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.lineAlpha != lineAlpha ||
      oldDelegate.dotAlpha != dotAlpha ||
      oldDelegate.nodes != nodes;
}
