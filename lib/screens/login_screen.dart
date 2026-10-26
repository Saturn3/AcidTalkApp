import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _server, _email;
  final _password = TextEditingController();
  bool _busy = false, _hide = true, _advanced = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _server = TextEditingController(text: s.server);
    _email = TextEditingController(text: s.lastEmail ?? '');
    _advanced = s.server != AppState.defaultServer;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(_server.text, _email.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Impossibile contattare il server: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final at = AT.of(context);
    return Scaffold(
      backgroundColor: at.surface2,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: Logo(size: 56)),
                const SizedBox(height: 18),
                Text('Accedi ad AcidTalk', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: at.text)),
                const SizedBox(height: 6),
                Text('Usa le credenziali della tua organizzazione', textAlign: TextAlign.center, style: TextStyle(color: at.muted)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: at.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: at.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_advanced) ...[
                      _label('Server', at),
                      TextField(controller: _server, keyboardType: TextInputType.url, decoration: const InputDecoration(prefixIcon: Icon(Icons.dns_outlined, size: 18), hintText: 'https://talk.azienda.it')),
                      const SizedBox(height: 14),
                    ],
                    _label('Email', at),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email, AutofillHints.username],
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline, size: 18), hintText: 'nome@azienda.it'),
                    ),
                    const SizedBox(height: 14),
                    _label('Password', at),
                    TextField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18), onPressed: () => setState(() => _hide = !_hide)),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: at.mention.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Icon(Icons.error_outline, size: 18, color: at.mention),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: at.mention))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Accedi'),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => setState(() => _advanced = !_advanced),
                  icon: Icon(_advanced ? Icons.expand_less : Icons.tune_outlined, size: 16),
                  label: Text(_advanced ? 'Nascondi impostazioni server' : 'Cambia server (${Uri.tryParse(_server.text)?.host ?? _server.text})'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t, AT at) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: at.text)));
}
