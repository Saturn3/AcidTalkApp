import '../api/api.dart';

/// Variante senza Firebase usata per Windows e Linux (tool/no_firebase.sh la copia su push.dart):
/// le app desktop usano le notifiche locali mentre sono aperte.
class Push {
  Push._();
  static final instance = Push._();

  void Function(int channelId)? onOpen;
  void Function()? onForegroundMessage;
  String? status = 'Le notifiche push Firebase sono disponibili nelle app Android, iOS e macOS';

  bool get available => false;

  Future<void> register(Api api) async {}

  Future<void> unregister(Api api) async {}
}
