import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows the "you have updates" local notification raised by
/// [BackgroundUpdateChecker]. A thin wrapper around
/// flutter_local_notifications, kept separate so the checker's own logic
/// (which apps count as updatable) stays testable without a real platform
/// channel.
class NotificationService {
  static const _channelId = 'update_checks';
  static const _channelName = 'Update checks';
  static const _channelDescription =
      'Notifies you when a background check finds app updates.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Shows a single notification summarizing that [appNames] have updates
  /// available. No-op for an empty list.
  Future<void> showUpdatesAvailable(List<String> appNames) async {
    if (appNames.isEmpty) return;
    await _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final title = appNames.length == 1
        ? '${appNames.first} has an update'
        : '${appNames.length} apps have an update';

    await _plugin.show(
      0,
      title,
      appNames.join(', '),
      const NotificationDetails(android: androidDetails),
    );
  }
}
