import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../theme.dart';

/// Logo AcidTalk disegnato in codice (nessun asset esterno).
class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .26),
          gradient: const LinearGradient(colors: [Color(0xFF611F69), Color(0xFF1264A3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.forum_outlined, color: Colors.white, size: size * .56),
      );
}

class Avatar extends StatelessWidget {
  final AppUser user;
  final double size;
  final bool showPresence;
  const Avatar(this.user, {super.key, this.size = 36, this.showPresence = false});

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: user.isAi ? null : hexColor(user.avatarColor),
        gradient: user.isAi ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF1264A3)]) : null,
        borderRadius: BorderRadius.circular(size * .22),
      ),
      alignment: Alignment.center,
      child: user.isAi
          ? Icon(Icons.auto_awesome_outlined, color: Colors.white, size: size * .55)
          : Text(user.initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .38)),
    );
    if (!showPresence) return box;
    return Stack(clipBehavior: Clip.none, children: [
      box,
      Positioned(
        right: -2,
        bottom: -2,
        child: Container(
          width: size * .36,
          height: size * .36,
          decoration: BoxDecoration(
            color: user.online ? at.online : at.sidebar,
            shape: BoxShape.circle,
            border: Border.all(color: user.online ? at.sidebar : at.sidebarMuted, width: 2),
          ),
        ),
      ),
    ]);
  }
}

String fmtTime(DateTime d) => DateFormat.Hm('it_IT').format(d);

String fmtDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Ieri';
  return DateFormat(d.year == now.year ? 'EEEE d MMMM' : 'd MMMM y', 'it_IT').format(d);
}

String fmtDuration(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}
