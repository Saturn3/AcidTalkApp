import 'package:acidtalk/api/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Message.fromJson legge allegati audio, anteprime e reazioni', () {
    final m = Message.fromJson({
      'id': 5,
      'channel_id': 2,
      'user': {'id': 1, 'name': 'Mario Rossi'},
      'body': 'ciao',
      'html': '<p>ciao</p>',
      'kind': 'voice',
      'attachments': [
        {'id': 9, 'name': 'voice-1.webm', 'mime': 'video/webm', 'kind': 'audio', 'size': 1200, 'url': '/storage/a.webm', 'meta': {'duration': 4.2}},
      ],
      'link_previews': [
        {'id': 3, 'url': 'https://youtu.be/x', 'kind': 'video', 'title': 'Video'},
      ],
      'reactions': [
        {'emoji': '👍', 'count': 2, 'me': true},
      ],
      'created_at': '2026-10-25T10:00:00+01:00',
      'can_edit': true,
    });
    expect(m.isVoice, isTrue);
    expect(m.attachments.single.isAudio, isTrue);
    expect(m.attachments.single.duration, 4.2);
    expect(m.previews.single.kind, 'video');
    expect(m.reactions.single.me, isTrue);
    expect(m.user.initials, 'MR');
  });

  test('Channel.activity usa last_message_at oppure created_at', () {
    final c = Channel.fromJson({'id': 1, 'name': 'generale', 'type': 'public', 'created_at': '2026-01-01T00:00:00Z'});
    expect(c.isChannel, isTrue);
    expect(c.activity.year, 2026);
    final d = Channel.fromJson({'id': 2, 'name': 'Luca', 'type': 'dm', 'last_message_at': '2026-10-01T00:00:00Z', 'unread_count': 3});
    expect(d.isDm, isTrue);
    expect(d.unread, 3);
  });

  test('OrgConfig legge i giorni della barra laterale e la configurazione realtime', () {
    final o = OrgConfig.fromJson({
      'org': {'name': 'AcidSoft', 'sidebar_dm_days': 30, 'sidebar_channel_days': 120},
      'realtime': {'driver': 'pusher', 'key': 'abc', 'cluster': 'eu'},
    });
    expect(o.dmDays, 30);
    expect(o.channelDays, 120);
    expect(o.realtime?['driver'], 'pusher');
    expect(OrgConfig.fromJson({'org': {}}).dmDays, 60);
  });
}
