import 'package:acidtalk/api/models.dart';
import 'package:acidtalk/state/app_state.dart';
import 'package:acidtalk/widgets/composer.dart';
import 'package:flutter/widgets.dart';
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

  test('2.4: avatar, bot, conferme di lettura e attività in sospeso', () {
    final u = AppUser.fromJson({'id': 8, 'name': 'Meteo', 'is_bot': true, 'avatar_url': '/media/avatars/8.jpg'});
    expect(u.isBot, isTrue);
    expect(u.avatarUrl, '/media/avatars/8.jpg');
    expect(u.mentionHandle, 'meteo');
    expect(AppUser.fromJson({'name': 'Giulia Verdi', 'avatar_url': ''}).avatarUrl, isNull);
    final r = ReadReceipt.list([
      {'user_id': 2, 'name': 'Giulia', 'last_read_at': '2026-10-26T10:00:00Z'},
      {'user_id': 3, 'name': 'Luca', 'last_read_at': null},
    ]);
    expect(r.length, 2);
    expect(r.first.lastReadAt?.toUtc().hour, 10);
    expect(r.last.lastReadAt, isNull);
    final m = Message.fromJson({
      'id': 5, 'channel_id': 1, 'body': '@ai ciao', 'html': '<p>@ai ciao</p>',
      'user': {'id': 1, 'name': 'Admin'}, 'created_at': '2026-10-26T09:00:00Z',
      'meta': {'pending': ['ai', 'previews']},
    });
    expect(m.pending, ['ai', 'previews']);
    final o = OrgConfig.fromJson({'org': {'read_receipts': false}, 'push_enabled': true});
    expect(o.readReceipts, isFalse);
  });

  test('2.5: suggerimenti @persone e #canali', () {
    final s = AppState();
    s.channels = [
      Channel.fromJson({'id': 20, 'name': 'Produzione', 'slug': 'produzione', 'type': 'public'}),
      Channel.fromJson({'id': 21, 'name': 'Progetto alfa', 'slug': 'progetto-alfa', 'type': 'private'}),
      Channel.fromJson({'id': 22, 'name': 'Giulia Verdi', 'type': 'dm'}),
    ];
    s.users = [
      AppUser.fromJson({'id': 2, 'name': 'Giulia Verdi', 'title': 'Marketing'}),
      AppUser.fromJson({'id': 3, 'name': 'Luca Bianchi'}),
      AppUser.fromJson({'id': 8, 'name': 'Meteo', 'is_bot': true}),
    ];
    expect(ComposerState.suggestRefs(s, '#', 'pro').map((r) => r.insert), ['#produzione', '#progetto-alfa']);
    expect(ComposerState.suggestRefs(s, '#', 'alfa').single.insert, '#progetto-alfa');
    expect(ComposerState.suggestRefs(s, '#', '').length, 2);
    expect(ComposerState.suggestRefs(s, '@', 'giu').single.insert, '@Giulia');
    expect(ComposerState.suggestRefs(s, '@', 'bian').single.insert, '@Luca');
    expect(ComposerState.suggestRefs(s, '@', 'met').single.insert, '@meteo');
    expect(ComposerState.suggestRefs(s, '@', 'a').first.insert, '@ai');
  });

  test('2.5.1: a capo con continuazione degli elenchi e pulsante elenco puntato', () {
    TextEditingValue v(String t, [int? o]) => TextEditingValue(text: t, selection: TextSelection.collapsed(offset: o ?? t.length));
    var r = ComposerState.newlineWithList(v('Ciao'));
    expect(r.text, 'Ciao\n');
    r = ComposerState.newlineWithList(v('Lista:\n- uno'));
    expect(r.text, 'Lista:\n- uno\n- ');
    expect(r.selection.baseOffset, r.text.length);
    r = ComposerState.newlineWithList(r);
    expect(r.text, 'Lista:\n- uno\n');
    expect(ComposerState.newlineWithList(v('1. primo')).text, '1. primo\n2. ');
    expect(ComposerState.newlineWithList(v('  * sotto')).text, '  * sotto\n  * ');
    expect(ComposerState.newlineWithList(v('-meno')).text, '-meno\n');
    r = ComposerState.toggleBullets(v('latte'));
    expect(r.text, '- latte');
    expect(r.selection.baseOffset, 7);
    r = ComposerState.toggleBullets(const TextEditingValue(text: 'a\nb\n\nc', selection: TextSelection(baseOffset: 0, extentOffset: 6)));
    expect(r.text, '- a\n- b\n\n- c');
    r = ComposerState.toggleBullets(TextEditingValue(text: r.text, selection: TextSelection(baseOffset: 0, extentOffset: r.text.length)));
    expect(r.text, 'a\nb\n\nc');
    expect(ComposerState.toggleBullets(v('')).text, '- ');
  });
}
