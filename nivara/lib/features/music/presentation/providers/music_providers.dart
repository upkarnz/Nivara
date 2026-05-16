import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nivara/features/music/data/local_music_repository.dart';
import 'package:nivara/features/music/data/local_music_service.dart';
import 'package:nivara/features/music/domain/music_repository.dart';
import 'package:nivara/features/music/domain/music_service.dart';

final musicServiceProvider = Provider<MusicService>(
  (ref) => LocalMusicService(),
);

final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => const LocalMusicRepository(),
);
