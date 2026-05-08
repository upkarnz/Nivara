import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/memory_provider.dart';
import '../widgets/memory_tile.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;
    ref.read(memoryNotifierProvider.notifier).loadMemories(token);
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoryNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Memories')),
      body: memoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (memories) {
          if (memories.isEmpty) {
            return const Center(
              child: Text('No memories yet. Keep chatting!'),
            );
          }
          return ListView.builder(
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index];
              return MemoryTile(
                memory: memory,
                onDelete: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final token = await user.getIdToken();
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
