import 'package:equatable/equatable.dart';

import '../data/news_post.dart';

sealed class NewsState extends Equatable {
  const NewsState();

  @override
  List<Object?> get props => [];
}

class NewsLoading extends NewsState {
  const NewsLoading();
}

class NewsLoaded extends NewsState {
  const NewsLoaded(this.posts);

  final List<NewsPost> posts;

  @override
  List<Object?> get props => [posts];
}

class NewsError extends NewsState {
  const NewsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
