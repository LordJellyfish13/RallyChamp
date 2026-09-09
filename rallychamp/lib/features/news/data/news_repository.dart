import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'news_post.dart';

class NewsRepository {
  NewsRepository({FirebaseFirestore? firestore, FirebaseMessaging? messaging})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Stream<List<NewsPost>> watchNews() {
    return _firestore
        .collection('news')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(NewsPost.fromFirestore).toList());
  }

  /// Spectator "apply" flow: a no-friction follow, just an FCM topic
  /// subscription. No account, no Firestore write — see dev_notes.md §4/§9.
  Future<void> followRally(String rallyId) {
    return _messaging.subscribeToTopic('rally_$rallyId');
  }

  Future<void> unfollowRally(String rallyId) {
    return _messaging.unsubscribeFromTopic('rally_$rallyId');
  }
}
