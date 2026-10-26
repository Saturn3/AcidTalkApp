import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifiche native: Android, iOS, macOS, Windows (toast) e Linux.
class Notifier {
  Notifier._();
  static final instance = Notifier._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  void Function(String payload)? onTap;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    // Su Linux le notifiche passano da D-Bus: senza sessione D-Bus l'app funziona comunque, senza notifiche.
    if (Platform.isLinux && (Platform.environment['DBUS_SESSION_BUS_ADDRESS'] ?? '').isEmpty) return;
    try {
      const darwin = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
          linux: LinuxInitializationSettings(defaultActionName: 'Apri'),
          windows: WindowsInitializationSettings(appName: 'AcidTalk', appUserModelId: 'it.acidsoft.acidtalk', guid: '6f3c2a51-8a4e-4c1b-9d9b-2b7f4c0e5a17'),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) onTap?.call(r.payload!);
        },
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifiche non disponibili: $e');
    }
  }

  /// Chiede il permesso (Android 13+, iOS, macOS). Restituisce true se concesso o non necessario.
  Future<bool> requestPermission() async {
    await init();
    try {
      if (Platform.isAndroid) {
        return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? true;
      }
      if (Platform.isIOS) {
        return await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      if (Platform.isMacOS) {
        return await _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (_) {}
    return true;
  }

  Future<void> show({required int id, required String title, required String body, String? payload}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id & 0x7fffffff,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('messages', 'Messaggi', channelDescription: 'Menzioni, messaggi diretti e risposte', importance: Importance.high, priority: Priority.high, category: AndroidNotificationCategory.message),
          iOS: DarwinNotificationDetails(threadIdentifier: 'acidtalk'),
          macOS: DarwinNotificationDetails(threadIdentifier: 'acidtalk'),
        ),
      );
    } catch (e) {
      debugPrint('Notifica non mostrata: $e');
    }
  }
}
