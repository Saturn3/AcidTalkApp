import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notifier.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const appVersion = '2.5.1';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final at = AT.of(context);
    final me = s.me;
    if (me == null) return const SizedBox.shrink();
    final push = me.prefs['push'] != false;
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo e preferenze')),
      body: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(
                leading: Avatar(me, size: 48),
                title: Text(me.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                subtitle: Text([me.email, me.title].whereType<String>().join(' · ')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(me.avatarUrl == null ? 'Imposta immagine profilo' : 'Cambia immagine'),
                    onPressed: () => _pickAvatar(context, s),
                  ),
                  if (me.avatarUrl != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Rimuovi'),
                      onPressed: () async {
                        try {
                          await s.removeAvatar();
                        } catch (e) {
                          if (context.mounted) toast(context, '$e');
                        }
                      },
                    ),
                ]),
              ),
              _hdr('Aspetto', at),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_outlined), label: Text('Chiaro')),
                    ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_outlined), label: Text('Scuro')),
                    ButtonSegment(value: 'system', icon: Icon(Icons.desktop_windows_outlined), label: Text('Sistema')),
                  ],
                  selected: {s.themePref},
                  onSelectionChanged: (v) => s.setTheme(v.first),
                ),
              ),
              _hdr('Barra laterale', at),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('Ordinamento canali'),
                trailing: DropdownButton<SortMode>(
                  value: s.sort,
                  underline: const SizedBox(),
                  onChanged: (v) => v == null ? null : s.setSort(v),
                  items: const [
                    DropdownMenuItem(value: SortMode.recent, child: Text('Attività recente')),
                    DropdownMenuItem(value: SortMode.alpha, child: Text('Ordine alfabetico')),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Conversazioni mostrate'),
                subtitle: Text('Messaggi diretti attivi negli ultimi ${s.org.dmDays} giorni, canali negli ultimi ${s.org.channelDays} (impostabile dall\'amministratore)'),
              ),
              _hdr('Notifiche', at),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_none_outlined),
                title: const Text('Notifiche sul dispositivo'),
                subtitle: const Text('Menzioni, messaggi diretti e risposte ai tuoi thread'),
                value: push,
                onChanged: (v) async {
                  if (v) await Notifier.instance.requestPermission();
                  await s.setPush(v);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notification_add_outlined),
                title: const Text('Invia una notifica di prova'),
                onTap: () async {
                  final ok = await Notifier.instance.requestPermission();
                  await Notifier.instance.show(id: 1, title: 'AcidTalk', body: ok ? 'Le notifiche funzionano correttamente.' : 'Permesso negato: abilitalo nelle impostazioni di sistema.');
                },
              ),
              ListTile(
                leading: Icon(Icons.cloud_outlined, color: s.pushAvailable && s.org.pushEnabled ? at.online : at.muted),
                title: const Text('Notifiche push (app chiusa)'),
                subtitle: Text(!s.org.pushEnabled
                    ? 'Il server non ha Firebase configurato (Amministrazione › Push)'
                    : (s.pushStatus ?? (s.pushAvailable ? 'In attivazione…' : 'Non disponibili in questa build'))),
              ),
              ListTile(
                leading: Icon(Icons.sync, color: s.realtimeConnected ? at.online : Colors.amber),
                title: Text(s.realtimeConnected ? 'Sincronizzazione in tempo reale attiva' : 'Sincronizzazione periodica (ogni 6 secondi)'),
                subtitle: Text(s.realtimeConnected ? 'Collegato al server WebSocket (Pusher o Reverb)' : 'Il server non ha un WebSocket configurato: l\'app controlla i nuovi messaggi in automatico'),
              ),
              _hdr('Account', at),
              ListTile(leading: const Icon(Icons.dns_outlined), title: const Text('Server'), subtitle: Text(s.server)),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('Versione app'), subtitle: const Text(appVersion)),
              ListTile(
                leading: Icon(Icons.logout, color: at.mention),
                title: Text('Esci', style: TextStyle(color: at.mention, fontWeight: FontWeight.w700)),
                onTap: () async {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  await s.logout();
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _pickAvatar(BuildContext context, AppState s) async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty || files.first.path == null) return;
    try {
      await s.updateAvatar(files.first.path!, name: files.first.name);
      if (context.mounted) toast(context, 'Immagine profilo aggiornata');
    } catch (e) {
      if (context.mounted) toast(context, '$e');
    }
  }

  Widget _hdr(String t, AT at) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
        child: Text(t.toUpperCase(), style: TextStyle(color: at.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6)),
      );
}
