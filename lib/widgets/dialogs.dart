import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

export 'search_sheet.dart' show showSearchSheet;

Future<void> showNewDm(BuildContext context, {VoidCallback? onOpened}) async {
  final s = context.read<AppState>();
  final users = await s.api!.users().catchError((_) => <AppUser>[]);
  if (!context.mounted) return;
  final others = users.where((u) => u.id != s.me?.id && !u.isAi).toList()..sort((a, b) => a.name.compareTo(b.name));
  final picked = await showDialog<AppUser>(context: context, builder: (_) => _PickerDialog(title: 'Nuovo messaggio diretto', users: others));
  if (picked == null) return;
  onOpened?.call();
  await s.startDm(picked);
}

class _PickerDialog extends StatefulWidget {
  final String title;
  final List<AppUser> users;
  const _PickerDialog({required this.title, required this.users});

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final list = widget.users.where((u) => '${u.name} ${u.email ?? ''}'.toLowerCase().contains(q.toLowerCase())).toList();
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 440,
        height: 420,
        child: Column(children: [
          TextField(autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Cerca persone'), onChanged: (v) => setState(() => q = v)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final u = list[i];
                return ListTile(
                  leading: Avatar(u, size: 32),
                  title: Text(u.name),
                  subtitle: Text(u.title ?? u.email ?? '', style: TextStyle(color: at.muted)),
                  trailing: u.isGuest ? const Chip(label: Text('Ospite'), visualDensity: VisualDensity.compact) : null,
                  onTap: () => Navigator.pop(context, u),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla'))],
    );
  }
}

Future<void> showChannelBrowser(BuildContext context, {VoidCallback? onOpened}) async {
  await showDialog(context: context, builder: (_) => _ChannelBrowser(onOpened: onOpened));
}

class _ChannelBrowser extends StatefulWidget {
  final VoidCallback? onOpened;
  const _ChannelBrowser({this.onOpened});

  @override
  State<_ChannelBrowser> createState() => _ChannelBrowserState();
}

class _ChannelBrowserState extends State<_ChannelBrowser> {
  bool creating = false, private = false, busy = false;
  final name = TextEditingController(), topic = TextEditingController();
  String? error;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final at = AT.of(context);
    final mine = s.channels.where((c) => c.isChannel && c.isMember && !c.isArchived).toList()..sort((a, b) => a.name.compareTo(b.name));
    final other = s.browsable;
    return AlertDialog(
      title: Text(creating ? 'Crea un canale' : 'Canali'),
      content: SizedBox(
        width: 480,
        height: creating ? 300 : 460,
        child: creating
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: name, autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.tag, size: 18), labelText: 'Nome', hintText: 'es. progetto-alpha')),
                const SizedBox(height: 12),
                TextField(controller: topic, decoration: const InputDecoration(labelText: 'Argomento (facoltativo)')),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: private,
                  onChanged: (v) => setState(() => private = v),
                  title: const Text('Canale privato'),
                  subtitle: Text('Visibile solo ai membri invitati', style: TextStyle(color: at.muted)),
                ),
                if (error != null) Text(error!, style: TextStyle(color: at.mention)),
              ])
            : ListView(children: [
                if (other.isNotEmpty) _hdr('Puoi unirti', at),
                for (final c in other)
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(c.name),
                    subtitle: c.topic == null ? null : Text(c.topic!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        Navigator.pop(context);
                        widget.onOpened?.call();
                        await s.joinChannel(c);
                      },
                      child: const Text('Unisciti'),
                    ),
                  ),
                _hdr('I tuoi canali', at),
                for (final c in mine)
                  ListTile(
                    leading: Icon(c.type == 'private' ? Icons.lock_outline : Icons.tag),
                    title: Text(c.name),
                    subtitle: Text('${c.memberCount ?? '-'} membri', style: TextStyle(color: at.muted)),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onOpened?.call();
                      s.openChannel(c.id);
                    },
                  ),
              ]),
      ),
      actions: creating
          ? [
              TextButton(onPressed: () => setState(() => creating = false), child: const Text('Indietro')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await s.createChannel(name.text.trim(), private, topic.text.trim().isEmpty ? null : topic.text.trim());
                          if (context.mounted) Navigator.pop(context);
                          widget.onOpened?.call();
                        } on ApiException catch (e) {
                          setState(() => error = e.message);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: const Text('Crea'),
              ),
            ]
          : [
              if (s.me?.isGuest != true) TextButton.icon(onPressed: () => setState(() => creating = true), icon: const Icon(Icons.add, size: 18), label: const Text('Crea canale')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
            ],
    );
  }

  Widget _hdr(String t, AT at) => Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text(t.toUpperCase(), style: TextStyle(color: at.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5)));
}

Future<void> showNotificationsSheet(BuildContext context, {VoidCallback? onOpened}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      builder: (_, sc) => Consumer<AppState>(builder: (ctx, s, _) {
        final at = AT.of(ctx);
        final items = s.notifications;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(children: [
              Expanded(
                child: Text(s.unreadNotifications > 0 ? 'Notifiche (${s.unreadNotifications} da leggere)' : 'Notifiche',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: at.text)),
              ),
              IconButton(tooltip: 'Chiudi', onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
            ]),
          ),
          if (items.isNotEmpty)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Wrap(spacing: 8, runSpacing: 4, children: [
                TextButton.icon(
                  onPressed: s.unreadNotifications == 0 ? null : s.readAllNotifications,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Segna tutte come lette'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: at.muted),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('Cancellare tutte le notifiche?'),
                        content: const Text('Le notifiche vengono eliminate dall\'elenco; i messaggi restano nei canali.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annulla')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Cancella tutte')),
                        ],
                      ),
                    );
                    if (ok == true) await s.clearNotifications();
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Cancella tutte'),
                ),
              ]),
            ),
          Divider(height: 1, color: at.border),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.notifications_none, size: 40, color: at.muted),
                      const SizedBox(height: 8),
                      Text('Nessuna notifica', style: TextStyle(color: at.muted)),
                    ]),
                  )
                : ListView.separated(
                    controller: sc,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: at.border),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.withValues(alpha: .85),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) => s.deleteNotification(n),
                        child: ListTile(
                          leading: Icon(
                            n.type == 'dm' ? Icons.chat_bubble_outline : (n.type == 'thread' || n.type == 'reply' ? Icons.forum_outlined : (n.type == 'mention' ? Icons.alternate_email : Icons.tag)),
                            color: n.read ? at.muted : at.accent,
                          ),
                          title: Text(n.type == 'dm' ? n.from : '${n.from} in #${n.channelName}', style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                          subtitle: Text(n.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(fmtTime(n.createdAt), style: TextStyle(color: at.muted, fontSize: 12)),
                            IconButton(
                              tooltip: 'Elimina notifica',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.close, size: 18, color: at.muted),
                              onPressed: () => s.deleteNotification(n),
                            ),
                          ]),
                          onTap: () {
                            Navigator.pop(ctx);
                            s.readNotification(n);
                            onOpened?.call();
                            s.openChannel(n.channelId);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ]);
      }),
    ),
  );
}
