import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

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
/// - Auto-fits all nodes within the visible area on first load.
/// - Zoom-in / zoom-out / fit-to-screen buttons in the bottom-right corner.
/// - Pan by dragging anywhere on the graph.
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
  late Graph _graph;
  late FruchtermanReingoldAlgorithm _algorithm;

  final _transformController = TransformationController();
  BoxConstraints? _lastConstraints;
  bool _didFit = false;
  late AnimationController _animCtrl;
  Matrix4? _animStart;
  Matrix4? _animEnd;

  // node id → Memory (leaf nodes)
  final Map<int, Memory> _memoryNodes = {};
  // type → cluster node id
  final Map<String, int> _clusterNodes = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onAnimTick);
    _buildGraph();
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
        _buildGraph();
      });
    }
  }

  // ── Graph construction ────────────────────────────────────────────────────

  void _buildGraph() {
    _graph = Graph()..isTree = false;
    _memoryNodes.clear();
    _clusterNodes.clear();

    final types = widget.memories.map((m) => m.memoryType).toSet();
    var nodeId = 1;
    for (final type in types) {
      _clusterNodes[type] = nodeId++;
      _graph.addNode(Node.Id(_clusterNodes[type]!));
    }

    for (final mem in widget.memories) {
      final memNodeId = nodeId++;
      _memoryNodes[memNodeId] = mem;
      _graph.addNode(Node.Id(memNodeId));
      _graph.addEdge(
        Node.Id(_clusterNodes[mem.memoryType]!),
        Node.Id(memNodeId),
      );
    }

    // Tighter layout: stronger attraction + weaker repulsion keeps nodes
    // from spreading outside the viewport.
    _algorithm = FruchtermanReingoldAlgorithm(
      FruchtermanReingoldConfiguration(
        iterations: 200,
        attractionRate: 0.45,
        attractionPercentage: 0.5,
        repulsionRate: 0.08,
        repulsionPercentage: 0.2,
        clusterPadding: 8,
      ),
    );
  }

  // ── Fit-to-screen ─────────────────────────────────────────────────────────

  /// Reads the actual node positions computed by the algorithm after the first
  /// layout pass and applies a transform that centres + fits the whole graph
  /// within the visible viewport.
  void _fitToScreen({bool animated = false}) {
    final constraints = _lastConstraints;
    if (constraints == null) return;

    final nodes = _graph.nodes;
    if (nodes.isEmpty) return;

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final node in nodes) {
      final pos = node.position;
      minX = math.min(minX, pos.dx);
      maxX = math.max(maxX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxY = math.max(maxY, pos.dy);
    }

    // Add generous padding so labels aren't clipped at the edge.
    const pad = 60.0;
    final graphW = (maxX - minX) + pad * 2;
    final graphH = (maxY - minY) + pad * 2;

    final scaleX = constraints.maxWidth / graphW;
    final scaleY = constraints.maxHeight / graphH;
    final scale = math.min(scaleX, scaleY).clamp(0.05, 1.0);

    // Translation that centres the graph inside the viewport.
    final tx = (constraints.maxWidth - graphW * scale) / 2 - (minX - pad) * scale;
    final ty =
        (constraints.maxHeight - graphH * scale) / 2 - (minY - pad) * scale;

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
    final newScale = (currentScale * factor).clamp(0.05, 4.0);
    final actualFactor = newScale / currentScale;

    final cx = constraints.maxWidth / 2;
    final cy = constraints.maxHeight / 2;

    // Scale around the viewport centre so the view doesn't jump.
    final scaleMatrix = Matrix4.identity()
      ..translate(cx, cy, 0)
      ..scale(actualFactor)
      ..translate(-cx, -cy, 0);

    _transformController.value =
        scaleMatrix * _transformController.value;
  }

  // ── Simple matrix animation ───────────────────────────────────────────────

  void _animateTo(Matrix4 target) {
    _animStart = _transformController.value.clone();
    _animEnd = target;
    _animCtrl.forward(from: 0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.memories.isEmpty) {
      return const Center(
        child: Text(
          'No memories yet.\nKeep chatting!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      _lastConstraints = constraints;

      // After the algorithm has placed nodes on the first frame, fit them.
      if (!_didFit) {
        _didFit = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fitToScreen();
        });
      }

      return Stack(
        children: [
          // ── Scrollable / zoomable graph ─────────────────────────────────
          InteractiveViewer(
            transformationController: _transformController,
            constrained: false,
            // Large boundary so the user can pan freely, but not infinitely.
            boundaryMargin: EdgeInsets.all(
              math.max(constraints.maxWidth, constraints.maxHeight) * 1.5,
            ),
            minScale: 0.05,
            maxScale: 4.0,
            child: GraphView(
              graph: _graph,
              algorithm: _algorithm,
              paint: Paint()
                ..color = Colors.white24
                ..strokeWidth = 1.2
                ..style = PaintingStyle.stroke,
              builder: (Node node) {
                final id = node.key!.value as int;
                final memory = _memoryNodes[id];

                if (memory != null) {
                  return _MemoryNode(
                    memory: memory,
                    onDelete: () => widget.onDelete(memory),
                  );
                }

                final type = _clusterNodes.entries
                    .firstWhere((e) => e.value == id)
                    .key;
                return _ClusterNode(type: type);
              },
            ),
          ),

          // ── Zoom controls overlay ───────────────────────────────────────
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
          const Divider(height: 1, color: Colors.white12, indent: 8, endIndent: 8),
          _ZoomBtn(icon: Icons.remove, tooltip: 'Zoom out', onTap: onZoomOut),
          const Divider(height: 1, color: Colors.white12, indent: 8, endIndent: 8),
          _ZoomBtn(icon: Icons.fit_screen_outlined, tooltip: 'Fit to screen', onTap: onFit),
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
          child: Icon(icon, size: 18, color: Colors.white70),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
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
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              memory.content,
              style: const TextStyle(
                color: Colors.white,
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
