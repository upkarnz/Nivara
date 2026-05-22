import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/memory.dart';
import '../providers/memory_provider.dart';
import '../widgets/memory_graph_view.dart';
import '../widgets/memory_tile.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  bool _listOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  Future<void> _load() async {
    final token = await _getToken();
    if (token == null) return;
    await ref.read(memoryNotifierProvider.notifier).loadMemories(token);
  }

  Future<void> _delete(Memory memory) async {
    final token = await _getToken();
    if (token == null) return;
    ref.read(memoryNotifierProvider.notifier).deleteMemory(token, memory.id);
  }

  Future<void> _update(Memory memory, String newContent) async {
    final token = await _getToken();
    if (token == null) return;
    ref
        .read(memoryNotifierProvider.notifier)
        .updateMemory(token, memory.id, newContent);
  }

  void _showEditDialog(Memory memory) {
    final controller = TextEditingController(text: memory.content);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Edit Memory', style: TextStyle(color: cs.onSurface)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: cs.onSurface),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Memory content…',
              hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty && trimmed != memory.content) {
                  _update(memory, trimmed);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoryNotifierProvider);
    final screenW = MediaQuery.sizeOf(context).width;
    final panelW = screenW * 0.78;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Memory Graph',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _listOpen ? Icons.hub_outlined : Icons.list_outlined,
              color: _listOpen ? cs.primary : cs.onSurfaceVariant,
            ),
            tooltip: _listOpen ? 'Show graph' : 'Show list',
            onPressed: () => setState(() => _listOpen = !_listOpen),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: memoriesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Could not load memories\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (memories) => Stack(
          children: [
            // ── Full-screen graph ────────────────────────────────────────────
            Positioned.fill(
              child: memories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hub_outlined,
                              size: 60, color: cs.onSurfaceVariant.withValues(alpha: 0.15)),
                          const SizedBox(height: 16),
                          Text(
                            'No memories yet.\nKeep chatting with BJ!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : MemoryGraphView(
                      memories: memories,
                      onDelete: _delete,
                    ),
            ),

            // ── Scrim — only covers the graph area (left of panel) ──────────
            if (_listOpen)
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: panelW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _listOpen = false),
                ),
              ),

            // ── Right sliding list panel ─────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _listOpen ? 0 : -panelW,
              width: panelW,
              child: _ListPanel(
                memories: memories,
                onDelete: _delete,
                onEdit: _showEditDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Right panel ───────────────────────────────────────────────────────────────

class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.memories,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Memory> memories;
  final void Function(Memory) onDelete;
  final void Function(Memory) onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(-6, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Text(
                  'ALL MEMORIES',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${memories.length}',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: cs.outlineVariant, height: 1),
          Expanded(
            child: memories.isEmpty
                ? Center(
                    child: Text(
                      'No memories yet',
                      style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    ),
                  )
                : ListView.separated(
                    itemCount: memories.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
                    itemBuilder: (context, index) {
                      final mem = memories[index];
                      return MemoryTile(
                        memory: mem,
                        onDelete: () => onDelete(mem),
                        onEdit: () => onEdit(mem),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
