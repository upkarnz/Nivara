import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/memory_provider.dart';
import '../widgets/memory_tile.dart';
import '../widgets/memory_graph_view.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  bool _showGraph = false;

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

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoryNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Memories'),
        actions: [
          memoriesAsync.maybeWhen(
            data: (memories) => memories.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      _showGraph ? Icons.list_outlined : Icons.hub_outlined,
                    ),
                    tooltip: _showGraph ? 'List view' : 'Graph view',
                    onPressed: () => setState(() => _showGraph = !_showGraph),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: memoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (memories) {
          if (memories.isEmpty) {
            return const Center(
              child: Text('No memories yet. Keep chatting!'),
            );
          }
          if (_showGraph) {
            return MemoryGraphView(
              memories: memories,
              onDelete: (memory) async {
                final token = await _getToken();
                if (token == null) return;
                ref
                    .read(memoryNotifierProvider.notifier)
                    .deleteMemory(token, memory.id);
              },
            );
          }
          return ListView.builder(
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index];
              return MemoryTile(
                memory: memory,
                onDelete: () async {
                  final token = await _getToken();
                  if (token == null) return;
                  ref
                      .read(memoryNotifierProvider.notifier)
                      .deleteMemory(token, memory.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}
