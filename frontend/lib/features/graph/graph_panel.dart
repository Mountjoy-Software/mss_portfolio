import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

const _repulsion = 26000.0;
const _repulsionRange = 300.0;
const _stiffness = 0.02;
const _damping = 0.85;
const _centering = 0.012;
const _minSeparation = 30.0;
const _maxSpeed = 14.0;
const _panelHeight = 460.0;

class _Body {
  _Body(this.node, this.x, this.y);

  final GraphNode node;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  bool expanded = false;
  bool pinned = false;

  double get radius => node.isCategory ? 9 : 6;
}

class _Edge {
  const _Edge(this.from, this.to, this.weight);

  final String from;
  final String to;
  final double weight;
}

class GraphPanel extends ConsumerStatefulWidget {
  const GraphPanel({required this.seed, super.key});

  final String seed;

  @override
  ConsumerState<GraphPanel> createState() => _GraphPanelState();
}

class _GraphPanelState extends ConsumerState<GraphPanel>
    with SingleTickerProviderStateMixin {
  final _bodies = <String, _Body>{};
  final _edges = <_Edge>[];
  final _random = Random();
  final _repaint = ValueNotifier(0);

  late final Ticker _ticker;
  Size _size = Size.zero;
  Duration _last = Duration.zero;
  String? _selected;
  String? _hovered;
  String? _dragging;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categories = await ref.read(apiClientProvider).graphSeed();
      final target = categories.firstWhere(
        (c) => c.title == widget.seed,
        orElse: () => categories.first,
      );
      _bodies[target.id] = _Body(target, 0, 0);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _selected = target.id;
      });
      await _expand(target.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '$error';
      });
    }
  }

  Future<void> _expand(String id) async {
    final origin = _bodies[id];
    if (origin == null || origin.expanded) return;
    origin.expanded = true;
    try {
      final neighbours = await ref.read(apiClientProvider).expandNode(id);
      if (!mounted) return;
      setState(() {
        for (final (i, node) in neighbours.indexed) {
          if (_bodies[node.id] == null) {
            final angle =
                i * 2 * pi / max(1, neighbours.length) +
                _random.nextDouble() * 0.5;
            _bodies[node.id] = _Body(
              node,
              origin.x + cos(angle) * 120,
              origin.y + sin(angle) * 120,
            );
          }
          final already = _edges.any(
            (e) =>
                (e.from == id && e.to == node.id) ||
                (e.from == node.id && e.to == id),
          );
          if (!already) _edges.add(_Edge(id, node.id, node.score ?? 0.2));
        }
      });
    } catch (_) {
      origin.expanded = false;
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_bodies.isEmpty || dt <= 0 || dt > 0.25 || _size.isEmpty) return;
    final step = (dt * 60).clamp(0.2, 2.0);

    final list = _bodies.values.toList();
    final fx = <String, double>{};
    final fy = <String, double>{};
    for (final body in list) {
      fx[body.node.id] = 0;
      fy[body.node.id] = 0;
    }

    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i];
        final b = list[j];
        var dx = b.x - a.x;
        var dy = b.y - a.y;
        var distance = sqrt(dx * dx + dy * dy);
        if (distance < 0.01) {
          dx = _random.nextDouble() - 0.5;
          dy = _random.nextDouble() - 0.5;
          distance = 1;
        }
        if (distance > _repulsionRange) continue;
        final effective = max(distance, _minSeparation);
        final push = _repulsion / (effective * effective);
        final ux = dx / distance;
        final uy = dy / distance;
        fx[a.node.id] = fx[a.node.id]! - ux * push;
        fy[a.node.id] = fy[a.node.id]! - uy * push;
        fx[b.node.id] = fx[b.node.id]! + ux * push;
        fy[b.node.id] = fy[b.node.id]! + uy * push;
      }
    }

    for (final edge in _edges) {
      final a = _bodies[edge.from];
      final b = _bodies[edge.to];
      if (a == null || b == null) continue;
      final rest = 135 - 50 * edge.weight.clamp(0.0, 1.0);
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final distance = max(0.01, sqrt(dx * dx + dy * dy));
      final pull = (distance - rest) * _stiffness;
      final ux = dx / distance;
      final uy = dy / distance;
      fx[a.node.id] = fx[a.node.id]! + ux * pull;
      fy[a.node.id] = fy[a.node.id]! + uy * pull;
      fx[b.node.id] = fx[b.node.id]! - ux * pull;
      fy[b.node.id] = fy[b.node.id]! - uy * pull;
    }

    final limit = min(_size.width, _size.height) / 2 - 20;
    for (final body in list) {
      if (body.pinned) {
        body.vx = 0;
        body.vy = 0;
        continue;
      }
      var forceX = fx[body.node.id]! - body.x * _centering;
      var forceY = fy[body.node.id]! - body.y * _centering;
      body.vx = (body.vx + forceX * step) * _damping;
      body.vy = (body.vy + forceY * step) * _damping;
      final speed = sqrt(body.vx * body.vx + body.vy * body.vy);
      if (speed > _maxSpeed) {
        body.vx *= _maxSpeed / speed;
        body.vy *= _maxSpeed / speed;
      }
      body.x += body.vx * step;
      body.y += body.vy * step;
      final radius = sqrt(body.x * body.x + body.y * body.y);
      if (radius > limit) {
        body.x *= limit / radius;
        body.y *= limit / radius;
      }
    }
    _repaint.value++;
  }

  Future<void> _reset() async {
    setState(() {
      _bodies.clear();
      _edges.clear();
      _selected = null;
      _hovered = null;
      _dragging = null;
      _loading = true;
      _error = null;
    });
    await _load();
  }

  Offset _toWorld(Offset local) =>
      Offset(local.dx - _size.width / 2, local.dy - _size.height / 2);

  _Body? _hit(Offset local) {
    final world = _toWorld(local);
    _Body? found;
    var best = 24.0;
    for (final body in _bodies.values) {
      final d = (Offset(body.x, body.y) - world).distance;
      if (d < best) {
        best = d;
        found = body;
      }
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(colorScheme),
        const SizedBox(height: 8),
        Text(
          'Every point is a piece of this portfolio, embedded with Amazon Bedrock '
          'Titan and stored in a Qdrant collection; the lines are cosine '
          'similarity between them. Expanding ${widget.seed} runs a vector search '
          'filtered to that kind, and expanding anything else searches the whole '
          'collection for nearest neighbours. Hover a point to see it, drag to '
          'rearrange.\n\n'
          'This collection is also how the assistant on this site knows anything. '
          'Each question is embedded the same way and the closest points are '
          'retrieved and handed to Claude as context, so it can talk about '
          'anything in here naturally instead of being limited to a fixed script.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            height: 1.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _panel(ColorScheme colorScheme) {
    return Container(
      height: _panelHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;
          final inspector = _Inspector(
            node: _selected == null ? null : _bodies[_selected]?.node,
            total: _bodies.length,
            edges: _edges.length,
          );
          return wide
              ? Row(
                  children: [
                    SizedBox(
                      width: constraints.maxWidth * 0.62,
                      child: _canvas(),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.25,
                      ),
                    ),
                    Expanded(child: inspector),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(height: _panelHeight * 0.58, child: _canvas()),
                    Divider(
                      height: 1,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.25,
                      ),
                    ),
                    Expanded(child: inspector),
                  ],
                );
        },
      ),
    );
  }

  Widget _canvas() {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  height: 1.6,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _ResetButton(onTap: _reset, label: 'try again'),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isFinite) _size = size;
        return MouseRegion(
          cursor: _hovered == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onHover: (event) {
            final body = _hit(event.localPosition);
            final id = body?.node.id;
            if (id != _hovered) setState(() => _hovered = id);
          },
          onExit: (_) {
            if (_hovered != null) setState(() => _hovered = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final body = _hit(details.localPosition);
              if (body == null) return;
              setState(() => _selected = body.node.id);
              _expand(body.node.id);
            },
            onPanStart: (details) {
              final body = _hit(details.localPosition);
              if (body == null) return;
              body.pinned = true;
              setState(() {
                _dragging = body.node.id;
                _selected = body.node.id;
              });
            },
            onPanUpdate: (details) {
              final body = _dragging == null ? null : _bodies[_dragging];
              if (body == null) return;
              final world = _toWorld(details.localPosition);
              body.x = world.dx;
              body.y = world.dy;
              _repaint.value++;
            },
            onPanEnd: (_) {
              final body = _dragging == null ? null : _bodies[_dragging];
              body?.pinned = false;
              setState(() => _dragging = null);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    size: size,
                    painter: _GraphPainter(
                      bodies: _bodies,
                      edges: _edges,
                      selected: _selected,
                      hovered: _hovered,
                      hub: colorScheme.primary,
                      leaf: dark
                          ? const Color(0xFF2DD4BF)
                          : const Color(0xFF0D9488),
                      label: colorScheme.onSurface,
                      muted: colorScheme.onSurfaceVariant,
                      tooltipFill: colorScheme.surface,
                      tooltipBorder: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.45,
                      ),
                      repaint: _repaint,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _ResetButton(onTap: _reset),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap, this.label = 'reset'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.bodies,
    required this.edges,
    required this.selected,
    required this.hovered,
    required this.hub,
    required this.leaf,
    required this.label,
    required this.muted,
    required this.tooltipFill,
    required this.tooltipBorder,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Map<String, _Body> bodies;
  final List<_Edge> edges;
  final String? selected;
  final String? hovered;
  final Color hub;
  final Color leaf;
  final Color label;
  final Color muted;
  final Color tooltipFill;
  final Color tooltipBorder;

  static final _labels = <String, TextPainter>{};

  TextPainter _labelFor(String text, Color colour) {
    return _labels.putIfAbsent('$text|${colour.toARGB32()}', () {
      final painter = TextPainter(
        text: TextSpan(
          text: text.length > 30 ? '${text.substring(0, 29)}…' : text,
          style: TextStyle(color: colour, fontSize: 11, height: 1.2),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    final line = Paint()..strokeWidth = 1;
    for (final edge in edges) {
      final a = bodies[edge.from];
      final b = bodies[edge.to];
      if (a == null || b == null) continue;
      line.color = hub.withValues(
        alpha: (0.16 + edge.weight * 0.5).clamp(0.12, 0.7),
      );
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), line);
    }

    for (final body in bodies.values) {
      final colour = body.node.isCategory || body.expanded ? hub : leaf;
      final centre = Offset(body.x, body.y);
      final isSelected = body.node.id == selected;
      if (isSelected) {
        canvas.drawCircle(
          centre,
          body.radius + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colour,
        );
      }
      canvas.drawCircle(centre, body.radius, Paint()..color = colour);
      if (body.node.isCategory && body.node.id != hovered) {
        final painter = _labelFor(body.node.title, label);
        painter.paint(
          canvas,
          Offset(body.x - painter.width / 2, body.y + body.radius + 4),
        );
      }
    }

    final chosen = hovered == null ? null : bodies[hovered];
    if (chosen != null) _tooltip(canvas, size, chosen);
    canvas.restore();
  }

  TextPainter _wrapped(
    String text,
    Color colour,
    double maxWidth,
    double fontSize,
    FontWeight weight,
  ) {
    final key =
        '$text|${colour.toARGB32()}|$maxWidth|$fontSize|${weight.value}';
    return _labels.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: colour,
            fontSize: fontSize,
            height: 1.35,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 6,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      return painter;
    });
  }

  void _tooltip(Canvas canvas, Size size, _Body body) {
    const padding = 10.0;
    final maxTextWidth = min(300.0, max(120.0, size.width - 60));
    final title = _wrapped(
      body.node.title,
      label,
      maxTextWidth,
      12.5,
      FontWeight.w600,
    );
    final detail = body.node.score != null && body.node.score! > 0
        ? '${body.node.kind}  ·  ${body.node.score!.toStringAsFixed(3)}'
        : body.node.kind;
    final subtitle = _wrapped(detail, muted, maxTextWidth, 11, FontWeight.w400);

    final width = max(title.width, subtitle.width) + padding * 2;
    final height = title.height + subtitle.height + padding * 2 + 4;

    var left = body.x + body.radius + 10;
    var top = body.y - height / 2;
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;
    if (left + width > halfWidth - 4) left = body.x - body.radius - 10 - width;
    if (left < -halfWidth + 4) left = -halfWidth + 4;
    top = top.clamp(-halfHeight + 4, halfHeight - height - 4);

    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(5),
    );
    canvas.drawRRect(box, Paint()..color = tooltipFill);
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tooltipBorder,
    );
    title.paint(canvas, Offset(left + padding, top + padding));
    subtitle.paint(
      canvas,
      Offset(left + padding, top + padding + title.height + 4),
    );
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.hovered != hovered ||
      oldDelegate.hub != hub ||
      oldDelegate.leaf != leaf ||
      oldDelegate.tooltipFill != tooltipFill;
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.node,
    required this.total,
    required this.edges,
  });

  final GraphNode? node;
  final int total;
  final int edges;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mono = textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.55);
    final muted = mono?.copyWith(color: colorScheme.onSurfaceVariant);

    final current = node;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'qdrant · portfolio',
            style: mono?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('$total points · $edges edges', style: muted),
          Text('drag to rearrange · tap to expand', style: muted),
          const SizedBox(height: 14),
          if (current == null)
            Text('Tap a point to inspect its payload.', style: muted)
          else ...[
            Text(
              current.title,
              style: mono?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _Row(label: 'kind', value: current.kind, style: mono, muted: muted),
            if (current.score != null && current.score! > 0)
              _Row(
                label: 'score',
                value: current.score!.toStringAsFixed(4),
                style: mono,
                muted: muted,
              ),
            if (current.payload['deck'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go('${current.payload['deck']}'),
                    child: Text(
                      'open the full write-up >',
                      style: mono?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            for (final entry in current.payload.entries)
              if (entry.key != 'deck' &&
                  entry.value != null &&
                  '${entry.value}'.isNotEmpty)
                _Row(
                  label: entry.key,
                  value: entry.value is List
                      ? (entry.value as List).join(', ')
                      : '${entry.value}',
                  style: mono,
                  muted: muted,
                ),
            const SizedBox(height: 12),
            Text(
              current.isCategory
                  ? 'Expanding this runs a filtered vector search for its members.'
                  : 'Expanding this runs a nearest-neighbour search across the collection.',
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.style,
    required this.muted,
  });

  final String label;
  final String value;
  final TextStyle? style;
  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: muted),
            TextSpan(text: value, style: style),
          ],
        ),
      ),
    );
  }
}
