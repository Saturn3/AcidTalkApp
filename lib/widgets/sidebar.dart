import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'dialogs.dart';

/// Barra laterale stile Slack: messaggi diretti in alto, canali ordinabili, filtro attività recente.
class Sidebar extends StatefulWidget {
  final VoidCallback? onOpened;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  const Sidebar({super.key, this.onOpened, required this.onProfile, required this.onNotifications});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  // Il controller vive con lo stato: la posizione di scorrimento resta invariata durante la sincronizzazione.
  final _scroll = ScrollController(keepScrollOffset: true);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(Channel c) async {
    widget.onOpened?.call();
    await context.read<AppState>().openChannel(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final at = AT.of(context);
    final dms = s.sidebarDms;
    final chans = s.sidebarChannels;
    final ai = s.aiChannels;

    return Container(
      color: at.sidebar,
      child: SafeArea(
        right: false,
        child: Column(children: [
          // intestazione organizzazione
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: .1)))),
            child: Row(children: [
              const Logo(size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(s.org.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.sidebarText, fontWeight: FontWeight.w800, fontSize: 16))),
              _HeaderBtn(
                icon: Icons.notifications_none_outlined,
                tooltip: 'Notifiche',
                badge: s.unreadNotifications,
                onTap: widget.onNotifications,
              ),
              _HeaderBtn(icon: Icons.edit_square, tooltip: 'Nuovo messaggio', onTap: () => showNewDm(context, onOpened: widget.onOpened)),
            ]),
          ),
          Expanded(
            child: ListView(
              key: const PageStorageKey('sidebar'),
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                if (ai.isNotEmpty)
                  for (final c in ai) _Item(icon: Icons.auto_awesome_outlined, label: c.name.isEmpty ? s.org.aiBotName : c.name, channel: c, onTap: () => _open(c))
                else
                  _Item(icon: Icons.auto_awesome_outlined, label: 'Assistente ${s.org.aiBotName}', onTap: () async {
                    widget.onOpened?.call();
                    await s.openAi();
                  }),
                const SizedBox(height: 8),
                _Section(
                  title: 'Messaggi diretti',
                  trailing: _SmallBtn(icon: Icons.add, tooltip: 'Nuovo messaggio diretto', onTap: () => showNewDm(context, onOpened: widget.onOpened)),
                ),
                for (final c in dms.visible)
                  _Item(
                    leading: c.otherUser != null ? Avatar(c.otherUser!, size: 20, showPresence: true) : null,
                    icon: Icons.person_outline,
                    label: c.name,
                    channel: c,
                    onTap: () => _open(c),
                  ),
                if (dms.hidden > 0 || s.showAllDms)
                  _MoreToggle(
                    label: s.showAllDms ? 'Solo attivi negli ultimi ${s.org.dmDays} giorni' : 'Altri ${dms.hidden} meno recenti',
                    expanded: s.showAllDms,
                    onTap: () => s.toggleShowAll(dms: true),
                  ),
                const SizedBox(height: 10),
                _Section(
                  title: 'Canali',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    PopupMenuButton<SortMode>(
                      tooltip: 'Ordina canali',
                      initialValue: s.sort,
                      onSelected: s.setSort,
                      itemBuilder: (_) => [
                        CheckedPopupMenuItem(value: SortMode.recent, checked: s.sort == SortMode.recent, child: const Text('Attività recente')),
                        CheckedPopupMenuItem(value: SortMode.alpha, checked: s.sort == SortMode.alpha, child: const Text('Ordine alfabetico')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(s.sort == SortMode.alpha ? Icons.sort_by_alpha : Icons.schedule, size: 16, color: at.sidebarMuted),
                      ),
                    ),
                    _SmallBtn(icon: Icons.add, tooltip: 'Crea o sfoglia canali', onTap: () => showChannelBrowser(context, onOpened: widget.onOpened)),
                  ]),
                ),
                for (final c in chans.visible)
                  _Item(icon: c.type == 'private' ? Icons.lock_outline : Icons.tag, label: c.name, channel: c, onTap: () => _open(c)),
                if (chans.hidden > 0 || s.showAllChannels)
                  _MoreToggle(
                    label: s.showAllChannels ? 'Solo attivi negli ultimi ${s.org.channelDays} giorni' : 'Altri ${chans.hidden} meno recenti',
                    expanded: s.showAllChannels,
                    onTap: () => s.toggleShowAll(dms: false),
                  ),
                _Item(icon: Icons.explore_outlined, label: 'Sfoglia canali', muted: true, onTap: () => showChannelBrowser(context, onOpened: widget.onOpened)),
              ],
            ),
          ),
          // piede: utente corrente
          if (s.me != null)
            InkWell(
              onTap: widget.onProfile,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .1)))),
                child: Row(children: [
                  Avatar(s.me!, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.me!.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.sidebarText, fontWeight: FontWeight.w700)),
                      Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: s.realtimeConnected ? at.online : Colors.amber, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Flexible(child: Text(s.realtimeConnected ? 'In tempo reale' : 'Sincronizzazione attiva', overflow: TextOverflow.ellipsis, style: TextStyle(color: at.sidebarMuted, fontSize: 12))),
                      ]),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Tema',
                    icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18, color: at.sidebarMuted),
                    onPressed: () => s.setTheme(Theme.of(context).brightness == Brightness.dark ? 'light' : 'dark'),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _Section({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(color: at.sidebarMuted, fontWeight: FontWeight.w700, fontSize: 13))),
        ?trailing,
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final Widget? leading;
  final String label;
  final Channel? channel;
  final bool muted;
  final VoidCallback onTap;
  const _Item({required this.icon, this.leading, required this.label, this.channel, this.muted = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final active = channel != null && context.select<AppState, int?>((s) => s.activeId) == channel!.id;
    final unread = channel?.unread ?? 0;
    final bold = unread > 0;
    final color = active ? Colors.white : (bold ? at.sidebarText : at.sidebarMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: active ? at.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: at.sidebarHover,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              SizedBox(width: 20, child: leading ?? Icon(icon, size: 17, color: color)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontStyle: muted ? FontStyle.normal : null, fontSize: 15)),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: at.mention, borderRadius: BorderRadius.circular(9)),
                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MoreToggle extends StatelessWidget {
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  const _MoreToggle({required this.label, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            SizedBox(width: 20, child: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 17, color: at.sidebarMuted)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: at.sidebarMuted, fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final int badge;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.tooltip, this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        backgroundColor: at.mention,
        child: Icon(icon, color: at.sidebarText, size: 20),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 17, color: AT.of(context).sidebarMuted)),
        ),
      );
}
