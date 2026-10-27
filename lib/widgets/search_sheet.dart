import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Apre la ricerca nei messaggi: finestra centrata su schermi larghi, foglio a tutta altezza su telefono.
/// Con [channel] la ricerca parte limitata a quella conversazione (si può estendere a tutti i canali).
Future<void> showSearchSheet(BuildContext context, {Channel? channel, VoidCallback? onOpened}) async {
  final wide = MediaQuery.sizeOf(context).width >= 900;
  final panel = SearchPanel(channel: channel, onOpened: onOpened);
  if (wide) {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        alignment: const Alignment(0, -.5),
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620), child: panel),
      ),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: .92, child: panel),
    );
  }
}

class SearchPanel extends StatefulWidget {
  final Channel? channel;
  final VoidCallback? onOpened;
  const SearchPanel({super.key, this.channel, this.onOpened});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final _q = TextEditingController();
  Timer? _debounce;
  late bool _onlyHere = widget.channel != null;
  List<Message> _items = const [];
  Map<int, String> _names = const {};
  bool _loading = false;
  String? _error;
  String _lastQuery = '';
  int _sel = 0;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _run);
    setState(() {});
  }

  Future<void> _run() async {
    final q = _q.text.trim();
    if (q.length < 2) {
      setState(() {
        _items = const [];
        _error = null;
        _lastQuery = '';
      });
      return;
    }
    final s = context.read<AppState>();
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await s.search(q, channelId: _onlyHere ? widget.channel?.id : null);
      if (!mounted || seq != _seq) return;
      setState(() {
        _items = r.items;
        _names = r.channels;
        _lastQuery = q;
        _sel = 0;
      });
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = '$e');
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  Future<void> _open(Message m) async {
    final s = context.read<AppState>();
    Navigator.of(context).pop();
    widget.onOpened?.call();
    try {
      await s.openMessage(m);
    } catch (_) {}
  }

  String _channelName(Message m) {
    final s = context.read<AppState>();
    final c = s.channels.where((c) => c.id == m.channelId).firstOrNull;
    final n = _names[m.channelId] ?? c?.name ?? '${m.channelId}';
    final isDm = c != null && !c.isChannel;
    return isDm ? n : '#$n';
  }

  static String _plain(String md) =>
      md.replaceAll(RegExp(r'^\s*(?:[-*+•]|\d{1,4}[.)])\s+', multiLine: true), '').replaceAll(RegExp(r'```[a-z]*\n?'), '').replaceAll(RegExp(r'[*_`>~]+'), '').replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1').replaceAll(RegExp(r'\s*\n\s*'), ' · ').trim();

  /// Estratto centrato sulla prima occorrenza, con le parole cercate evidenziate.
  List<TextSpan> _highlight(String text, String q, AT at) {
    final lower = text.toLowerCase(), ql = q.toLowerCase();
    var start = 0;
    final first = lower.indexOf(ql);
    if (first > 90) start = text.lastIndexOf(' ', first - 60).clamp(0, first);
    final t = (start > 0 ? '…' : '') + text.substring(start);
    final tl = t.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (ql.isNotEmpty) {
      final j = tl.indexOf(ql, i);
      if (j < 0) break;
      if (j > i) spans.add(TextSpan(text: t.substring(i, j)));
      spans.add(
        TextSpan(
          text: t.substring(j, j + ql.length),
          style: TextStyle(backgroundColor: Colors.amber.withValues(alpha: .35), color: at.text, fontWeight: FontWeight.w700),
        ),
      );
      i = j + ql.length;
    }
    spans.add(TextSpan(text: t.substring(i)));
    return spans;
  }

  KeyEventResult _keys(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || _items.isEmpty) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _sel = (_sel + 1) % _items.length);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _sel = (_sel - 1 + _items.length) % _items.length);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _open(_items[_sel]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final c = widget.channel;
    final q = _q.text.trim();
    return Material(
      color: at.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: _keys,
                    child: TextField(
                      controller: _q,
                      autofocus: true,
                      onChanged: _changed,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _items.isNotEmpty && _lastQuery == q ? _open(_items[_sel]) : _run(),
                      style: TextStyle(color: at.text, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: c != null && _onlyHere ? 'Cerca in ${c.isChannel ? '#${c.name}' : c.name}…' : 'Cerca nei messaggi…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _q.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Cancella',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _q.clear();
                                  _changed('');
                                },
                              ),
                        isDense: true,
                        filled: true,
                        fillColor: at.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: at.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: at.border),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(tooltip: 'Chiudi', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          if (c != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(c.isChannel ? 'In #${c.name}' : 'In questa conversazione'),
                    selected: _onlyHere,
                    onSelected: (_) {
                      setState(() => _onlyHere = true);
                      _run();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('In tutti i canali'),
                    selected: !_onlyHere,
                    onSelected: (_) {
                      setState(() => _onlyHere = false);
                      _run();
                    },
                  ),
                ],
              ),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          Divider(height: 1, color: at.border),
          Expanded(child: _results(at, q)),
        ],
      ),
    );
  }

  Widget _results(AT at, String q) {
    Widget msg(IconData icon, String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: at.muted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: at.muted),
            ),
          ],
        ),
      ),
    );
    if (_error != null) return msg(Icons.error_outline, _error!);
    if (q.length < 2) return msg(Icons.manage_search, 'Digita almeno 2 caratteri per cercare nel testo dei messaggi.');
    if (_items.isEmpty) return _loading || _lastQuery != q ? const SizedBox() : msg(Icons.search_off, 'Nessun messaggio contiene "$q".');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _items.length + 1,
      separatorBuilder: (_, i) => Divider(height: 1, indent: 62, color: at.border.withValues(alpha: .6)),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              _items.length >= 40 ? 'Sono mostrati i 40 risultati più recenti: aggiungi parole per restringere la ricerca.' : '${_items.length} risultati',
              textAlign: TextAlign.center,
              style: TextStyle(color: at.muted, fontSize: 12),
            ),
          );
        }
        final m = _items[i];
        final body = _plain(m.body);
        return InkWell(
          onTap: () => _open(m),
          child: Container(
            color: i == _sel ? at.accent.withValues(alpha: .08) : null,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(m.user, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    m.user.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: at.text, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'in ${_channelName(m)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: at.muted, fontSize: 12.5),
                                  ),
                                ),
                                if (m.parentId != null) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.forum_outlined, size: 13, color: at.muted),
                                  Text(' thread', style: TextStyle(color: at.muted, fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${fmtDay(m.createdAt)} ${fmtTime(m.createdAt)}', style: TextStyle(color: at.muted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(children: body.isEmpty ? [const TextSpan(text: '[allegato]')] : _highlight(body, q, at)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: at.text, fontSize: 14, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
