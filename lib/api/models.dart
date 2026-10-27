// Modelli dati dell'API AcidTalk 2.x (vedi docs/api.md del backend).
import 'dart:ui' show Color;

DateTime? parseDate(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;
int asInt(dynamic v, [int d = 0]) => v is int ? v : v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? d;
double asDouble(dynamic v, [double d = 0]) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? d;

Color hexColor(String? hex, [Color fallback = const Color(0xFF4A154B)]) {
  if (hex == null) return fallback;
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}

class AppUser {
  final int? id;
  final String name;
  final String initials;
  final String? email;
  final String? title;
  final String role;
  final String avatarColor;
  final bool online;
  final bool isAi;
  final bool isBot;
  final String? avatarUrl;
  final Map<String, dynamic> prefs;

  AppUser({this.id, required this.name, required this.initials, this.email, this.title, this.role = 'member', this.avatarColor = '#4a154b', this.online = false, this.isAi = false, this.isBot = false, this.avatarUrl, this.prefs = const {}});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] == null ? null : asInt(j['id']),
        name: (j['name'] ?? '') as String,
        initials: (j['initials'] ?? _initials(j['name'] as String? ?? '?')) as String,
        email: j['email'] as String?,
        title: j['title'] as String?,
        role: (j['role'] ?? 'member') as String,
        avatarColor: (j['avatar_color'] ?? '#4a154b') as String,
        online: j['online'] == true || j['is_online'] == true,
        isAi: j['is_ai'] == true,
        isBot: j['is_bot'] == true,
        avatarUrl: (j['avatar_url'] as String?)?.isNotEmpty == true ? j['avatar_url'] as String : null,
        prefs: (j['notification_prefs'] is Map) ? Map<String, dynamic>.from(j['notification_prefs']) : const {},
      );

  bool get isAdmin => role == 'admin';
  bool get isGuest => role == 'guest';
  String get themePref => (prefs['theme'] as String?) ?? 'light';
  /// Nome usato nelle menzioni: i bot si menzionano con il nome senza spazi (@nomebot).
  String get mentionHandle => isAi ? 'ai' : isBot ? name.toLowerCase().replaceAll(RegExp(r'[^\p{L}\d._-]+', unicode: true), '') : name.split(' ').first;

  static String _initials(String n) {
    final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.length == 1 ? p[0].substring(0, p[0].length.clamp(0, 2)) : '${p[0][0]}${p[1][0]}').toUpperCase();
  }
}

class Channel {
  final int id;
  String name;
  final String type; // public | private | dm | ai_dm
  String? topic;
  int unread;
  String notify;
  bool isMember;
  bool isArchived;
  DateTime? lastMessageAt;
  final DateTime? createdAt;
  final AppUser? otherUser;
  final int? memberCount;

  Channel({required this.id, required this.name, required this.type, this.topic, this.unread = 0, this.notify = 'all', this.isMember = true, this.isArchived = false, this.lastMessageAt, this.createdAt, this.otherUser, this.memberCount});

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: asInt(j['id']),
        name: (j['name'] ?? '') as String,
        type: (j['type'] ?? 'public') as String,
        topic: j['topic'] as String?,
        unread: asInt(j['unread_count']),
        notify: (j['notify'] ?? 'all') as String,
        isMember: j['is_member'] != false,
        isArchived: j['is_archived'] == true,
        lastMessageAt: parseDate(j['last_message_at']),
        createdAt: parseDate(j['created_at']),
        otherUser: j['other_user'] is Map ? AppUser.fromJson(Map<String, dynamic>.from(j['other_user'])) : null,
        memberCount: j['member_count'] == null ? null : asInt(j['member_count']),
      );

  bool get isDm => type == 'dm';
  bool get isAi => type == 'ai_dm';
  bool get isChannel => type == 'public' || type == 'private';
  DateTime get activity => lastMessageAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  String get label => isChannel ? '#$name' : name;
}

class Attachment {
  final int id;
  final String name;
  final String mime;
  final String kind; // image | pdf | audio | video | file
  final int size;
  final String url;
  final double? duration;

  Attachment({required this.id, required this.name, required this.mime, required this.kind, required this.size, required this.url, this.duration});

  factory Attachment.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] is Map ? Map<String, dynamic>.from(j['meta']) : const <String, dynamic>{};
    return Attachment(
      id: asInt(j['id']),
      name: (j['name'] ?? 'file') as String,
      mime: (j['mime'] ?? '') as String,
      kind: (j['kind'] ?? 'file') as String,
      size: asInt(j['size']),
      url: (j['url'] ?? '') as String,
      duration: meta['duration'] == null ? null : asDouble(meta['duration']),
    );
  }

  static final _audioExt = RegExp(r'\.(mp3|m4a|aac|ogg|oga|opus|wav|flac|weba|mka)$', caseSensitive: false);
  bool get isAudio => kind == 'audio' || mime.startsWith('audio/') || _audioExt.hasMatch(name);
}

class LinkPreview {
  final int id;
  final String url;
  final String kind; // link | video | image | video_call
  final String? title, description, image, siteName, provider;

  LinkPreview({required this.id, required this.url, required this.kind, this.title, this.description, this.image, this.siteName, this.provider});

  factory LinkPreview.fromJson(Map<String, dynamic> j) => LinkPreview(
        id: asInt(j['id']),
        url: (j['url'] ?? '') as String,
        kind: (j['kind'] ?? 'link') as String,
        title: j['title'] as String?,
        description: j['description'] as String?,
        image: j['image'] as String?,
        siteName: j['site_name'] as String?,
        provider: j['provider'] as String?,
      );
}

class Reaction {
  final String emoji;
  final int count;
  final bool me;
  Reaction(this.emoji, this.count, this.me);
  factory Reaction.fromJson(Map<String, dynamic> j) => Reaction((j['emoji'] ?? '') as String, asInt(j['count']), j['me'] == true);
}

class Message {
  final int id;
  final int channelId;
  final int? parentId;
  final AppUser user;
  final String body;
  final String html;
  final String kind;
  final bool isAi;
  final List<Attachment> attachments;
  final List<LinkPreview> previews;
  final List<Reaction> reactions;
  final int replyCount;
  final DateTime? lastReplyAt;
  final DateTime? editedAt;
  final DateTime createdAt;
  final bool canEdit, canDelete;
  /// Attività ancora da eseguire dopo l'invio: ai | previews | bots
  final List<String> pending;
  final String raw; // per confronti rapidi durante la sincronizzazione

  Message({required this.id, required this.channelId, this.parentId, required this.user, required this.body, required this.html, required this.kind, required this.isAi, required this.attachments, required this.previews, required this.reactions, required this.replyCount, this.lastReplyAt, this.editedAt, required this.createdAt, required this.canEdit, required this.canDelete, this.pending = const [], this.raw = ''});

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: asInt(j['id']),
        channelId: asInt(j['channel_id']),
        parentId: j['parent_id'] == null ? null : asInt(j['parent_id']),
        user: AppUser.fromJson(Map<String, dynamic>.from(j['user'] ?? const {'name': '?'})),
        body: (j['body'] ?? '') as String,
        html: (j['html'] ?? '') as String,
        kind: (j['kind'] ?? 'text') as String,
        isAi: j['is_ai'] == true,
        attachments: ((j['attachments'] as List?) ?? const []).map((e) => Attachment.fromJson(Map<String, dynamic>.from(e))).toList(),
        previews: ((j['link_previews'] as List?) ?? const []).map((e) => LinkPreview.fromJson(Map<String, dynamic>.from(e))).toList(),
        reactions: ((j['reactions'] as List?) ?? const []).map((e) => Reaction.fromJson(Map<String, dynamic>.from(e))).toList(),
        replyCount: asInt(j['reply_count']),
        lastReplyAt: parseDate(j['last_reply_at']),
        editedAt: parseDate(j['edited_at']),
        createdAt: parseDate(j['created_at']) ?? DateTime.now(),
        canEdit: j['can_edit'] == true,
        canDelete: j['can_delete'] == true,
        pending: (((j['meta'] is Map ? j['meta']['pending'] : null) as List?) ?? const []).map((e) => '$e').toList(),
        raw: '${j['html']}|${j['edited_at']}|${j['reply_count']}|${j['reactions']}|${j['link_previews']}|${j['attachments']?.length}',
      );

  bool get isVoice => kind == 'voice' && attachments.isNotEmpty;
}

/// Conferma di lettura: fino a quando un membro ha letto il canale.
class ReadReceipt {
  final int userId;
  final String name;
  final DateTime? lastReadAt;
  ReadReceipt(this.userId, this.name, this.lastReadAt);
  factory ReadReceipt.fromJson(Map<String, dynamic> j) => ReadReceipt(asInt(j['user_id']), (j['name'] ?? '') as String, parseDate(j['last_read_at']));
  static List<ReadReceipt> list(dynamic v) => ((v as List?) ?? const []).map((e) => ReadReceipt.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}

class AppNotification {
  final String id;
  final String from, channelName, excerpt, type;
  final int channelId;
  final int? messageId, parentId;
  bool read;
  final DateTime createdAt;

  AppNotification({required this.id, required this.from, required this.channelName, required this.excerpt, required this.type, required this.channelId, this.messageId, this.parentId, required this.read, required this.createdAt});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: '${j['id']}',
        from: (j['from'] ?? '') as String,
        channelName: (j['channel_name'] ?? '') as String,
        excerpt: (j['excerpt'] ?? '') as String,
        // il backend usa "reason" (mention | dm | thread | message)
        type: (j['reason'] ?? j['type'] ?? 'message') as String,
        channelId: asInt(j['channel_id']),
        messageId: j['message_id'] == null ? null : asInt(j['message_id']),
        parentId: j['parent_id'] == null ? null : asInt(j['parent_id']),
        read: j['read_at'] != null,
        createdAt: parseDate(j['created_at']) ?? DateTime.now(),
      );
}

class OrgConfig {
  final String name;
  final String aiBotName;
  final int maxUploadMb;
  final int dmDays;
  final int channelDays;
  final Map<String, dynamic>? realtime;
  final bool readReceipts;
  final bool pushEnabled;

  OrgConfig({this.name = 'AcidTalk', this.aiBotName = 'AI', this.maxUploadMb = 25, this.dmDays = 60, this.channelDays = 90, this.realtime, this.readReceipts = true, this.pushEnabled = false});

  factory OrgConfig.fromJson(Map<String, dynamic> j) {
    final o = Map<String, dynamic>.from(j['org'] ?? const {});
    return OrgConfig(
      name: (o['name'] ?? 'AcidTalk') as String,
      aiBotName: (o['ai_bot_name'] ?? 'AI') as String,
      maxUploadMb: asInt(o['max_upload_mb'], 25),
      dmDays: asInt(o['sidebar_dm_days'], 60),
      channelDays: asInt(o['sidebar_channel_days'], 90),
      realtime: j['realtime'] is Map ? Map<String, dynamic>.from(j['realtime']) : null,
      readReceipts: o['read_receipts'] != false,
      pushEnabled: o['push_enabled'] == true,
    );
  }
}
