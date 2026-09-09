import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/news_post.dart';
import '../data/news_repository.dart';
import 'news_state.dart';

class NewsCubit extends Cubit<NewsState> {
  NewsCubit(this._repository) : super(const NewsLoading()) {
    _subscription = _repository.watchNews().listen(
      (posts) => emit(NewsLoaded(posts)),
      onError: (Object error, StackTrace _) => emit(NewsError('$error')),
    );
  }

  final NewsRepository _repository;
  late final StreamSubscription<List<NewsPost>> _subscription;

  Future<void> followRally(String rallyId) => _repository.followRally(rallyId);

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
