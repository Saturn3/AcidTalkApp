import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// Un'emoji del catalogo (assets/emoji.json, lo stesso usato dal frontend web).
class EmojiItem {
  final String char;
  final List<String> aliases;
  final String keywords;
  final int cat;
  const EmojiItem(this.char, this.aliases, this.keywords, this.cat);
}

/// Catalogo emoji con ricerca per alias (anche italiani), usato dal selettore e dall'autocompletamento ":".
class EmojiCatalog {
  EmojiCatalog._();
  static List<String> cats = const [];
  static List<EmojiItem> list = const [];
  static Future<void>? _loading;
  static List<String> recent = [];

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/emoji.json')) as Map<String, dynamic>;
      cats = List<String>.from(j['cats'] as List);
      list = [
        for (final e in j['list'] as List)
          EmojiItem(e[0] as String, (e[1] as String).split(' ').where((a) => a.isNotEmpty).toList(), e[2] as String? ?? '', (e[3] as num).toInt()),
      ];
      final p = await SharedPreferences.getInstance();
      recent = p.getStringList('emoji_recent') ?? [];
    } catch (e) {
      debugPrint('Catalogo emoji non caricato: $e');
    }
  }

  static Future<void> remember(String e) async {
    recent.remove(e);
    recent.insert(0, e);
    if (recent.length > 24) recent = recent.sublist(0, 24);
    try {
      (await SharedPreferences.getInstance()).setStringList('emoji_recent', recent);
    } catch (_) {}
  }

  /// Cerca per alias (prefisso prima, poi contenuto) e parole chiave.
  static List<EmojiItem> search(String q, {int limit = 80}) {
    q = q.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final starts = <EmojiItem>[], contains = <EmojiItem>[], kw = <EmojiItem>[];
    for (final e in list) {
      if (e.aliases.any((a) => a.startsWith(q))) {
        starts.add(e);
      } else if (e.aliases.any((a) => a.contains(q))) {
        contains.add(e);
      } else if (e.keywords.contains(q)) {
        kw.add(e);
      }
    }
    return [...starts, ...contains, ...kw].take(limit).toList();
  }
}

/// Apre il selettore emoji completo (bottom sheet su mobile, dialog su desktop) e restituisce l'emoji scelta.
Future<String?> pickEmoji(BuildContext context) async {
  await EmojiCatalog.load();
  if (!context.mounted) return null;
  final wide = MediaQuery.sizeOf(context).width > 700;
  final String? r = wide
      ? await showDialog<String>(
          context: context,
          builder: (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: const SizedBox(width: 380, height: 440, child: EmojiPickerPanel()),
          ),
        )
      : await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height * .6, child: const EmojiPickerPanel()),
        );
  if (r != null) EmojiCatalog.remember(r);
  return r;
}

class EmojiPickerPanel extends StatefulWidget {
  const EmojiPickerPanel({super.key});
  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  final _q = TextEditingController();
  int _cat = -1; // -1 = recenti

  static const _catIcons = [
    Icons.sentiment_satisfied_outlined,
    Icons.waving_hand_outlined,
    Icons.pets_outlined,
    Icons.restaurant_outlined,
    Icons.sports_soccer_outlined,
    Icons.directions_car_outlined,
    Icons.lightbulb_outline,
    Icons.tag,
    Icons.flag_outlined,
  ];

  @override
  void initState() {
    super.initState();
    if (EmojiCatalog.recent.isEmpty) _cat = 0;
  }

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    final q = _q.text.trim();
    final items = q.isNotEmpty
        ? EmojiCatalog.search(q, limit: 200).map((e) => e.char).toList()
        : _cat < 0
            ? EmojiCatalog.recent
            : EmojiCatalog.list.where((e) => e.cat == _cat).map((e) => e.char).toList();
    final title = q.isNotEmpty ? 'Risultati' : _cat < 0 ? 'Usate di recente' : (_cat < EmojiCatalog.cats.length ? EmojiCatalog.cats[_cat] : '');
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: TextField(
          controller: _q,
          autofocus: MediaQuery.sizeOf(context).width > 700,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            final r = EmojiCatalog.search(_q.text, limit: 1);
            if (r.isNotEmpty) Navigator.pop(context, r.first.char);
          },
          decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 20), hintText: 'Cerca emoji (es. pollice, cuore, festa)'),
        ),
      ),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          _catBtn(-1, Icons.schedule, 'Recenti', at),
          for (var i = 0; i < EmojiCatalog.cats.length && i < _catIcons.length; i++) _catBtn(i, _catIcons[i], EmojiCatalog.cats[i], at),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(color: at.muted, fontSize: 12, fontWeight: FontWeight.w700))),
      ),
      Expanded(
        child: items.isEmpty
            ? Center(child: Text(q.isNotEmpty ? 'Nessuna emoji trovata' : 'Nessuna emoji recente', style: TextStyle(color: at.muted)))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 44, mainAxisSpacing: 2, crossAxisSpacing: 2),
                itemCount: items.length,
                itemBuilder: (_, i) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(context, items[i]),
                  child: Center(child: Text(items[i], style: const TextStyle(fontSize: 24))),
                ),
              ),
      ),
    ]);
  }

  Widget _catBtn(int i, IconData icon, String tip, AT at) => Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() {
            _cat = i;
            _q.clear();
          }),
          child: Container(
            width: 34,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: _cat == i && _q.text.isEmpty ? at.accent.withValues(alpha: .12) : null, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 19, color: _cat == i && _q.text.isEmpty ? at.accent : at.muted),
          ),
        ),
      );
}
