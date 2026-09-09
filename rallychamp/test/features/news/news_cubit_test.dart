import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/news/bloc/news_cubit.dart';
import 'package:rallychamp/features/news/bloc/news_state.dart';
import 'package:rallychamp/features/news/data/news_post.dart';
import 'package:rallychamp/features/news/data/news_repository.dart';

class _FakeNewsRepository implements NewsRepository {
  final _controller = StreamController<List<NewsPost>>();
  final List<String> followedRallyIds = [];

  @override
  Stream<List<NewsPost>> watchNews() => _controller.stream;

  @override
  Future<void> followRally(String rallyId) async {
    followedRallyIds.add(rallyId);
  }

  @override
  Future<void> unfollowRally(String rallyId) async {
    followedRallyIds.remove(rallyId);
  }

  void emit(List<NewsPost> posts) => _controller.add(posts);
  void emitError(Object error) => _controller.addError(error);
  void dispose() => _controller.close();
}

NewsPost _samplePost({String id = 'p1', String? rallyId}) {
  return NewsPost(
    id: id,
    rallyId: rallyId,
    type: NewsPostType.announcement,
    title: 'Test post',
    body: 'Body',
    imageUrl: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('NewsCubit', () {
    test('starts in loading state', () async {
      final repo = _FakeNewsRepository();
      final cubit = NewsCubit(repo);

      expect(cubit.state, isA<NewsLoading>());

      await cubit.close();
      repo.dispose();
    });

    test('emits NewsLoaded when the repository stream emits posts', () async {
      final repo = _FakeNewsRepository();
      final cubit = NewsCubit(repo);

      repo.emit([_samplePost(rallyId: 'rally-1')]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<NewsLoaded>());
      expect((cubit.state as NewsLoaded).posts, hasLength(1));

      await cubit.close();
      repo.dispose();
    });

    test('emits NewsError when the repository stream errors', () async {
      final repo = _FakeNewsRepository();
      final cubit = NewsCubit(repo);

      repo.emitError(Exception('offline'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<NewsError>());

      await cubit.close();
      repo.dispose();
    });

    test('followRally delegates to the repository', () async {
      final repo = _FakeNewsRepository();
      final cubit = NewsCubit(repo);

      await cubit.followRally('rally-1');

      expect(repo.followedRallyIds, contains('rally-1'));

      await cubit.close();
      repo.dispose();
    });
  });
}
