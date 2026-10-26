import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import 'common.dart';

/// Un solo player attivo alla volta (come nel client web).
class _Exclusive {
  static AudioPlayer? current;
  static void claim(AudioPlayer p) {
    if (current != null && current != p) current!.pause();
    current = p;
  }
}

/// Player per messaggi vocali e file audio: play/pausa, forma d'onda cliccabile, tempo, velocità.
class VoicePlayer extends StatefulWidget {
  final Attachment attachment;
  final String url;
  final Map<String, String> headers;
  const VoicePlayer({super.key, required this.attachment, required this.url, this.headers = const {}});

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero, _dur = Duration.zero;
  double _rate = 1;
  bool _loaded = false, _loading = false;
  String? _error;
  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    // forma d'onda pseudo-casuale ma stabile per ogni allegato
    final r = Random(widget.attachment.id);
    _bars = List.generate(40, (i) => .25 + r.nextDouble() * .75 * (0.6 + 0.4 * sin(i / 3).abs()));
    if (widget.attachment.duration != null) _dur = Duration(milliseconds: (widget.attachment.duration! * 1000).round());
    _subs.add(_player.onPlayerStateChanged.listen((s) => mounted ? setState(() => _state = s) : null));
    _subs.add(_player.onPositionChanged.listen((p) => mounted ? setState(() => _pos = p) : null));
    _subs.add(_player.onDurationChanged.listen((d) => mounted && d > Duration.zero ? setState(() => _dur = d) : null));
    _subs.add(_player.onPlayerComplete.listen((_) => mounted ? setState(() => _pos = Duration.zero) : null));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    if (_Exclusive.current == _player) _Exclusive.current = null;
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    setState(() => _loading = true);
    try {
      await _player.setSourceUrl(widget.url, mimeType: widget.attachment.mime.isEmpty ? null : widget.attachment.mime);
      await _player.setPlaybackRate(_rate);
      _loaded = true;
    } catch (e) {
      _error = 'Formato audio non supportato su questo dispositivo';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) return _player.pause();
    await _ensureLoaded();
    if (!_loaded) return;
    _Exclusive.claim(_player);
    await _player.resume();
  }

  Future<void> _seek(double f) async {
    await _ensureLoaded();
    if (!_loaded || _dur == Duration.zero) return;
    await _player.seek(Duration(milliseconds: (_dur.inMilliseconds * f.clamp(0, 1)).round()));
    if (mounted) setState(() {});
  }

  Future<void> _cycleRate() async {
    _rate = _rate == 1 ? 1.5 : (_rate == 1.5 ? 2 : 1);
    if (_loaded) await _player.setPlaybackRate(_rate);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final playing = _state == PlayerState.playing;
    final progress = _dur.inMilliseconds == 0 ? 0.0 : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    final isVoice = widget.attachment.name.startsWith('voice') || widget.attachment.duration != null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      decoration: BoxDecoration(color: at.surface2, borderRadius: BorderRadius.circular(24), border: Border.all(color: at.border)),
      child: Row(children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Material(
            color: at.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _error == null ? _toggle : null,
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _error != null
              ? Text(_error!, style: TextStyle(color: at.muted, fontSize: 12))
              : LayoutBuilder(
                  builder: (_, c) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _seek(d.localPosition.dx / c.maxWidth),
                    onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx / c.maxWidth),
                    child: SizedBox(
                      height: 30,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        for (var i = 0; i < _bars.length; i++)
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 2.5,
                                height: 4 + 22 * _bars[i],
                                decoration: BoxDecoration(
                                  color: (i + .5) / _bars.length <= progress ? at.accent : at.muted.withValues(alpha: .35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Text(
          playing || _pos > Duration.zero ? fmtDuration(_pos) : fmtDuration(_dur),
          style: TextStyle(color: at.muted, fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: _cycleRate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: at.border)),
            child: Text('${_rate == 1 ? '1' : _rate}×', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: at.muted)),
          ),
        ),
        if (!isVoice) ...[
          const SizedBox(width: 6),
          Icon(Icons.audio_file_outlined, size: 16, color: at.muted),
        ],
      ]),
    );
  }
}
