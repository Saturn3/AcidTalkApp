import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'attachments.dart';
import 'common.dart';
import 'emoji_picker.dart';

const quickEmojis = ['👍', '❤️', '😂', '🎉', '👀', '✅'];

class MessageTile extends StatefulWidget {
  final Message m;
  final bool compact; // messaggio consecutivo dello stesso autore
  final bool inThread;
  final void Function(Message) onEdit;
  const MessageTile({super.key, required this.m, this.compact = false, this.inThread = false, required this.onEdit});

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  bool _hover = false;

  Message get m => widget.m;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final at = AT.of(context);
    final abs = s.api!.abs;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.compact)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  m.user.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: at.text, fontSize: 15),
                ),
              ),
              if (m.user.isAi) ...[const SizedBox(width: 6), _Tag('AI', at.accent)],
              if (m.user.isBot) ...[const SizedBox(width: 6), _Tag('BOT', const Color(0xFF0E7490))],
              if (m.user.isGuest) ...[const SizedBox(width: 6), _Tag('OSPITE', Colors.orange)],
              const SizedBox(width: 8),
              Text(fmtTime(m.createdAt), style: TextStyle(color: at.muted, fontSize: 12)),
              if (_receipt(s, at) case final w?) ...[const SizedBox(width: 6), w],
            ],
          ),
        if (m.html.trim().isNotEmpty && !(m.isVoice && m.body.trim().isEmpty))
          HtmlWidget(
            m.html,
            textStyle: TextStyle(color: at.text, fontSize: 15, height: 1.4),
            onTapUrl: (url) {
              if (s.openInternalLink(url)) return true;
              openUrl(url.startsWith('http') ? url : abs(url));
              return true;
            },
            customStylesBuilder: (e) => switch (e.localName) {
              'pre' => {
                'background-color': _css(at.codeBg),
                'border': '1px solid ${_css(at.border)}',
                'padding': '8px 10px',
                'border-radius': '6px',
                'font-family': 'monospace',
                'font-size': '13px',
                'white-space': 'pre-wrap',
              },
              'code' => {'font-family': 'monospace', 'font-size': '13px', 'background-color': _css(at.codeBg), 'color': e.parent?.localName == 'pre' ? _css(at.text) : '#e01e5a'},
              'blockquote' => {'border-left': '4px solid ${_css(at.border)}', 'padding-left': '10px', 'margin': '4px 0', 'color': _css(at.muted)},
              'a' => {'color': _css(at.accent), 'text-decoration': 'none'},
              'p' => e.classes.contains('jumbo') ? {'margin': '0', 'font-size': '34px', 'line-height': '1.25'} : {'margin': '0'},
              _ => null,
            },
            customWidgetBuilder: (e) {
              if (e.classes.contains('chan-ref')) {
                final id = int.tryParse(e.attributes['data-channel-id'] ?? '');
                return InlineCustomWidget(
                  child: InkWell(
                    onTap: id == null ? null : () => s.openChannel(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: at.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        e.text,
                        style: TextStyle(color: at.accent, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ),
                );
              }
              if (e.classes.contains('mention')) {
                return InlineCustomWidget(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: at.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      e.text,
                      style: TextStyle(color: at.accent, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                );
              }
              return null;
            },
          ),
        if (widget.compact)
          if (_receipt(s, at) case final w?) Align(alignment: Alignment.centerRight, child: w),
        if (m.editedAt != null) Text('(modificato)', style: TextStyle(color: at.muted, fontSize: 11)),
        for (final a in m.attachments) AttachmentView(a, abs: abs),
        for (final p in m.previews) LinkPreviewCard(p, onRemove: m.canEdit && p.kind != 'video_call' ? () => s.removePreview(m, p) : null),
        if (m.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in m.reactions)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => s.react(m, r.emoji),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: r.me ? at.accent.withValues(alpha: .12) : at.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: r.me ? at.accent : at.border),
                      ),
                      child: Text(
                        '${r.emoji} ${r.count}',
                        style: TextStyle(fontSize: 13, color: r.me ? at.accent : at.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                Tooltip(
                  message: 'Aggiungi reazione',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _pickReaction(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: at.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: at.border),
                      ),
                      child: Icon(Icons.add_reaction_outlined, size: 16, color: at.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!widget.inThread && m.replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () => s.openThread(m),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined, size: 15, color: at.accent),
                    const SizedBox(width: 6),
                    Text(
                      '${m.replyCount} ${m.replyCount == 1 ? 'risposta' : 'risposte'}',
                      style: TextStyle(color: at.accent, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (m.lastReplyAt != null) Text('  ultima ${fmtDay(m.lastReplyAt!).toLowerCase()} alle ${fmtTime(m.lastReplyAt!)}', style: TextStyle(color: at.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onLongPress: () => _sheet(context),
        child: Container(
          color: _hover ? at.surface2 : Colors.transparent,
          padding: EdgeInsets.fromLTRB(16, widget.compact ? 2 : 8, 16, 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: widget.compact
                        ? (_hover
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(fmtTime(m.createdAt), style: TextStyle(color: at.muted, fontSize: 10)),
                                )
                              : null)
                        : Avatar(m.user, size: 36),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: body),
                ],
              ),
              if (_hover)
                Positioned(
                  top: -6,
                  right: 0,
                  child: Material(
                    elevation: 2,
                    color: at.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: at.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in quickEmojis.take(3)) _ToolBtn(label: e, tooltip: 'Reagisci', onTap: () => s.react(m, e)),
                          _ToolBtn(icon: Icons.add_reaction_outlined, tooltip: 'Scegli una reazione', onTap: () => _pickReaction(context)),
                          if (!widget.inThread) _ToolBtn(icon: Icons.forum_outlined, tooltip: 'Rispondi nel thread', onTap: () => s.openThread(m)),
                          _ToolBtn(icon: Icons.more_horiz, tooltip: 'Altro', onTap: () => _sheet(context)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReaction(BuildContext context) async {
    final s = context.read<AppState>();
    final e = await pickEmoji(context);
    if (e != null) await s.react(m, e);
  }

  /// Conferma di lettura sui propri messaggi: una spunta = inviato, due spunte = letto (blu se letto da tutti).
  Widget? _receipt(AppState s, AT at) {
    if (!s.readReceiptsEnabled || m.user.id != s.me?.id || m.id <= 0) return null;
    final readers = s.readersOf(m);
    final others = s.othersIn(m.channelId);
    final all = others.isNotEmpty && readers.length >= others.length;
    final tip = readers.isEmpty ? 'Inviato' : 'Letto da ${readers.map((r) => r.name).take(8).join(', ')}${readers.length > 8 ? ' e altri ${readers.length - 8}' : ''}';
    return Tooltip(
      message: tip,
      child: Icon(readers.isEmpty ? Icons.check : Icons.done_all, size: 15, color: all ? const Color(0xFF1D9BD1) : at.muted),
    );
  }

  Future<void> _sheet(BuildContext context) async {
    final s = context.read<AppState>();
    final at = AT.of(context);
    await showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in quickEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.pop(ctx);
                        s.react(m, e);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: at.surface2, shape: BoxShape.circle),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  Tooltip(
                    message: 'Altre emoji',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickReaction(context);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: at.surface2, shape: BoxShape.circle),
                        child: Icon(Icons.add_reaction_outlined, size: 22, color: at.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.inThread)
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Rispondi nel thread'),
                onTap: () {
                  Navigator.pop(ctx);
                  s.openThread(m);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copia testo'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.body));
                Navigator.pop(ctx);
                toast(context, 'Testo copiato');
              },
            ),
            if (m.canEdit && !m.isVoice)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifica messaggio'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEdit(m);
                },
              ),
            if (m.canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline, color: at.mention),
                title: Text('Elimina messaggio', style: TextStyle(color: at.mention)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Eliminare il messaggio?'),
                      content: const Text('L\'operazione non può essere annullata.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annulla')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: at.mention),
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Elimina'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await s.delete(m);
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _css(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class _Tag extends StatelessWidget {
  final String t;
  final Color c;
  const _Tag(this.t, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(3)),
    child: Text(
      t,
      style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _ToolBtn extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolBtn({this.icon, this.label, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 32,
        height: 30,
        child: Center(
          child: icon != null ? Icon(icon, size: 17, color: AT.of(context).muted) : Text(label!, style: const TextStyle(fontSize: 15)),
        ),
      ),
    ),
  );
}
