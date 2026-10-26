import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Si usa il token di registrazione FCM classico (getToken/onTokenRefresh), accettato da FCM HTTP v1
// usato dal server; register()/onRegistered di firebase_messaging 17 restituiscono invece l'ID installazione.
// ignore_for_file: deprecated_member_use
import 'package:flutter/foundation.dart';

import '../api/api.dart';

/// Notifiche push con Firebase Cloud Messaging (Android, iOS, macOS).
///
/// Le chiavi del progetto Firebase si passano in compilazione, senza google-services.json:
///   --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_PROJECT_ID=...
///   --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_ANDROID_APP_ID=...
///   --dart-define=FIREBASE_APPLE_APP_ID=...  (iOS/macOS)
/// Senza queste chiavi l'app funziona normalmente con le sole notifiche locali.
/// Per Windows/Linux usare tool/no_firebase.sh (vedi README): questo file viene sostituito da push_stub.dart.
class Push {
  Push._();
  static final instance = Push._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _appleAppId = String.fromEnvironment('FIREBASE_APPLE_APP_ID');
  static const _bundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'it.acidsoft.acidtalk');

  /// Apre il canale indicato nel payload quando l'utente tocca la notifica.
  void Function(int channelId)? onOpen;

  /// Chiamato quando arriva una push con l'app in primo piano (l'app aggiorna subito i dati).
  void Function()? onForegroundMessage;

  String? _token;
  String? status;
  bool _initialized = false;

  String get _appId => Platform.isAndroid ? _androidAppId : _appleAppId;

  bool get available => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) && _apiKey.isNotEmpty && _projectId.isNotEmpty && _senderId.isNotEmpty && _appId.isNotEmpty;

  Future<bool> _init() async {
    if (_initialized) return true;
    if (!available) {
      status = 'App compilata senza chiavi Firebase: notifiche push non disponibili';
      return false;
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(apiKey: _apiKey, appId: _appId, messagingSenderId: _senderId, projectId: _projectId, iosBundleId: Platform.isAndroid ? null : _bundleId),
    );
    FirebaseMessaging.onMessage.listen((m) => onForegroundMessage?.call());
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) Timer(const Duration(milliseconds: 600), () => _open(initial));
    _initialized = true;
    return true;
  }

  void _open(RemoteMessage m) {
    final id = int.tryParse('${m.data['channel_id'] ?? ''}');
    if (id != null) onOpen?.call(id);
  }

  /// Chiede il permesso, ottiene il token FCM e lo registra sul server.
  Future<void> register(Api api) async {
    try {
      if (!await _init()) return;
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission(alert: true, badge: true, sound: true);
      if (perm.authorizationStatus == AuthorizationStatus.denied) {
        status = 'Permesso notifiche negato nelle impostazioni del sistema';
        return;
      }
      await fm.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
      if (Platform.isIOS || Platform.isMacOS) {
        // il token APNs può arrivare qualche secondo dopo l'avvio
        for (var i = 0; i < 10 && await fm.getAPNSToken() == null; i++) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      _token = await fm.getToken();
      if (_token == null) {
        status = 'Token FCM non disponibile';
        return;
      }
      await api.registerDevice(_token!, Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'macos', name: Platform.localHostname);
      status = 'Notifiche push attive';
      fm.onTokenRefresh.listen((t) {
        _token = t;
        api.registerDevice(t, Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'macos').catchError((_) {});
      });
    } catch (e) {
      status = 'Notifiche push non attive: $e';
      debugPrint(status);
    }
  }

  Future<void> unregister(Api api) async {
    if (_token == null) return;
    await api.unregisterDevice(_token!);
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }
}
