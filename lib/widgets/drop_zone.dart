import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Area che accetta file trascinati dal sistema operativo (solo app desktop) e li passa a [onFiles].
/// Durante il trascinamento mostra un velo con l'invito a rilasciare i file.
class FileDropZone extends StatefulWidget {
  final Widget child;
  final void Function(List<String> paths) onFiles;
  final String? target;
  final bool enabled;
  const FileDropZone({super.key, required this.child, required this.onFiles, this.target, this.enabled = true});

  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    if (!FileDropZone.supported) return widget.child;
    final at = AT.of(context);
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (d) {
        setState(() => _over = false);
        final paths = [
          for (final f in d.files)
            if (f.path.isNotEmpty) f.path,
        ];
        if (paths.isNotEmpty) widget.onFiles(paths);
      },
      child: Stack(
        children: [
          widget.child,
          if (_over)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: at.surface.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: at.accent, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file_outlined, size: 44, color: at.accent),
                      const SizedBox(height: 10),
                      Text(
                        'Rilascia i file per allegarli',
                        style: TextStyle(color: at.text, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      if (widget.target != null) ...[const SizedBox(height: 4), Text(widget.target!, style: TextStyle(color: at.muted, fontSize: 13))],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
