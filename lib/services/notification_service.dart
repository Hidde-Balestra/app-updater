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

  Future<void> _ensureInitialized({
    void Function(String? payload)? onTap,
  }) async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: onTap == null
          ? null
          : (response) => onTap(response.payload),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Registers [onTap] to fire whenever the user taps a notification while
  /// the app is already running. Called once at app startup — see
  /// [getLaunchPayload] for the case where tapping the notification is what
  /// launches the app in the first place, which this callback never fires
  /// for.
  Future<void> initialize({void Function(String? payload)? onTap}) {
    return _ensureInitialized(onTap: onTap);
  }

  /// The payload of the notification that launched the app from a cold
  /// start (tapping a notification while the app wasn't already running),
  /// or null if the app wasn't launched that way.
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// Shows a single notification summarizing that [appNames] have updates
  /// available. No-op for an empty list. [payload] is handed back to
  /// [initialize]'s `onTap` (or [getLaunchPayload]) when tapped — the sole
  /// updatable app's id when there's exactly one, so the tap can jump
  /// straight to it, or null when there are several (nothing to jump to in
  /// particular, so tapping just opens the app as usual).
  Future<void> showUpdatesAvailable(
    List<String> appNames, {
    String? payload,
  }) async {
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
      id: 0,
      title: title,
      body: appNames.join(', '),
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }
}
