import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/story_repository.dart';
import '../domain/story_model.dart';

final storiesProvider = FutureProvider<List<UserStoryGroup>>((ref) async {
  final repo = ref.read(storyRepositoryProvider);
  return repo.getStories();
});
