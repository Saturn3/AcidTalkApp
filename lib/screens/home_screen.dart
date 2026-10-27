import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/sidebar.dart';
import 'chat_view.dart';
import 'profile_screen.dart';

/// Layout adattivo: tre colonne su desktop/tablet, navigazione a pagine su telefono.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const wide = 900.0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final at = AT.of(context);
    void profile() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    // Ctrl+K (Windows/Linux) o Cmd+K (macOS) apre la ricerca da qualsiasi punto, come sul web
    return _SearchHotkey(
      onSearch: () => showSearchSheet(context, channel: s.active),
      child: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= wide;
          final sidebar = Sidebar(key: const ValueKey('sidebar'), onProfile: profile, onNotifications: () => showNotificationsSheet(context));
          if (isWide) {
            return Scaffold(
              body: Row(
                children: [
                  SizedBox(width: c.maxWidth > 1300 ? 300 : 264, child: sidebar),
                  Expanded(child: const ChatView()),
                  if (s.threadRoot != null) ...[VerticalDivider(width: 1, color: at.border), SizedBox(width: c.maxWidth > 1300 ? 420 : 360, child: const ThreadView())],
                ],
              ),
            );
          }
          // telefono: la barra laterale resta montata (Offstage) così mantiene la posizione di scorrimento
          final page = s.activeId == null ? 0 : (s.threadRoot != null ? 2 : 1);
          return PopScope(
            canPop: page == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              page == 2 ? s.closeThread() : s.closeChannel();
            },
            child: Scaffold(
              body: Stack(
                children: [
                  Offstage(offstage: page != 0, child: sidebar),
                  if (page == 1) ChatView(showBack: true, onBack: s.closeChannel),
                  if (page == 2) const ThreadView(asPage: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Scorciatoia globale per la ricerca: usa il gestore della tastiera di sistema, quindi funziona
/// anche quando nessun campo ha il focus (es. dopo un clic nella barra laterale).
class _SearchHotkey extends StatefulWidget {
  final Future<void> Function() onSearch;
  final Widget child;
  const _SearchHotkey({required this.onSearch, required this.child});

  @override
  State<_SearchHotkey> createState() => _SearchHotkeyState();
}

class _SearchHotkeyState extends State<_SearchHotkey> {
  bool _open = false;

  bool _handle(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyK) return false;
    final kb = HardwareKeyboard.instance;
    if (!(kb.isControlPressed || kb.isMetaPressed) || kb.isAltPressed || kb.isShiftPressed) return false;
    if (_open) return true;
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
    _open = true;
    widget.onSearch().whenComplete(() => _open = false);
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handle);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
