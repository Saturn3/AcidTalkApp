import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api.dart';

typedef RealtimeHandler = void Function(String channel, String event, Map<String, dynamic> data);

/// Client minimale del protocollo Pusher (v7), compatibile con Pusher Channels e Laravel Reverb.
/// Se la connessione non è disponibile l'app continua a funzionare con il polling.
class RealtimeClient {
  final Api api;
  final Map<String, dynamic> config; // {driver: pusher|reverb, key, cluster|host, port, scheme}
  final RealtimeHandler onEvent;
  final void Function(bool connected)? onState;

  /// Ultimo errore di connessione o del protocollo (es. "App key ... not in this cluster"), per la diagnosi.
  String? lastError;

  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  String? _socketId;
  Timer? _ping, _retry;
  int _attempt = 0;
  bool _closed = false;
  final Set<String> _channels = {};
  bool connected = false;

  RealtimeClient({required this.api, required this.config, required this.onEvent, this.onState});

  Uri get _uri {
    final key = config['key'];
    const q = 'protocol=7&client=acidtalk-flutter&version=2.3&flash=false';
    if (config['driver'] == 'pusher') {
      return Uri.parse('wss://ws-${config['cluster'] ?? 'eu'}.pusher.com/app/$key?$q');
    }
    final secure = (config['scheme'] ?? 'https') == 'https';
    final port = config['port'] ?? (secure ? 443 : 80);
    return Uri.parse('${secure ? 'wss' : 'ws'}://${config['host']}:$port/app/$key?$q');
  }

  void connect() {
    if (_closed) return;
    try {
      _ws = WebSocketChannel.connect(_uri);
      _sub = _ws!.stream.listen(
        _onData,
        onError: (e) {
          lastError = '$e'.replaceFirst('WebSocketChannelException: ', '');
          _drop();
        },
        onDone: () {
          final code = _ws?.closeCode;
          if (code != null && code >= 4000) lastError ??= 'connessione chiusa dal server (codice $code)';
          _drop();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Realtime non disponibile: $e');
      lastError = '$e';
      _drop();
    }
  }

  void subscribe(String channel) {
    _channels.add(channel);
    if (_socketId != null) _doSubscribe(channel);
  }

  Future<void> _doSubscribe(String channel) async {
    try {
      final auth = await api.broadcastAuth(_socketId!, channel);
      _send('pusher:subscribe', {'channel': channel, 'auth': auth});
    } catch (e) {
      debugPrint('Sottoscrizione $channel fallita: $e');
      lastError = 'autorizzazione del canale $channel non riuscita: $e';
      onState?.call(connected);
    }
  }

  void _send(String event, Map<String, dynamic> data) => _ws?.sink.add(jsonEncode({'event': event, 'data': data}));

  void _onData(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final event = msg['event'] as String? ?? '';
    dynamic data = msg['data'];
    if (data is String && data.isNotEmpty) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }
    switch (event) {
      case 'pusher:connection_established':
        _socketId = (data as Map)['socket_id'] as String;
        _attempt = 0;
        lastError = null;
        connected = true;
        onState?.call(true);
        for (final c in _channels) {
          _doSubscribe(c);
        }
        _ping?.cancel();
        _ping = Timer.periodic(const Duration(seconds: 60), (_) => _send('pusher:ping', {}));
      case 'pusher:ping':
        _send('pusher:pong', {});
      case 'pusher:error':
        debugPrint('Realtime: $data');
        if (data is Map) lastError = '${data['message'] ?? 'errore'}${data['code'] != null ? ' (codice ${data['code']})' : ''}';
        onState?.call(connected);
      case 'pusher_internal:subscription_succeeded':
        break;
      default:
        if (!event.startsWith('pusher')) {
          onEvent(msg['channel'] as String? ?? '', event, data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
        }
    }
  }

  void _drop() {
    _ping?.cancel();
    _sub?.cancel();
    _socketId = null;
    if (connected) onState?.call(false);
    connected = false;
    if (_closed) return;
    _attempt++;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: (2 << _attempt.clamp(0, 5))), connect); // 4 s … 64 s
  }

  void close() {
    _closed = true;
    _ping?.cancel();
    _retry?.cancel();
    _sub?.cancel();
    _ws?.sink.close();
    connected = false;
  }
}
