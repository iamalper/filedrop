import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:num_remap/num_remap.dart';

final _localNotifications = FlutterLocalNotificationsPlugin();

enum Type { download, upload }

///Create notification details for updating or creating progress notification
///
///Make sure [progress] within range 0 to 100
AndroidNotificationDetails _androidDetails(int progress, Type type) {
  assert(progress.isWithinRange(0, 100));
  final id = switch (type) {
    Type.download => "download_progress",
    Type.upload => "upload_progress",
  };
  final name = switch (type) {
    Type.download => "Download progress for FileDrop",
    Type.upload => "Upload progress for FileDrop",
  };
  return AndroidNotificationDetails(id, name,
      priority: Priority.low,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      channelAction: AndroidNotificationChannelAction.update,
      category: AndroidNotificationCategory.progress);
}

///Show or update download progress notification.
///
///Make sure [progress] within range 0 to 100
Future<void> showDownload(int progress) => _localNotifications.show(
    0,
    null,
    null,
    NotificationDetails(android: _androidDetails(progress, Type.download)));

///Show or update upload progress notification.
///
///Make sure [progress] within range 0 to 100
Future<void> showUpload(int progress) => _localNotifications.show(1, null, null,
    NotificationDetails(android: _androidDetails(progress, Type.upload)));

Future<void> cancelDownload() => _localNotifications.cancel(0);

Future<void> cancelUpload() => _localNotifications.cancel(1);

Future<bool> initalise() async {
  final status = await _localNotifications.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings("@mipmap/ic_launcher")));
  return status ?? false;
}
