import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(PoolServerTaskHandler());
}

class PoolServerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Background worker task initialized
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat or keepalive tick
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup on service stop
  }
}

class ForegroundServiceManager {
  static bool _isInitialized = false;

  /// Initializes the notification channel and wake lock configurations for Android.
  static Future<void> initialize() async {
    if (!Platform.isAndroid || _isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'p2p_file_pool_foreground',
        channelName: 'P2P File Pool Server',
        channelDescription: 'Persistent LAN file pool service and discovery socket',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
  }

  /// Starts the persistent foreground service with notification and Wi-Fi lock.
  static Future<bool> start({
    String notificationTitle = 'P2P File Pool Active',
    String notificationText = 'Serving shared folders on port 45454',
  }) async {
    if (!Platform.isAndroid) return true;

    await initialize();

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: notificationTitle,
        notificationText: notificationText,
      );
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      callback: startForegroundCallback,
    );

    return result is ServiceRequestSuccess;
  }

  /// Stops the background service.
  static Future<bool> stop() async {
    if (!Platform.isAndroid) return true;

    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  /// Returns whether the service is currently running.
  static Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    return await FlutterForegroundTask.isRunningService;
  }
}
