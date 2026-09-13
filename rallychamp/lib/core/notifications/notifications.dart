import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Crash and incident alerts: the only thing allowed to make noise and push
/// a heads-up banner over whatever the person is doing.
const incidentChannel = AndroidNotificationChannel(
  'rally_incidents',
  'Incidents and crashes',
  description: 'Urgent alerts from a rally you follow.',
  importance: Importance.high,
);

/// Routine rally status changes. Deliberately low importance — it lands in
/// the tray silently. A spectator should not get buzzed because lunch
/// started, and if routine changes buzzed like incidents do, people would
/// turn notifications off entirely and miss the one that matters.
const statusChannel = AndroidNotificationChannel(
  'rally_status',
  'Rally status',
  description: 'A rally you follow started, paused or resumed.',
  importance: Importance.low,
);

final _local = FlutterLocalNotificationsPlugin();

/// Registers the notification channels and starts showing messages that
/// arrive while the app is open. Android only creates a channel when the
/// app asks it to, and a channel's importance is fixed once created — the
/// system deliberately won't let an app quietly promote itself to noisy
/// later, so getting these right up front matters.
///
/// Deliberately does *not* ask for permission: that happens when someone
/// follows a rally, where the prompt has an obvious reason, rather than
/// on a cold launch where it reads as a shakedown and gets denied.
Future<void> initializeNotifications() async {
  final android = _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(incidentChannel);
  await android?.createNotificationChannel(statusChannel);

  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // A notification that arrives while the app is backgrounded is drawn by
  // the system on its own; one that arrives while the app is open is not,
  // so it has to be drawn here or it's silently swallowed.
  FirebaseMessaging.onMessage.listen(_showForeground);
}

void _showForeground(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  final channel = message.data['channel'] == incidentChannel.id
      ? incidentChannel
      : statusChannel;

  _local.show(
    id: notification.hashCode,
    title: notification.title,
    body: notification.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: channel == incidentChannel ? Priority.high : Priority.low,
      ),
    ),
  );
}

/// Asks for notification permission, returning whether we ended up with it.
///
/// Android 13 turned notifications into a runtime permission
/// (`POST_NOTIFICATIONS`); below that they were granted at install and this
/// resolves immediately. The grant is stored by the OS, not by us — the
/// user can revoke it in Settings, and Android auto-resets permissions for
/// apps left unused for months — so this is asked fresh each time rather
/// than cached anywhere, and every caller has to cope with "no".
Future<bool> ensureNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}
