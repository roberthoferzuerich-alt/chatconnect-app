import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/story_model.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(ref.read(apiClientProvider));
});

class StoryRepository {
  final Dio _dio;

  StoryRepository(this._dio);

  Future<List<UserStoryGroup>> getStories() async {
    final res = await _dio.get('stories');
    return (res.data as List).map((e) => UserStoryGroup.fromJson(e)).toList();
  }

  Future<Story> uploadStory(String imagePath, {String? caption}) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath),
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });

    final res = await _dio.post(
      'stories',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'Accept': 'application/json'},
      ),
    );
    return Story.fromJson(res.data);
  }

  Future<void> deleteStory(int storyId) async {
    await _dio.delete('stories/$storyId');
  }

  Future<void> viewStory(
    int storyId, {
    String? reaction,
    String? message,
  }) async {
    await _dio.post(
      'stories/$storyId/view',
      data: {
        if (reaction != null) 'reaction': reaction,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
  }
}
