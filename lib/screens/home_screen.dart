import 'package:flutter/material.dart';
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
    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth >= wide;
      final sidebar = Sidebar(
        key: const ValueKey('sidebar'),
        onProfile: profile,
        onNotifications: () => showNotificationsSheet(context),
      );
      if (isWide) {
        return Scaffold(
          body: Row(children: [
            SizedBox(width: c.maxWidth > 1300 ? 300 : 264, child: sidebar),
            Expanded(child: const ChatView()),
            if (s.threadRoot != null) ...[
              VerticalDivider(width: 1, color: at.border),
              SizedBox(width: c.maxWidth > 1300 ? 420 : 360, child: const ThreadView()),
            ],
          ]),
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
          body: Stack(children: [
            Offstage(offstage: page != 0, child: sidebar),
            if (page == 1) ChatView(showBack: true, onBack: s.closeChannel),
            if (page == 2) const ThreadView(asPage: true),
          ]),
        ),
      );
    });
  }
}
