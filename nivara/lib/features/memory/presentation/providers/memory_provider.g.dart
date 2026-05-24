// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userMemoriesHash() => r'7a63fb4f2b5ad6379e9624e859267e12f6325c76';

/// Auto-fetches the user's memories on first access and keeps them alive for
/// the session. Used by ChatNotifier to inject memory context into every
/// AI request so the agent can recall past conversations and user preferences.
///
/// Copied from [userMemories].
@ProviderFor(userMemories)
final userMemoriesProvider = FutureProvider<List<Memory>>.internal(
  userMemories,
  name: r'userMemoriesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userMemoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserMemoriesRef = FutureProviderRef<List<Memory>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
