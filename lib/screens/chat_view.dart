import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/composer.dart';
import '../widgets/message_tile.dart';

/// Elenco messaggi + composer di un canale (o di un thread se [thread] è valorizzato).
class MessageList extends StatefulWidget {
  final List<Message> messages;
  final bool loading, hasMore, inThread;
  final VoidCallback? onLoadMore;
  final Widget? header;
  final Widget? footer; // es. indicatore "l'assistente sta scrivendo"
  final void Function(Message) onEdit;
  const MessageList({super.key, required this.messages, this.loading = false, this.hasMore = false, this.inThread = false, this.onLoadMore, this.header, this.footer, required this.onEdit});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // lista invertita: maxScrollExtent = messaggi più vecchi
      if (widget.hasMore && !widget.loading && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) widget.onLoadMore?.call();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final list = widget.messages;
    final items = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      final prev = i > 0 ? list[i - 1] : null;
      final newDay = prev == null || !DateUtils.isSameDay(prev.createdAt, m.createdAt);
      if (newDay) items.add(_DayDivider(fmtDay(m.createdAt)));
      final compact = !newDay && prev.user.id == m.user.id && m.createdAt.difference(prev.createdAt).inMinutes < 5 && prev.kind != 'call';
      items.add(MessageTile(key: ValueKey(m.id), m: m, compact: compact, inThread: widget.inThread, onEdit: widget.onEdit));
    }
    final rev = [if (widget.footer != null) widget.footer!, ...items.reversed];
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      itemCount: rev.length + 1,
      itemBuilder: (_, i) {
        if (i < rev.length) return rev[i];
        if (widget.loading) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        if (widget.hasMore) return Center(child: TextButton(onPressed: widget.onLoadMore, child: const Text('Carica messaggi precedenti')));
        return widget.header ?? SizedBox(height: 24, child: Center(child: Text('', style: TextStyle(color: at.muted))));
      },
    );
  }
}

class _DayDivider extends StatelessWidget {
  final String label;
  const _DayDivider(this.label);

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(children: [
        Expanded(child: Divider(color: at.border)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(color: at.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: at.border)),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: at.text)),
        ),
        Expanded(child: Divider(color: at.border)),
      ]),
    );
  }
}

class ChatView extends StatefulWidget {
  final bool showBack;
  final VoidCallback? onBack;
  const ChatView({super.key, this.showBack = false, this.onBack});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _composer = GlobalKey<ComposerState>();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final at = AT.of(context);
    final c = s.active;
    if (c == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Logo(size: 56),
          const SizedBox(height: 14),
          Text('Seleziona un canale o un messaggio diretto', style: TextStyle(color: at.muted)),
        ]),
      );
    }
    final msgs = s.messages[c.id] ?? const <Message>[];
    if (s.lastError != null) {
      final err = s.lastError!;
      s.lastError = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), duration: const Duration(seconds: 6)));
      });
    }
    final title = Row(children: [
      if (c.otherUser != null) ...[Avatar(c.otherUser!, size: 24, showPresence: false), const SizedBox(width: 8)] else
        Icon(c.isAi ? Icons.auto_awesome_outlined : (c.type == 'private' ? Icons.lock_outline : Icons.tag), size: 18, color: at.text),
      if (c.otherUser == null) const SizedBox(width: 6),
      Flexible(child: Text(c.isAi && c.name.isEmpty ? s.org.aiBotName : c.name, overflow: TextOverflow.ellipsis)),
      if (c.isArchived) ...[const SizedBox(width: 8), Icon(Icons.archive_outlined, size: 16, color: at.muted)],
    ]);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.showBack ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
        titleSpacing: widget.showBack ? 0 : 16,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title,
          if ((c.topic ?? '').isNotEmpty) Text(c.topic!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: at.muted, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          if (!c.isAi && !c.isArchived)
            IconButton(
              tooltip: 'Avvia videochiamata',
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () async {
                try {
                  await s.startCall();
                } catch (e) {
                  if (context.mounted) toast(context, '$e');
                }
              },
            ),
          if (c.isChannel)
            PopupMenuButton<String>(
              tooltip: 'Opzioni canale',
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'leave') await s.leaveChannel(c);
                if (v == 'reload') await s.loadMessages(c.id);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reload', child: Text('Ricarica messaggi')),
                if (c.name != 'generale') const PopupMenuItem(value: 'leave', child: Text('Abbandona canale')),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: MessageList(
            key: ValueKey('ch-${c.id}'),
            messages: msgs,
            loading: s.loading.contains(c.id),
            hasMore: s.hasMore[c.id] ?? false,
            onLoadMore: () => s.loadMessages(c.id, older: true),
            onEdit: (m) => _composer.currentState?.startEdit(m),
            header: _ChannelIntro(c),
            footer: s.aiTyping.contains('c${c.id}') ? TypingRow(name: s.org.aiBotName) : null,
          ),
        ),
        Composer(
          key: _composer,
          disabled: c.isArchived,
          placeholder: c.isAi ? 'Chiedi a ${s.org.aiBotName}…' : (c.isChannel ? 'Scrivi in #${c.name}' : 'Scrivi a ${c.name}'),
        ),
      ]),
    );
  }
}

class _ChannelIntro extends StatelessWidget {
  final Channel c;
  const _ChannelIntro(this.c);

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.isChannel ? '#${c.name}' : c.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: at.text)),
        const SizedBox(height: 4),
        Text(c.isChannel ? 'Questo è l\'inizio del canale #${c.name}.' : 'Questo è l\'inizio della conversazione.', style: TextStyle(color: at.muted)),
      ]),
    );
  }
}

/// Pannello thread (laterale su desktop, schermata a parte su mobile).
class ThreadView extends StatefulWidget {
  final bool asPage;
  const ThreadView({super.key, this.asPage = false});

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  final _composer = GlobalKey<ComposerState>();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final at = AT.of(context);
    final root = s.threadRoot;
    if (root == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.asPage ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: s.closeThread) : null,
        titleSpacing: widget.asPage ? 0 : 16,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Thread'),
          Text(s.active?.label ?? '', style: TextStyle(fontSize: 12, color: at.muted, fontWeight: FontWeight.w400)),
        ]),
        actions: [if (!widget.asPage) IconButton(onPressed: s.closeThread, icon: const Icon(Icons.close), tooltip: 'Chiudi')],
      ),
      body: Column(children: [
        Expanded(
          child: MessageList(
            key: ValueKey('th-${root.id}'),
            inThread: true,
            messages: [root, ...s.threadReplies],
            footer: s.aiTyping.contains('t${root.id}') ? TypingRow(name: s.org.aiBotName) : null,
            onEdit: (m) => _composer.currentState?.startEdit(m),
          ),
        ),
        Composer(key: _composer, parentId: root.id, placeholder: 'Rispondi…', disabled: s.active?.isArchived == true),
      ]),
    );
  }
}

/// Riga animata "nome sta scrivendo…" mostrata mentre l'assistente AI genera la risposta.
class TypingRow extends StatefulWidget {
  final String name;
  const TypingRow({super.key, required this.name});
  @override
  State<TypingRow> createState() => _TypingRowState();
}

class _TypingRowState extends State<TypingRow> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        Avatar(AppUser(name: widget.name, initials: 'AI', isAi: true), size: 28),
        const SizedBox(width: 10),
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: at.muted.withValues(alpha: (((_c.value * 3 - i) % 3) < 1) ? 1 : .35),
                  shape: BoxShape.circle,
                ),
              ),
          ]),
        ),
        const SizedBox(width: 6),
        Text('${widget.name} sta scrivendo…', style: TextStyle(color: at.muted, fontSize: 13)),
      ]),
    );
  }
}
