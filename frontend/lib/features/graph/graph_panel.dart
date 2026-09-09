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
const _minSeparation = 40.0;
const _maxSpeed = 14.0;
const _panelHeight = 460.0;
const _hop = 115.0;

const _kindLabels = {'skill_group': 'skill group'};

String kindLabel(String kind) => _kindLabels[kind] ?? kind;

Color kindColour(String kind, ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  return switch (kind) {
    'category' => scheme.primary,
    'project' => dark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
    'role' => dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    'highlight' => dark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6),
    'skill_group' => dark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
    'skill' => dark ? const Color(0xFFD8B4FE) : const Color(0xFFA855F7),
    'bio' ||
    'education' => dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
    _ => scheme.onSurfaceVariant,
  };
}

class _Body {
  _Body(this.node, this.x, this.y, {this.parent});

  final GraphNode node;
  final String? parent;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  bool expanded = false;
  bool pinned = false;

  double get radius => switch (node.kind) {
    'category' => 9,
    'skill_group' || 'project' || 'role' => 7,
    _ => 5.5,
  };

  bool get prominent => radius >= 7;
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
      setState(() => _place(origin, neighbours));
    } catch (_) {
      origin.expanded = false;
    }
  }

  void _place(_Body origin, List<GraphNode> neighbours) {
    final parent = origin.parent == null ? null : _bodies[origin.parent];
    final fresh = neighbours.where((n) => _bodies[n.id] == null).toList();
    final outward = parent == null
        ? 0.0
        : atan2(origin.y - parent.y, origin.x - parent.x);
    final spread = parent == null ? 2 * pi : pi * 1.15;
    for (final (i, node) in fresh.indexed) {
      final t = parent == null
          ? i / fresh.length
          : (fresh.length == 1 ? 0.5 : i / (fresh.length - 1)) - 0.5;
      final angle = outward + t * spread + (_random.nextDouble() - 0.5) * 0.15;
      final reach = _hop + _random.nextDouble() * 20;
      _bodies[node.id] = _Body(
        node,
        origin.x + cos(angle) * reach,
        origin.y + sin(angle) * reach,
        parent: origin.node.id,
      );
    }
    for (final node in neighbours) {
      final already = _edges.any(
        (e) =>
            (e.from == origin.node.id && e.to == node.id) ||
            (e.from == node.id && e.to == origin.node.id),
      );
      if (!already) {
        _edges.add(_Edge(origin.node.id, node.id, node.score ?? 0.2));
      }
    }
  }

  void _collapse(String id) {
    bool under(String? cursor) {
      while (cursor != null) {
        if (cursor == id) return true;
        cursor = _bodies[cursor]?.parent;
      }
      return false;
    }

    final doomed = {
      for (final body in _bodies.values)
        if (body.node.id != id && under(body.parent)) body.node.id,
    };
    setState(() {
      _bodies.removeWhere((key, _) => doomed.contains(key));
      _edges.removeWhere(
        (e) => doomed.contains(e.from) || doomed.contains(e.to),
      );
      _bodies[id]?.expanded = false;
      if (_hovered != null && doomed.contains(_hovered)) _hovered = null;
    });
  }

  List<String> _path(String id) {
    final titles = <String>[];
    String? cursor = id;
    while (cursor != null) {
      final body = _bodies[cursor];
      if (body == null) break;
      titles.insert(0, body.node.title);
      cursor = body.parent;
    }
    return titles;
  }

  bool _hasChildren(String id) => _bodies.values.any((b) => b.parent == id);

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
      final rest = _hop + 20 - 50 * edge.weight.clamp(0.0, 1.0);
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

    final limitX = _size.width / 2 - 30;
    final limitY = _size.height / 2 - 24;
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
      body.x = (body.x + body.vx * step).clamp(-limitX, limitX);
      body.y = (body.y + body.vy * step).clamp(-limitY, limitY);
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
          'Titan and stored in a Qdrant collection. Start at the ${widget.seed} '
          'hub and tap outward: a project opens the skills it leans on, a role '
          'opens what shipped in it, a skill opens the projects that used it. '
          'Each hop is a vector search filtered to one kind of point and ordered '
          'by cosine similarity, so what appears is whatever sits closest in '
          'embedding space, not a hand-written list. Hover to read a point, drag '
          'to rearrange, and expand or collapse from the inspector.\n\n'
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
          final selected = _selected == null ? null : _bodies[_selected];
          final inspector = _Inspector(
            body: selected,
            path: selected == null ? const [] : _path(selected.node.id),
            kinds: {for (final b in _bodies.values) b.node.kind},
            total: _bodies.length,
            edges: _edges.length,
            canCollapse:
                selected != null &&
                selected.expanded &&
                _hasChildren(selected.node.id),
            onExpand: selected == null ? null : () => _expand(selected.node.id),
            onCollapse: selected == null
                ? null
                : () => _collapse(selected.node.id),
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
                      scheme: colorScheme,
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
    required this.scheme,
    required this.tooltipBorder,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Map<String, _Body> bodies;
  final List<_Edge> edges;
  final String? selected;
  final String? hovered;
  final ColorScheme scheme;
  final Color tooltipBorder;

  static final _labels = <String, TextPainter>{};

  TextPainter _labelFor(String text, Color colour, {int limit = 26}) {
    return _labels.putIfAbsent('$text|${colour.toARGB32()}|$limit', () {
      final painter = TextPainter(
        text: TextSpan(
          text: text.length > limit ? '${text.substring(0, limit - 1)}…' : text,
          style: TextStyle(color: colour, fontSize: 10.5, height: 1.2),
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
      line.color = kindColour(
        b.node.kind,
        scheme,
      ).withValues(alpha: (0.18 + edge.weight * 0.5).clamp(0.14, 0.7));
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), line);
    }

    for (final body in bodies.values) {
      final colour = kindColour(body.node.kind, scheme);
      final centre = Offset(body.x, body.y);
      if (body.node.id == selected) {
        canvas.drawCircle(
          centre,
          body.radius + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colour,
        );
      }
      canvas.drawCircle(
        centre,
        body.radius,
        Paint()..color = body.expanded ? colour : colour.withValues(alpha: 0.8),
      );
      if (!body.expanded && body.node.kind != 'category') {
        canvas.drawCircle(
          centre,
          body.radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = colour,
        );
      }
      if (body.node.id != hovered) {
        final painter = _labelFor(
          body.node.title,
          body.prominent
              ? scheme.onSurface
              : scheme.onSurfaceVariant.withValues(alpha: 0.85),
        );
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
      scheme.onSurface,
      maxTextWidth,
      12.5,
      FontWeight.w600,
    );
    final detail = [
      kindLabel(body.node.kind),
      if (body.node.relation != null) body.node.relation!,
      if (body.node.score != null && body.node.score! > 0)
        'cosine ${body.node.score!.toStringAsFixed(3)}',
      if (body.expanded)
        'tap for detail'
      else if (body.node.expands.isNotEmpty)
        'tap to open ${body.node.expands}',
    ].join('  ·  ');
    final subtitle = _wrapped(
      detail,
      scheme.onSurfaceVariant,
      maxTextWidth,
      11,
      FontWeight.w400,
    );

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
    canvas.drawRRect(box, Paint()..color = scheme.surface);
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
      oldDelegate.scheme != scheme;
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.body,
    required this.path,
    required this.kinds,
    required this.total,
    required this.edges,
    required this.canCollapse,
    required this.onExpand,
    required this.onCollapse,
  });

  final _Body? body;
  final List<String> path;
  final Set<String> kinds;
  final int total;
  final int edges;
  final bool canCollapse;
  final VoidCallback? onExpand;
  final VoidCallback? onCollapse;

  static const _hidden = {'deck', 'text', 'media'};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mono = textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.55);
    final muted = mono?.copyWith(color: colorScheme.onSurfaceVariant);

    final current = body;
    final node = current?.node;
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
          Text('$total points on screen · $edges edges', style: muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final kind in kinds.toList()..sort())
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: kindColour(kind, colorScheme),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(kindLabel(kind), style: muted),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (current == null || node == null)
            Text('Tap a point to inspect it.', style: muted)
          else ...[
            if (path.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(path.join('  ›  '), style: muted),
              ),
            Text(
              node.title,
              style: mono?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'kind',
              value: kindLabel(node.kind),
              style: mono,
              muted: muted,
            ),
            if (node.relation != null)
              _Row(
                label: 'shown as',
                value: node.relation!,
                style: mono,
                muted: muted,
              ),
            if (node.score != null && node.score! > 0)
              _Row(
                label: 'cosine',
                value: node.score!.toStringAsFixed(4),
                style: mono,
                muted: muted,
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              children: [
                if (node.payload['deck'] != null)
                  _Action(
                    label: 'open the full write-up >',
                    onTap: () => context.go('${node.payload['deck']}'),
                  ),
                if (!current.expanded &&
                    node.expands.isNotEmpty &&
                    onExpand != null)
                  _Action(label: 'expand >', onTap: onExpand!),
                if (canCollapse && onCollapse != null)
                  _Action(label: 'collapse <', onTap: onCollapse!),
              ],
            ),
            const SizedBox(height: 10),
            for (final entry in node.payload.entries)
              if (!_hidden.contains(entry.key) &&
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
              node.expands.isEmpty
                  ? 'This point has nothing further to open.'
                  : 'Expanding this runs a vector search from its embedding, '
                        'filtered by kind, for ${node.expands}.',
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
