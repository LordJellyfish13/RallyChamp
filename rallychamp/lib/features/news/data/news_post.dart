import 'package:cloud_firestore/cloud_firestore.dart';

enum NewsPostType { newRally, victory, announcement, recruiting }

NewsPostType _typeFromFirestore(String? value) {
  switch (value) {
    case 'new_rally':
      return NewsPostType.newRally;
    case 'victory':
      return NewsPostType.victory;
    case 'recruiting':
      return NewsPostType.recruiting;
    default:
      return NewsPostType.announcement;
  }
}

class NewsPost {
  const NewsPost({
    required this.id,
    required this.rallyId,
    required this.type,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
  });

  factory NewsPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return NewsPost(
      id: doc.id,
      rallyId: data['rallyId'] as String?,
      type: _typeFromFirestore(data['type'] as String?),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  final String id;
  final String? rallyId;
  final NewsPostType type;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
}
