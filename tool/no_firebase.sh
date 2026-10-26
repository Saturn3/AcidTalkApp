#!/usr/bin/env bash
# Prepara il progetto per le build desktop senza Firebase (Windows e Linux):
# il plugin firebase_core per Windows scarica a ogni build un SDK C++ da circa 940 MB che non serve,
# perché le notifiche push Firebase sono usate solo da Android, iOS e macOS.
# Uso: bash tool/no_firebase.sh && flutter pub get && flutter build windows
set -euo pipefail
cd "$(dirname "$0")/.."
sed -i.bak -E '/^[[:space:]]+firebase_(core|messaging):/d' pubspec.yaml && rm -f pubspec.yaml.bak
cp lib/services/push_stub.dart lib/services/push.dart
echo "Firebase rimosso per la build desktop (ripristina con: git checkout pubspec.yaml lib/services/push.dart)"
