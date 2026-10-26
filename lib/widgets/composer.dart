import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'emoji_picker.dart';

/// Barra di scrittura: testo con Markdown, allegati, messaggi vocali, modifica di un messaggio.
class Composer extends StatefulWidget {
  final String placeholder;
  final int? parentId;
  final bool disabled;
  const Composer({super.key, required this.placeholder, this.parentId, this.disabled = false});

  @override
  State<Composer> createState() => ComposerState();
}

class ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final List<Attachment> _files = [];
  double? _progress;
  bool _sending = false;
  Message? _editing;

  final _rec = AudioRecorder();
  bool _recording = false;
  DateTime? _recStart;
  Timer? _recTimer;

  bool get _desktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    EmojiCatalog.load();
    _focus.onKeyEvent = (node, e) {
      if (e is KeyDownEvent && _emojiHits.isNotEmpty) {
        final k = e.logicalKey;
        if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.tab) {
          _applyEmoji(_emojiHits[_emojiSel].char);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowDown) {
          setState(() => _emojiSel = (_emojiSel + 1) % _emojiHits.length);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowUp) {
          setState(() => _emojiSel = (_emojiSel - 1 + _emojiHits.length) % _emojiHits.length);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.escape) {
          setState(() => _emojiHits = const []);
          return KeyEventResult.handled;
        }
      }
      if (_desktop && e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
        _submit();
        return KeyEventResult.handled;
      }
      if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape && _editing != null) {
        cancelEdit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _text.addListener(() {
      _emojiWatch();
      setState(() {});
    });
  }

  // ---- inserimento rapido emoji con ":" (es. :pollice → 👍) ----
  List<EmojiItem> _emojiHits = const [];
  int _emojiSel = 0;
  String _emojiLast = '';
  static final _emojiRe = RegExp(r'(?:^|\s):([\p{L}\d_+\-]{2,})$', unicode: true);

  void _emojiWatch() {
    final sel = _text.selection;
    final pos = sel.isValid && sel.isCollapsed ? sel.baseOffset : -1;
    final m = pos >= 0 ? _emojiRe.firstMatch(_text.text.substring(0, pos)) : null;
    final q = m?.group(1) ?? '';
    if (q == _emojiLast) return;
    _emojiLast = q;
    _emojiHits = q.isEmpty ? const [] : EmojiCatalog.search(q, limit: 12);
    _emojiSel = 0;
  }

  void _applyEmoji(String e) {
    final pos = _text.selection.baseOffset;
    final before = _text.text.substring(0, pos);
    final start = before.lastIndexOf(':');
    if (start < 0) return;
    final t = '${_text.text.substring(0, start)}$e ${_text.text.substring(pos)}';
    _emojiHits = const [];
    _emojiLast = '';
    _text.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: start + e.length + 1));
    EmojiCatalog.remember(e);
    _focus.requestFocus();
  }

  Future<void> _openEmojiPicker() async {
    final e = await pickEmoji(context);
    if (e == null) return;
    final sel = _text.selection;
    final pos = sel.isValid ? sel.baseOffset : _text.text.length;
    final t = _text.text.replaceRange(pos, sel.isValid ? sel.extentOffset : pos, e);
    _text.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + e.length));
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _rec.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void startEdit(Message m) {
    setState(() => _editing = m);
    _text.text = m.body;
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
    _focus.requestFocus();
  }

  void cancelEdit() {
    setState(() => _editing = null);
    _text.clear();
  }

  Future<void> _submit() async {
    final s = context.read<AppState>();
    final body = _text.text.trim();
    if (_sending || (body.isEmpty && _files.isEmpty)) return;
    setState(() => _sending = true);
    try {
      if (_editing != null) {
        await s.edit(_editing!, body);
        _editing = null;
      } else {
        await s.send(body, parentId: widget.parentId, attachments: List.of(_files));
        _files.clear();
      }
      _text.clear();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
      _focus.requestFocus();
    }
  }

  Future<void> _pickFiles() async {
    final s = context.read<AppState>();
    final files = await FilePicker.pickFiles();
    for (final f in files) {
      if (f.path == null) continue;
      if (File(f.path!).lengthSync() > s.org.maxUploadMb * 1024 * 1024) {
        if (mounted) toast(context, '${f.name}: supera il limite di ${s.org.maxUploadMb} MB');
        continue;
      }
      setState(() => _progress = 0);
      try {
        final a = await s.api!.upload(f.path!, name: f.name, onProgress: (p) => mounted ? setState(() => _progress = p) : null);
        setState(() => _files.add(a));
      } on ApiException catch (e) {
        if (mounted) toast(context, e.message);
      } finally {
        if (mounted) setState(() => _progress = null);
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) return _stopRecording(send: true);
    if (!await _rec.hasPermission()) {
      if (mounted) toast(context, 'Consenti l\'accesso al microfono per registrare un messaggio vocale');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}${Platform.pathSeparator}voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: path);
    setState(() {
      _recording = true;
      _recStart = DateTime.now();
    });
    _recTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => mounted ? setState(() {}) : null);
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    final path = await _rec.stop();
    final secs = DateTime.now().difference(_recStart ?? DateTime.now()).inMilliseconds / 1000;
    setState(() => _recording = false);
    if (!send || path == null) {
      if (path != null) File(path).delete().catchError((_) => File(path));
      return;
    }
    if (secs < .8) {
      if (mounted) toast(context, 'Registrazione troppo breve');
      return;
    }
    if (!mounted) return;
    final s = context.read<AppState>();
    setState(() => _sending = true);
    try {
      final a = await s.api!.upload(path, name: 'voice-${DateTime.now().millisecondsSinceEpoch}.m4a', duration: secs, voice: true);
      await s.send('', parentId: widget.parentId, attachments: [a], kind: 'voice');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
      File(path).delete().catchError((_) => File(path));
    }
  }

  void _wrap(String l, [String? r]) {
    final sel = _text.selection;
    final t = _text.text;
    if (!sel.isValid) {
      _text.text = '$t$l${r ?? l}';
      return;
    }
    final inner = sel.textInside(t);
    _text.value = TextEditingValue(
      text: sel.textBefore(t) + l + inner + (r ?? l) + sel.textAfter(t),
      selection: TextSelection.collapsed(offset: sel.start + l.length + inner.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final canSend = _text.text.trim().isNotEmpty || _files.isNotEmpty;
    if (widget.disabled) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: at.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: at.border)),
        child: Row(children: [Icon(Icons.archive_outlined, color: at.muted), const SizedBox(width: 10), Text('Canale archiviato: sola lettura', style: TextStyle(color: at.muted))]),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        decoration: BoxDecoration(
          color: at.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focus.hasFocus ? at.muted : at.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_editing != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: .15), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
              child: Row(children: [
                const Icon(Icons.edit_outlined, size: 16),
                const SizedBox(width: 8),
                const Expanded(child: Text('Modifica del messaggio — Esc per annullare', style: TextStyle(fontSize: 13))),
                IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 16), onPressed: cancelEdit),
              ]),
            ),
          if (_files.isNotEmpty || _progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in _files)
                  InputChip(
                    avatar: Icon(f.kind == 'image' ? Icons.image_outlined : (f.kind == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.attach_file), size: 16),
                    label: Text(f.name, overflow: TextOverflow.ellipsis),
                    onDeleted: () => setState(() => _files.remove(f)),
                  ),
                if (_progress != null) SizedBox(width: 140, child: LinearProgressIndicator(value: _progress)),
              ]),
            ),
          if (_emojiHits.isNotEmpty && !_recording)
            Container(
              height: 40,
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              decoration: BoxDecoration(color: at.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: at.border)),
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 4), children: [
                for (var i = 0; i < _emojiHits.length; i++)
                  Tooltip(
                    message: ':${_emojiHits[i].aliases.first}:',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _applyEmoji(_emojiHits[i].char),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(color: i == _emojiSel ? at.accent.withValues(alpha: .14) : null, borderRadius: BorderRadius.circular(6)),
                        alignment: Alignment.center,
                        child: Row(children: [
                          Text(_emojiHits[i].char, style: const TextStyle(fontSize: 20)),
                          if (i == _emojiSel) ...[const SizedBox(width: 6), Text(':${_emojiHits[i].aliases.first}:', style: TextStyle(color: at.muted, fontSize: 12))],
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          if (_recording)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: at.mention, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text('Registrazione in corso  ${fmtDuration(DateTime.now().difference(_recStart!))}', style: TextStyle(color: at.text, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () => _stopRecording(send: false), child: const Text('Annulla')),
              ]),
            )
          else
            TextField(
              controller: _text,
              focusNode: _focus,
              minLines: 1,
              maxLines: 8,
              textInputAction: _desktop ? TextInputAction.none : TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: TextStyle(color: at.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 6, 4),
            child: Row(children: [
              _Btn(Icons.add_circle_outline, 'Allega file', _recording || _editing != null ? null : _pickFiles),
              _Btn(Icons.format_bold, 'Grassetto', _recording ? null : () => _wrap('**')),
              _Btn(Icons.format_italic, 'Corsivo', _recording ? null : () => _wrap('_')),
              _Btn(Icons.code, 'Codice', _recording ? null : () => _wrap('`')),
              _Btn(Icons.data_object, 'Blocco di codice', _recording ? null : () => _wrap('```\n', '\n```')),
              _Btn(Icons.alternate_email, 'Menziona', _recording ? null : () => _wrap('@', '')),
              _Btn(Icons.sentiment_satisfied_outlined, 'Emoji (oppure digita : e due lettere)', _recording ? null : _openEmojiPicker),
              const Spacer(),
              if (!canSend && _editing == null)
                _Btn(_recording ? Icons.stop_circle_outlined : Icons.mic_none_outlined, _recording ? 'Invia messaggio vocale' : 'Registra messaggio vocale', _sending ? null : _toggleRecording, color: _recording ? at.mention : null),
              if (canSend || _editing != null || _recording)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Material(
                    color: canSend || _recording ? const Color(0xFF007A5A) : at.surface2,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _sending ? null : (_recording ? () => _stopRecording(send: true) : _submit),
                      child: SizedBox(
                        width: 36,
                        height: 30,
                        child: _sending
                            ? const Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_editing != null ? Icons.check : Icons.send_rounded, size: 18, color: canSend || _recording ? Colors.white : at.muted),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final Color? color;
  const _Btn(this.icon, this.tip, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        iconSize: 19,
        onPressed: onTap,
        color: color ?? AT.of(context).muted,
        icon: Icon(icon),
      );
}
