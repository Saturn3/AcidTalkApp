import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Client REST del backend AcidTalk (token Sanctum Bearer).
class Api {
  final String server; // es. https://talk.acidsoft.it
  String? token;
  late final Dio dio;

  Api(this.server, {this.token}) {
    dio = Dio(BaseOptions(
      baseUrl: '${server.replaceAll(RegExp(r'/+$'), '')}/api',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 40),
      headers: {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
    ));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
      h.next(o);
    }));
  }

  /// URL assoluto per allegati e immagini (il backend può restituire percorsi relativi).
  String abs(String url) => url.startsWith('http') ? url : '${server.replaceAll(RegExp(r'/+$'), '')}${url.startsWith('/') ? '' : '/'}$url';

  Future<dynamic> _req(Future<Response> Function() f) async {
    try {
      return (await f()).data;
    } on DioException catch (e) {
      final d = e.response?.data;
      String msg;
      if (d is Map && d['errors'] is Map) {
        msg = (d['errors'] as Map).values.expand((v) => v is List ? v : [v]).first.toString();
      } else if (d is Map && d['message'] is String && (d['message'] as String).isNotEmpty) {
        msg = d['message'];
      } else if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        msg = 'Server non raggiungibile: controlla l\'indirizzo e la connessione';
      } else {
        msg = 'Errore ${e.response?.statusCode ?? ''} ${e.message ?? ''}'.trim();
      }
      throw ApiException(msg, e.response?.statusCode);
    }
  }

  static List<Map<String, dynamic>> _list(dynamic r) => ((r is Map ? r['data'] : r) as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  static Map<String, dynamic> _one(dynamic r) => Map<String, dynamic>.from((r is Map && r['data'] is Map ? r['data'] : r) as Map);

  // ---------------- autenticazione
  Future<(String, AppUser)> login(String email, String password, String device) async {
    final r = await _req(() => dio.post('/auth/login', data: {'email': email, 'password': password, 'device_name': device}));
    return (r['token'] as String, AppUser.fromJson(_one(r['user'])));
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } catch (_) {}
  }

  Future<AppUser> me() async => AppUser.fromJson(_one(await _req(() => dio.get('/me'))));
  Future<AppUser> updatePrefs(Map<String, dynamic> prefs) async => AppUser.fromJson(_one(await _req(() => dio.put('/me', data: {'notification_prefs': prefs}))));

  Future<OrgConfig> config() async {
    try {
      return OrgConfig.fromJson(Map<String, dynamic>.from(await _req(() => dio.get('/config'))));
    } on ApiException catch (e) {
      if (e.status == 404) return OrgConfig(); // backend < 2.3
      rethrow;
    }
  }

  // ---------------- canali
  Future<List<Channel>> channels() async => _list(await _req(() => dio.get('/channels'))).map(Channel.fromJson).toList();
  Future<Channel> directWith(int userId) async => Channel.fromJson(_one(await _req(() => dio.post('/channels/direct', data: {'user_id': userId}))));
  Future<Channel> aiChannel() async => Channel.fromJson(_one(await _req(() => dio.post('/channels/ai'))));
  Future<void> markRead(int id) => _req(() => dio.post('/channels/$id/read'));
  Future<Channel> createChannel(String name, {bool private = false, String? topic}) async =>
      Channel.fromJson(_one(await _req(() => dio.post('/channels', data: {'name': name, 'type': private ? 'private' : 'public', 'topic': ?topic}))));
  Future<void> join(int id) => _req(() => dio.post('/channels/$id/join'));
  Future<void> leave(int id) => _req(() => dio.post('/channels/$id/leave'));
  Future<Message> startCall(int channelId, {String? url}) async {
    final r = await _req(() => dio.post('/channels/$channelId/calls', data: {'url': ?url}));
    return Message.fromJson(Map<String, dynamic>.from(r['message'] as Map));
  }
  Future<List<AppUser>> users() async => _list(await _req(() => dio.get('/users'))).map(AppUser.fromJson).toList();

  // ---------------- messaggi
  Future<({List<Message> items, bool hasMore, String? serverTime})> messages(int channelId, {int? before, int? after, int limit = 50}) async {
    final r = await _req(() => dio.get('/channels/$channelId/messages', queryParameters: {'limit': limit, 'before': ?before, 'after': ?after}));
    final meta = (r is Map ? r['meta'] : null) as Map?;
    return (items: _list(r).map(Message.fromJson).toList(), hasMore: meta?['has_more'] == true, serverTime: meta?['server_time'] as String?);
  }

  /// Sincronizzazione senza WebSocket: messaggi modificati/eliminati dopo [since].
  Future<({List<Message> changed, List<int> deleted, String? serverTime})> changes(int channelId, String since, {int? thread}) async {
    final r = await _req(() => dio.get('/channels/$channelId/messages', queryParameters: {'changed_since': since, 'thread': ?thread}));
    return (
      changed: _list(r).map(Message.fromJson).toList(),
      deleted: ((r['deleted'] as List?) ?? const []).map((e) => asInt(e)).toList(),
      serverTime: (r['meta'] as Map?)?['server_time'] as String?,
    );
  }

  Future<({Message root, List<Message> replies})> thread(int messageId) async {
    final r = await _req(() => dio.get('/messages/$messageId/thread'));
    return (root: Message.fromJson(Map<String, dynamic>.from(r['root'])), replies: _list(r).map(Message.fromJson).toList());
  }

  Future<Message> send(int channelId, String body, {int? parentId, List<int> attachmentIds = const [], String kind = 'text'}) async =>
      Message.fromJson(_one(await _req(() => dio.post('/channels/$channelId/messages', data: {'body': body, 'parent_id': ?parentId, 'attachment_ids': attachmentIds, 'kind': kind}))));
  Future<Message> edit(int id, String body) async => Message.fromJson(_one(await _req(() => dio.put('/messages/$id', data: {'body': body}))));
  Future<void> delete(int id) => _req(() => dio.delete('/messages/$id'));
  Future<Message> react(int id, String emoji) async => Message.fromJson(_one(await _req(() => dio.post('/messages/$id/react', data: {'emoji': emoji}))));
  Future<Message> removePreview(int id, int previewId) async => Message.fromJson(_one(await _req(() => dio.delete('/messages/$id/previews/$previewId'))));

  Future<Attachment> upload(String path, {String? name, double? duration, bool voice = false, void Function(double)? onProgress}) async {
    final filename = name ?? path.split(Platform.pathSeparator).last;
    final type = lookupMimeType(filename) ?? (voice ? 'audio/mp4' : 'application/octet-stream');
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename, contentType: MediaType.parse(type)),
      'duration': ?duration?.toStringAsFixed(1),
      if (voice) 'voice': '1',
    });
    final r = await _req(() => dio.post('/attachments', data: form, onSendProgress: (s, t) => onProgress?.call(t > 0 ? s / t : 0)));
    return Attachment.fromJson(_one(r));
  }

  // ---------------- notifiche
  Future<({List<AppNotification> items, int unread})> notifications() async {
    final r = await _req(() => dio.get('/notifications'));
    return (items: _list(r).map(AppNotification.fromJson).toList(), unread: asInt(r['unread']));
  }

  Future<void> readNotification(String id) => _req(() => dio.post('/notifications/$id/read'));

  /// Firma dei canali privati per Pusher/Reverb.
  Future<String> broadcastAuth(String socketId, String channel) async {
    final r = await _req(() => dio.post('/broadcasting/auth', data: {'socket_id': socketId, 'channel_name': channel}));
    return (r as Map)['auth'] as String;
  }
}
