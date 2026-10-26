import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../services/notifier.dart';
import '../services/realtime.dart';

enum SortMode { recent, alpha }

/// Stato globale dell'app: sessione, canali, messaggi, sincronizzazione e preferenze.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static const defaultServer = String.fromEnvironment('ACIDTALK_SERVER', defaultValue: 'https://talk.acidsoft.it');

  late SharedPreferences _prefs;
  Api? api;
  AppUser? me;
  OrgConfig org = OrgConfig();
  bool booting = true;

  List<Channel> channels = [];
  final Map<int, List<Message>> messages = {};
  final Map<int, bool> hasMore = {};
  final Map<int, String> _syncAt = {};
  final Set<int> loading = {};
  int? activeId;

  Message? threadRoot;
  List<Message> threadReplies = [];

  List<AppNotification> notifications = [];
  int unreadNotifications = 0;
  final Set<String> _seenNotifs = {};
  bool _notifsPrimed = false;

  SortMode sort = SortMode.recent;
  bool showAllChannels = false, showAllDms = false;
  ThemeMode themeMode = ThemeMode.light;
  String themePref = 'light';

  RealtimeClient? _rt;
  bool realtimeConnected = false;
  Timer? _poll;
  int _tick = 0;
  bool _foreground = true;

  String get server => _prefs.getString('server') ?? defaultServer;
  String? get lastEmail => _prefs.getString('email');

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    WidgetsBinding.instance.addObserver(this);
    sort = _prefs.getString('sort') == 'alpha' ? SortMode.alpha : SortMode.recent;
    _applyTheme(_prefs.getString('theme') ?? 'light', notify: false);
    await Notifier.instance.init().timeout(const Duration(seconds: 5), onTimeout: () {}).catchError((_) {});
    Notifier.instance.onTap = (payload) {
      final id = int.tryParse(payload);
      if (id != null) openChannel(id);
    };
    final token = _prefs.getString('token');
    if (token != null) {
      api = Api(server, token: token);
      try {
        await _afterLogin();
      } catch (e) {
        if (e is ApiException && e.status == 401) {
          await _prefs.remove('token');
          api = null;
        }
      }
    }
    booting = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && api != null) _pollOnce();
  }

  // ------------------------------------------------------------ sessione
  Future<void> login(String serverUrl, String email, String password) async {
    var url = serverUrl.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    url = url.replaceAll(RegExp(r'/+$'), '');
    final a = Api(url);
    final device = 'AcidTalk ${Platform.operatingSystem} (${Platform.localHostname})';
    final (token, user) = await a.login(email.trim(), password, device);
    a.token = token;
    api = a;
    me = user;
    await _prefs.setString('server', url);
    await _prefs.setString('email', email.trim());
    await _prefs.setString('token', token);
    await _afterLogin();
    notifyListeners();
  }

  Future<void> logout() async {
    _poll?.cancel();
    _rt?.close();
    await api?.logout();
    await _prefs.remove('token');
    api = null;
    me = null;
    channels = [];
    messages.clear();
    activeId = null;
    threadRoot = null;
    notifyListeners();
  }

  Future<void> _afterLogin() async {
    me = await api!.me();
    _applyTheme(me!.themePref);
    try {
      org = await api!.config();
    } catch (_) {}
    await refreshChannels();
    await _loadNotifications();
    if (activeId == null) {
      final last = _prefs.getInt('last_channel');
      final c = channels.where((c) => c.id == last).firstOrNull ?? channels.where((c) => c.name == 'generale').firstOrNull;
      if (c != null && !_isMobileLayoutHint) await openChannel(c.id);
    }
    _startRealtime();
    _startPolling();
    Notifier.instance.requestPermission();
  }

  /// Sui telefoni l'app parte dalla lista conversazioni, su desktop/tablet apre l'ultimo canale.
  bool get _isMobileLayoutHint => Platform.isAndroid || Platform.isIOS;

  // ------------------------------------------------------------ tema
  void _applyTheme(String pref, {bool notify = true}) {
    themePref = pref;
    themeMode = switch (pref) { 'dark' => ThemeMode.dark, 'system' => ThemeMode.system, _ => ThemeMode.light };
    _prefs.setString('theme', pref);
    if (notify) notifyListeners();
  }

  Future<void> setTheme(String pref) async {
    _applyTheme(pref);
    try {
      me = await api?.updatePrefs({'theme': pref});
    } catch (_) {}
  }

  Future<void> setPush(bool v) async {
    me = await api!.updatePrefs({'push': v});
    notifyListeners();
  }

  // ------------------------------------------------------------ barra laterale
  void setSort(SortMode m) {
    sort = m;
    _prefs.setString('sort', m == SortMode.alpha ? 'alpha' : 'recent');
    notifyListeners();
  }

  void toggleShowAll({required bool dms}) {
    dms ? showAllDms = !showAllDms : showAllChannels = !showAllChannels;
    notifyListeners();
  }

  bool _recent(Channel c, int days) => c.unread > 0 || c.id == activeId || c.activity.isAfter(DateTime.now().subtract(Duration(days: days)));

  List<Channel> _sorted(Iterable<Channel> l, SortMode m) {
    final out = l.toList();
    int byName(Channel a, Channel b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    out.sort(m == SortMode.alpha ? byName : (a, b) {
      final c = b.activity.compareTo(a.activity);
      return c != 0 ? c : byName(a, b);
    });
    return out;
  }

  ({List<Channel> visible, int hidden}) get sidebarDms {
    final all = channels.where((c) => c.isDm);
    final vis = showAllDms ? all : all.where((c) => _recent(c, org.dmDays));
    return (visible: _sorted(vis, SortMode.recent), hidden: all.length - vis.length);
  }

  ({List<Channel> visible, int hidden}) get sidebarChannels {
    final all = channels.where((c) => c.isChannel && c.isMember && !c.isArchived);
    final vis = showAllChannels ? all : all.where((c) => _recent(c, org.channelDays));
    return (visible: _sorted(vis, sort), hidden: all.length - vis.length);
  }

  List<Channel> get aiChannels => channels.where((c) => c.isAi).toList();
  Channel? get active => channels.where((c) => c.id == activeId).firstOrNull;
  int get totalUnread => channels.fold(0, (s, c) => s + c.unread);

  // ------------------------------------------------------------ canali e messaggi
  Future<void> refreshChannels() async {
    final list = await api!.channels();
    for (final c in list) {
      if (c.id == activeId) c.unread = 0;
    }
    channels = list;
    notifyListeners();
  }

  Future<void> openChannel(int id) async {
    activeId = id;
    threadRoot = null;
    _prefs.setInt('last_channel', id);
    final c = active;
    if (c != null && c.unread > 0) {
      c.unread = 0;
      api!.markRead(id).catchError((_) {});
    }
    notifyListeners();
    if (!messages.containsKey(id)) await loadMessages(id);
    _rt?.subscribe('private-channel.$id');
  }

  void closeChannel() {
    activeId = null;
    threadRoot = null;
    notifyListeners();
  }

  Future<void> loadMessages(int id, {bool older = false}) async {
    if (loading.contains(id)) return;
    loading.add(id);
    notifyListeners();
    try {
      final before = older ? messages[id]?.firstOrNull?.id : null;
      final r = await api!.messages(id, before: before);
      messages[id] = older ? [...r.items, ...?messages[id]] : r.items;
      hasMore[id] = r.hasMore;
      if (!older && r.serverTime != null) _syncAt[id] = r.serverTime!;
    } finally {
      loading.remove(id);
      notifyListeners();
    }
  }

  void _upsert(Message m, {bool onlyExisting = false}) {
    if (m.parentId != null) {
      if (threadRoot?.id == m.parentId) {
        final i = threadReplies.indexWhere((x) => x.id == m.id);
        i >= 0 ? threadReplies[i] = m : threadReplies.add(m);
      }
      return;
    }
    final list = messages[m.channelId];
    if (list == null) return;
    final i = list.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      if (list[i].raw == m.raw) return;
      list[i] = m;
    } else if (!onlyExisting) {
      list.add(m);
      final c = channels.where((c) => c.id == m.channelId).firstOrNull;
      if (c != null) c.lastMessageAt = m.createdAt;
    }
    if (threadRoot?.id == m.id) threadRoot = m;
  }

  void _remove(int id, int channelId) {
    messages[channelId]?.removeWhere((x) => x.id == id);
    threadReplies.removeWhere((x) => x.id == id);
    if (threadRoot?.id == id) threadRoot = null;
  }

  Future<void> send(String body, {int? parentId, List<Attachment> attachments = const [], String kind = 'text'}) async {
    final id = activeId;
    if (id == null) return;
    final m = await api!.send(id, body, parentId: parentId, attachmentIds: attachments.map((a) => a.id).toList(), kind: kind);
    _upsert(m);
    if (parentId != null && threadRoot != null) await openThread(threadRoot!);
    notifyListeners();
  }

  Future<void> edit(Message m, String body) async {
    _upsert(await api!.edit(m.id, body));
    notifyListeners();
  }

  Future<void> delete(Message m) async {
    await api!.delete(m.id);
    _remove(m.id, m.channelId);
    notifyListeners();
  }

  Future<void> react(Message m, String emoji) async {
    _upsert(await api!.react(m.id, emoji));
    notifyListeners();
  }

  Future<void> removePreview(Message m, LinkPreview p) async {
    _upsert(await api!.removePreview(m.id, p.id));
    notifyListeners();
  }

  Future<void> openThread(Message root) async {
    threadRoot = root;
    threadReplies = [];
    notifyListeners();
    final t = await api!.thread(root.id);
    threadRoot = t.root;
    threadReplies = t.replies;
    notifyListeners();
  }

  void closeThread() {
    threadRoot = null;
    notifyListeners();
  }

  Future<void> startDm(AppUser u) async {
    final c = await api!.directWith(u.id!);
    await refreshChannels();
    await openChannel(c.id);
  }

  List<Channel> get browsable => channels.where((c) => c.isChannel && !c.isMember && !c.isArchived).toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> joinChannel(Channel c) async {
    await api!.join(c.id);
    await refreshChannels();
    await openChannel(c.id);
  }

  Future<void> leaveChannel(Channel c) async {
    await api!.leave(c.id);
    messages.remove(c.id);
    if (activeId == c.id) activeId = null;
    await refreshChannels();
  }

  Future<void> createChannel(String name, bool private, String? topic) async {
    final c = await api!.createChannel(name, private: private, topic: topic);
    await refreshChannels();
    await openChannel(c.id);
  }

  Future<void> startCall() async {
    if (activeId == null) return;
    final m = await api!.startCall(activeId!);
    _upsert(m);
    notifyListeners();
  }

  Future<void> readNotification(AppNotification n) async {
    await api!.readNotification(n.id).catchError((_) {});
    await _loadNotifications();
    notifyListeners();
  }

  Future<void> openAi() async {
    final c = await api!.aiChannel();
    await refreshChannels();
    await openChannel(c.id);
  }

  // ------------------------------------------------------------ sincronizzazione
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_foreground && !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
      if (realtimeConnected && _tick++ % 4 != 0) return;
      _pollOnce();
    });
  }

  bool _polling = false;
  Future<void> _pollOnce() async {
    if (_polling || api == null) return;
    _polling = true;
    try {
      final id = activeId;
      if (id != null && messages[id] != null) {
        final last = messages[id]!.lastOrNull?.id ?? 0;
        final r = await api!.messages(id, after: last);
        for (final m in r.items) {
          _upsert(m);
        }
        if (_syncAt[id] != null && !realtimeConnected) {
          final ch = await api!.changes(id, _syncAt[id]!);
          if (ch.serverTime != null) _syncAt[id] = ch.serverTime!;
          for (final m in ch.changed) {
            _upsert(m, onlyExisting: true);
          }
          for (final d in ch.deleted) {
            _remove(d, id);
          }
        }
        if (threadRoot != null) {
          final t = await api!.thread(threadRoot!.id);
          threadRoot = t.root;
          threadReplies = t.replies;
        }
        if (r.items.isNotEmpty) api!.markRead(id).catchError((_) {});
      }
      if (!realtimeConnected) await refreshChannels();
      await _loadNotifications();
      notifyListeners();
    } catch (_) {
      // rete assente: riprova al prossimo giro
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadNotifications() async {
    final r = await api!.notifications();
    notifications = r.items;
    unreadNotifications = r.unread;
    for (final n in r.items) {
      final fresh = DateTime.now().difference(n.createdAt).inMinutes < 5;
      if (_notifsPrimed && !_seenNotifs.contains(n.id) && !n.read && fresh && me?.prefs['push'] != false) {
        final visible = _foreground && n.channelId == activeId;
        if (!visible) {
          Notifier.instance.show(id: n.messageId ?? n.id.hashCode, title: n.type == 'dm' ? n.from : '${n.from} in #${n.channelName}', body: n.excerpt, payload: '${n.channelId}');
        }
      }
      _seenNotifs.add(n.id);
    }
    _notifsPrimed = true;
  }

  void _startRealtime() {
    _rt?.close();
    final cfg = org.realtime;
    if (cfg == null || cfg['key'] == null) return;
    _rt = RealtimeClient(
      api: api!,
      config: cfg,
      onState: (ok) {
        realtimeConnected = ok;
        if (!ok) _pollOnce();
        notifyListeners();
      },
      onEvent: (channel, event, data) {
        switch (event) {
          case 'message.sent' || 'message.updated':
            if (data['message'] is Map) {
              final m = Message.fromJson(Map<String, dynamic>.from(data['message']));
              if (m.channelId == activeId || m.parentId != null) {
                _upsert(m, onlyExisting: event == 'message.updated');
              }
            }
          case 'message.deleted':
            _remove(asInt(data['id']), asInt(data['channel_id']));
          case 'user.touched':
            refreshChannels();
            _loadNotifications();
        }
        notifyListeners();
      },
    );
    _rt!.connect();
    _rt!.subscribe('private-user.${me!.id}');
    if (activeId != null) _rt!.subscribe('private-channel.$activeId');
  }

  @override
  void dispose() {
    _poll?.cancel();
    _rt?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
