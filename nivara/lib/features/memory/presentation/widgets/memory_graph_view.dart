import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/memory.dart';

/// Color + label for each memory type.
const _typeColors = <String, Color>{
  'personal_fact': Color(0xFF60A5FA),
  'preference': Color(0xFFF472B6),
  'goal': Color(0xFF34D399),
  'work_context': Color(0xFFFB923C),
  'relationship': Color(0xFFA78BFA),
  'routine': Color(0xFF22D3EE),
  'decision': Color(0xFFFBBF24),
  'emotional_signal': Color(0xFFE879F9),
};

const _typeLabels = <String, String>{
  'personal_fact': 'Personal',
  'preference': 'Preferences',
  'goal': 'Goals',
  'work_context': 'Work',
  'relationship': 'Relationships',
  'routine': 'Routines',
  'decision': 'Decisions',
  'emotional_signal': 'Emotions',
};

Color _colorFor(String type) => _typeColors[type] ?? const Color(0xFF94A3B8);
String _labelFor(String type) =>
    _typeLabels[type] ?? type.replaceAll('_', ' ');

/// Obsidian-style force-directed graph for memories.
/// Uses a manual circular layout: cluster nodes in a circle, memory nodes
/// orbiting their cluster. No third-party layout algorithm — predictable,
/// readable at any scale.
class MemoryGraphView extends StatefulWidget {
  const MemoryGraphView({
    super.key,
    required this.memories,
    required this.onDelete,
  });

  final List<Memory> memories;
  final void Function(Memory) onDelete;

  @override
  State<MemoryGraphView> createState() => _MemoryGraphViewState();
}

class _MemoryGraphViewState extends State<MemoryGraphView>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  BoxConstraints? _lastConstraints;
  bool _didFit = false;
  late AnimationController _animCtrl;
  Matrix4? _animStart;
  Matrix4? _animEnd;

  // Computed layout
  final Map<String, Offset> _clusterPositions = {};
  final Map<Memory, Offset> _memoryPositions = {};
  double _graphW = 400;
  double _graphH = 400;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onAnimTick);
    _computeLayout();
  }

  void _onAnimTick() {
    final start = _animStart;
    final end = _animEnd;
    if (start == null || end == null) return;
    final t = Curves.easeOut.transform(_animCtrl.value);
    _transformController.value = Matrix4Tween(begin: start, end: end).lerp(t);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MemoryGraphView old) {
    super.didUpdateWidget(old);
    if (old.memories != widget.memories) {
      setState(() {
        _didFit = false;
        _computeLayout();
      });
    }
  }

  // ── Circular layout ───────────────────────────────────────────────────────

  void _computeLayout() {
    _clusterPositions.clear();
    _memoryPositions.clear();

    final types = widget.memories.map((m) => m.memoryType).toSet().toList();
    if (types.isEmpty) return;

    // Scale cluster radius based on number of types so labels don't overlap.
    final clusterR = math.max(110.0, types.length * 36.0);
    // Memory nodes orbit at a fixed distance from their cluster.
    const memR = 58.0;
    const cx = 0.0, cy = 0.0;

    for (var i = 0; i < types.length; i++) {
      final type = types[i];
      final clusterAngle = (i / types.length) * 2 * math.pi - math.pi / 2;
      final clusterPos = Offset(
        cx + clusterR * math.cos(clusterAngle),
        cy + clusterR * math.sin(clusterAngle),
      );
      _clusterPositions[type] = clusterPos;

      final mems = widget.memories.where((m) => m.memoryType == type).toList();
      for (var j = 0; j < mems.length; j++) {
        final double memAngle;
        if (mems.length == 1) {
          // Single memory: place on far side from center
          memAngle = clusterAngle + math.pi;
        } else {
          // Fan out around the radial direction
          const fanSpread = math.pi * 0.9;
          memAngle = clusterAngle +
              math.pi -
              fanSpread / 2 +
              (j / (mems.length - 1)) * fanSpread;
        }
        _memoryPositions[mems[j]] = Offset(
          clusterPos.dx + memR * math.cos(memAngle),
          clusterPos.dy + memR * math.sin(memAngle),
        );
      }
    }

    // Compute bounding box → canvas size
    final allPts = [
      ..._clusterPositions.values,
      ..._memoryPositions.values,
    ];
    const pad = 80.0;
    final minX = allPts.map((p) => p.dx).reduce(math.min);
    final maxX = allPts.map((p) => p.dx).reduce(math.max);
    final minY = allPts.map((p) => p.dy).reduce(math.min);
    final maxY = allPts.map((p) => p.dy).reduce(math.max);
    _graphW = (maxX - minX) + pad * 2 + 120; // extra for cluster label width
    _graphH = (maxY - minY) + pad * 2 + 40;
  }

  // ── Fit-to-screen ─────────────────────────────────────────────────────────

  void _fitToScreen({bool animated = false}) {
    final constraints = _lastConstraints;
    if (constraints == null) return;
    if (_graphW <= 0 || _graphH <= 0) return;

    const margin = 24.0;
    final scaleX = (constraints.maxWidth - margin * 2) / _graphW;
    final scaleY = (constraints.maxHeight - margin * 2) / _graphH;
    final scale = math.min(scaleX, scaleY).clamp(0.1, 3.0);

    final tx = (constraints.maxWidth - _graphW * scale) / 2;
    final ty = (constraints.maxHeight - _graphH * scale) / 2;

    final target = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);

    if (animated) {
      _animateTo(target);
    } else {
      _transformController.value = target;
    }
  }

  // ── Zoom helpers ──────────────────────────────────────────────────────────

  void _zoomIn() => _scaleBy(1.35);
  void _zoomOut() => _scaleBy(1 / 1.35);

  void _scaleBy(double factor) {
    final constraints = _lastConstraints;
    if (constraints == null) return;

    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.05, 6.0);
    final actualFactor = newScale / currentScale;

    final cx = constraints.maxWidth / 2;
    final cy = constraints.maxHeight / 2;

    final scaleMatrix = Matrix4.identity()
      ..translate(cx, cy, 0)
      ..scale(actualFactor)
      ..translate(-cx, -cy, 0);

    _transformController.value = scaleMatrix * _transformController.value;
  }

  void _animateTo(Matrix4 target) {
    _animStart = _transformController.value.clone();
    _animEnd = target;
    _animCtrl.forward(from: 0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.memories.isEmpty) {
      return Center(
        child: Text(
          'No memories yet.\nKeep chatting!',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      _lastConstraints = constraints;

      if (!_didFit) {
        _didFit = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fitToScreen();
        });
      }

      // Compute offset so all positions are in positive canvas space
      final allPts = [
        ..._clusterPositions.values,
        ..._memoryPositions.values,
      ];
      if (allPts.isEmpty) return const SizedBox();

      const pad = 80.0;
      final minX = allPts.map((p) => p.dx).reduce(math.min);
      final minY = allPts.map((p) => p.dy).reduce(math.min);
      final ox = pad - minX;
      final oy = pad - minY;

      // Build edge list (cluster center → memory center)
      final edges = <(Offset, Offset)>[
        for (final mem in widget.memories)
          if (_clusterPositions[mem.memoryType] != null &&
              _memoryPositions[mem] != null)
            (
              Offset(
                _clusterPositions[mem.memoryType]!.dx + ox,
                _clusterPositions[mem.memoryType]!.dy + oy,
              ),
              Offset(
                _memoryPositions[mem]!.dx + ox,
                _memoryPositions[mem]!.dy + oy,
              ),
            ),
      ];

      final edgePaint = Paint()
        ..color = cs.outlineVariant
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      return Stack(
        children: [
          // ── Scrollable / zoomable graph ─────────────────────────────
          SizedBox.expand(
            child: InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              boundaryMargin: EdgeInsets.all(
                math.max(constraints.maxWidth, constraints.maxHeight) * 2.0,
              ),
              minScale: 0.1,
              maxScale: 6.0,
              child: SizedBox(
                width: _graphW,
                height: _graphH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Edge layer
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EdgePainter(edges: edges, edgePaint: edgePaint),
                      ),
                    ),
                    // Cluster nodes
                    for (final entry in _clusterPositions.entries)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Transform.translate(
                          offset: Offset(
                            entry.value.dx + ox,
                            entry.value.dy + oy,
                          ),
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, -0.5),
                            child: _ClusterNode(type: entry.key),
                          ),
                        ),
                      ),
                    // Memory nodes
                    for (final entry in _memoryPositions.entries)
                      Builder(builder: (ctx) {
                        final size = 14.0 + entry.key.confidence * 8;
                        return Positioned(
                          left: entry.value.dx + ox - size / 2,
                          top: entry.value.dy + oy - size / 2,
                          child: _MemoryNode(
                            memory: entry.key,
                            onDelete: () => widget.onDelete(entry.key),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),

          // ── Zoom controls overlay ───────────────────────────────────
          Positioned(
            bottom: 24,
            right: 16,
            child: _ZoomControls(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onFit: () => _fitToScreen(animated: true),
            ),
          ),
        ],
      );
    });
  }
}

// ── Edge painter ──────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  const _EdgePainter({required this.edges, required this.edgePaint});
  final List<(Offset, Offset)> edges;
  final Paint edgePaint;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to) in edges) {
      canvas.drawLine(from, to, edgePaint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.edges != edges;
}

// ── Zoom control buttons ──────────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
          Divider(height: 1, color: cs.outlineVariant, indent: 8, endIndent: 8),
          _ZoomBtn(icon: Icons.remove, tooltip: 'Zoom out', onTap: onZoomOut),
          Divider(height: 1, color: cs.outlineVariant, indent: 8, endIndent: 8),
          _ZoomBtn(
              icon: Icons.fit_screen_outlined,
              tooltip: 'Fit to screen',
              onTap: onFit),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ── Cluster hub (type label) ──────────────────────────────────────────────────

class _ClusterNode extends StatelessWidget {
  const _ClusterNode({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: Text(
        _labelFor(type),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Memory leaf node ──────────────────────────────────────────────────────────

class _MemoryNode extends StatelessWidget {
  const _MemoryNode({required this.memory, required this.onDelete});
  final Memory memory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(memory.memoryType);
    final size = 14.0 + memory.confidence * 8;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.25),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final color = _colorFor(memory.memoryType);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.6), blurRadius: 6)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _labelFor(memory.memoryType),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(memory.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              memory.content,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.redAccent),
                  label: const Text('Forget',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
