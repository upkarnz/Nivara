import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_model_provider.dart';

const _models = [
  ('claude', 'Claude (Anthropic)', 'Default — best quality'),
  ('gemini', 'Gemini (Google)', 'Fast and capable'),
  ('openai', 'GPT-4o (OpenAI)', 'Strong general reasoning'),
];

class ModelSelectorWidget extends ConsumerWidget {
  const ModelSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(aiModelNotifierProvider);

    return modelAsync.when(
      loading: () => const CircularProgressIndicator.adaptive(),
      error: (e, _) => Text('Error: $e'),
      data: (selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _models.map((model) {
          final (value, label, subtitle) = model;
          return RadioListTile<String>(
            value: value,
            groupValue: selected,
            title: Text(label),
            subtitle: Text(subtitle),
            onChanged: (v) {
              if (v != null) {
                ref.read(aiModelNotifierProvider.notifier).setModel(v);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
