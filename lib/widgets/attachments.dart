import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../theme.dart';
import 'audio_player.dart';
import 'common.dart';

Future<void> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class AttachmentView extends StatelessWidget {
  final Attachment a;
  final String Function(String) abs;
  const AttachmentView(this.a, {super.key, required this.abs});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final url = abs(a.url);
    if (a.isAudio) return VoicePlayer(attachment: a, url: url);
    if (a.kind == 'image') {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: () => _showImage(context, url, a.name),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 280),
              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => _FileCard(a: a, url: url)),
            ),
          ),
        ),
      );
    }
    return _FileCard(a: a, url: url, color: at.surface2);
  }

  void _showImage(BuildContext context, String url, String name) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Stack(children: [
        Positioned.fill(child: InteractiveViewer(child: Center(child: Image.network(url)))),
        Positioned(
          top: 16,
          right: 16,
          child: Row(children: [
            IconButton.filledTonal(onPressed: () => openUrl(url), icon: const Icon(Icons.download_outlined), tooltip: 'Apri / scarica'),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close), tooltip: 'Chiudi'),
          ]),
        ),
      ]),
    );
  }
}

class _FileCard extends StatelessWidget {
  final Attachment a;
  final String url;
  final Color? color;
  const _FileCard({required this.a, required this.url, this.color});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final (icon, tint, label) = switch (a.kind) {
      'pdf' => (Icons.picture_as_pdf_outlined, const Color(0xFFD93025), 'PDF'),
      'video' => (Icons.movie_outlined, const Color(0xFF7C3AED), 'Video'),
      _ => (Icons.insert_drive_file_outlined, at.accent, a.name.contains('.') ? a.name.split('.').last.toUpperCase() : 'File'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: color ?? at.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: at.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openUrl(url),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: tint.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: at.text)),
                  Text('$label · ${fmtSize(a.size)}', style: TextStyle(color: at.muted, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 10),
              Icon(a.kind == 'video' ? Icons.play_circle_outline : Icons.open_in_new, size: 18, color: at.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Anteprime dei link: card con immagine, video con miniatura e pulsante "Partecipa" per le videochiamate.
class LinkPreviewCard extends StatelessWidget {
  final LinkPreview p;
  final VoidCallback? onRemove;
  const LinkPreviewCard(this.p, {super.key, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    if (p.kind == 'video_call') {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: at.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: at.border)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFF007A5A).withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.videocam_outlined, color: Color(0xFF007A5A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title ?? 'Videochiamata', style: TextStyle(fontWeight: FontWeight.w800, color: at.text)),
              Text(p.siteName ?? p.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.muted, fontSize: 12)),
            ]),
          ),
          FilledButton(onPressed: () => openUrl(p.url), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)), child: const Text('Partecipa')),
        ]),
      );
    }
    final host = Uri.tryParse(p.url)?.host.replaceFirst('www.', '') ?? '';
    final large = p.kind == 'video' || p.provider == 'large' || p.kind == 'image';
    final img = p.image == null
        ? null
        : Image.network(p.image!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink());
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: at.border, width: 4))),
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        onTap: () => openUrl(p.url),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Image.network('https://www.google.com/s2/favicons?domain=$host&sz=32', width: 14, height: 14, errorBuilder: (_, _, _) => Icon(Icons.public, size: 14, color: at.muted)),
            const SizedBox(width: 6),
            Expanded(child: Text(p.siteName ?? host, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.muted, fontSize: 12, fontWeight: FontWeight.w600))),
            if (onRemove != null)
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(10),
                child: Tooltip(message: 'Rimuovi anteprima', child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.close, size: 14, color: at.muted))),
              ),
          ]),
          if (p.title != null) ...[
            const SizedBox(height: 2),
            Text(p.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.accent, fontWeight: FontWeight.w700)),
          ],
          if (!large || img == null)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.description != null)
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(p.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.text, fontSize: 13)))),
              if (img != null) ...[const SizedBox(width: 10), ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 72, height: 72, child: img))],
            ])
          else ...[
            if (p.description != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(p.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.text, fontSize: 13))),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360, maxHeight: 203),
                child: Stack(alignment: Alignment.center, children: [
                  AspectRatio(aspectRatio: 16 / 9, child: img),
                  if (p.kind == 'video')
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                    ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
