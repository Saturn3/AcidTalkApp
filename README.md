# AcidTalk — app Flutter 2.5.1 (Android, iOS, Windows, macOS)

Client nativo per il backend **AcidTalk 2.x** (Laravel; le funzioni 2.4 richiedono il backend 2.4). Un unico codice Flutter produce:

| Piattaforma | Pacchetto prodotto dalla CI | Note |
|---|---|---|
| Android | `AcidTalk-android.apk`, `.aab` | firmato con la chiave di debug se non configuri i secrets |
| iOS | `AcidTalk-ios-unsigned.ipa` | da firmare con il tuo account Apple Developer |
| Windows 10/11 | `AcidTalk-windows-setup.exe`, `.zip` | installer Inno Setup con collegamento nel menu Start |
| macOS 11+ | `AcidTalk-macos.dmg`, `.zip` | non notarizzato: al primo avvio clic destro → Apri |
| Linux | `flutter build linux` | non incluso nella CI, usato per i test |

## Funzionalità

### Novità 2.5.1

- **A capo su desktop**: Invio invia, Alt+Invio (o Shift+Invio) va a capo, come sul web. Il suggerimento è indicato accanto al pulsante di invio.
- **Elenchi puntati**: nuovo pulsante *Elenco puntato* nella barra di scrittura (aggiunge o toglie `- ` sulle righe selezionate). Andando a capo dentro un elenco il punto (o il numero successivo, `1.` → `2.`) viene ripetuto; andando a capo su una voce vuota l'elenco termina. Su mobile la continuazione funziona con il tasto a capo della tastiera.
- La barra dei pulsanti di formattazione scorre in orizzontale sugli schermi stretti.
- Con il backend 2.5.1 una riga di testo scritta subito dopo un elenco chiude l'elenco invece di finire nell'ultima voce.

### Novità 2.5

- **Menzioni con lista di scelta**: digitando `@` compare l'elenco di persone, assistente AI e bot, filtrato mentre si scrive (nome, cognome o handle); digitando `#` compare l'elenco dei canali pubblici e privati. Su desktop si sceglie con frecce, Invio/Tab ed Esc, su mobile con un tocco. I pulsanti `@` e `#` della barra di scrittura aprono la lista.
- **Riferimenti ai canali**: `#slug` di un canale esistente diventa un link (anche sul web); toccandolo si apre il canale.
- **Trascinamento file (Windows, macOS, Linux)**: si possono trascinare uno o più file sulla chat o sul pannello thread per allegarli, con il controllo del limite di dimensione dell'organizzazione. Usa il plugin `desktop_drop`.
- Richiede il backend 2.5 per i link `#canale`; con un backend precedente la lista funziona ma il riferimento resta testo.

### Novità 2.4.1

- **Pannello notifiche**: pulsanti *Segna tutte come lette* e *Cancella tutte* (con conferma), eliminazione della singola notifica con la X o con uno scorrimento verso sinistra. Le notifiche già mostrate dal sistema vengono rimosse dal centro notifiche. La cancellazione richiede il backend 2.4.1 (`DELETE /api/notifications`).
- **Android con notifiche push Firebase attive** nelle build della CI (progetto `acidtalk-436e6`, chiavi nei secrets del repository).

### Novità 2.4

- **Conferme di lettura**: una spunta sui propri messaggi quando sono inviati, due spunte quando qualcuno li ha letti (blu se letti da tutti i membri); il tooltip mostra chi li ha letti. Si disattivano da Amministrazione › Organizzazione.
- **Immagine profilo**: Profilo › Imposta immagine profilo (ritagliata a 256×256 dal server); gli avatar compaiono in chat, nella barra laterale e nelle menzioni.
- **Reazioni con qualsiasi emoji**: pulsante "Scegli una reazione" nella barra al passaggio del mouse, nel menu a pressione prolungata e accanto alle reazioni esistenti. Il selettore ha categorie, ricerca (anche in italiano: *pollice*, *cuore*, *festa*) e le emoji usate di recente.
- **Emoji nel testo**: digitando `:` seguito da due lettere compaiono i suggerimenti (Tab/Invio per inserire, frecce per scegliere); il pulsante faccina apre il selettore completo. Il server converte `:shortcode:` ed emoticon come `:)` e mostra in grande i messaggi di sole emoji.
- **Anteprime dei link a riquadro**: immagine in alto, titolo, descrizione e dominio.
- **Utenti bot** (creati da Amministrazione › Bot) con etichetta BOT e avatar dedicato.
- **Assistente AI affidabile**: dopo l'invio l'app chiede al server di generare subito la risposta (`POST /api/messages/{id}/tasks/ai`) e mostra "AI sta scrivendo…"; gli errori del provider compaiono in una notifica in basso invece di restare silenziosi.
- **Notifiche push Firebase** (Android, iOS, macOS) anche ad app chiusa: vedi la sezione dedicata.

- Login con indirizzo del server (predefinito `https://talk.acidsoft.it`), token Sanctum salvato sul dispositivo.
- Barra laterale stile Slack: **messaggi diretti in alto**, poi canali; ordinamento dei canali per **attività recente** o **alfabetico**; mostra solo i DM attivi negli ultimi **60 giorni** e i canali attivi negli ultimi **90** (valori presi dalle impostazioni dell'organizzazione), con il pulsante "Altri N meno recenti". La posizione di scorrimento resta invariata durante la sincronizzazione.
- Messaggi con Markdown, blocchi di codice, menzioni, reazioni, thread, modifica ed eliminazione.
- **Player audio** per i messaggi vocali e i file audio: play/pausa, forma d'onda con avanzamento cliccabile, durata, velocità 1× / 1,5× / 2×, un solo audio alla volta.
- Registrazione di **messaggi vocali** (AAC .m4a) dal pulsante microfono.
- **Anteprime dei link** (titolo, descrizione, immagine, favicon; miniatura con pulsante play per YouTube/Vimeo; pulsante "Partecipa" per Meet/Jitsi). L'autore può rimuovere un'anteprima.
- Allegati: immagini con visualizzatore, PDF e altri file aperti con l'app di sistema.
- Videochiamata dal pulsante in alto nel canale.
- Assistente AI, canali pubblici e privati (sfoglia, unisciti, crea), nuovi messaggi diretti.
- Tema chiaro, scuro o di sistema (sincronizzato con il profilo web).
- Notifiche native (Android, iOS, macOS, Windows, Linux) per menzioni, DM e risposte.
- Sincronizzazione: in tempo reale se il server ha Pusher o Reverb, altrimenti controllo automatico ogni 6 secondi (nuovi messaggi, modifiche, eliminazioni, anteprime).
- Layout adattivo: tre colonne su desktop/tablet (≥ 900 px), navigazione a pagine su telefono.

## Sviluppo

```bash
flutter pub get
flutter run -d windows      # oppure macos, linux, un emulatore Android, un simulatore iOS
flutter run --dart-define=ACIDTALK_SERVER=http://192.168.1.10:8000   # server predefinito diverso
flutter analyze && flutter test
```

Requisiti: Flutter stabile ≥ 3.38 (Dart ≥ 3.9). Per Windows serve Visual Studio 2022 con "Sviluppo di applicazioni desktop con C++", per macOS/iOS Xcode.

Struttura:

```
lib/
  api/        models.dart, api.dart (client REST /api)
  services/   realtime.dart (protocollo Pusher, valido anche per Reverb), notifier.dart
  state/      app_state.dart (sessione, barra laterale, messaggi, polling)
  screens/    login, home (adattiva), chat_view (canale e thread), profile
  widgets/    sidebar, message_tile, composer, audio_player, attachments (file e anteprime link), dialogs
```

## Build automatiche con GitHub Actions

Il file `.github/workflows/build.yml` compila tutte le piattaforme a ogni push su `main`. Per pubblicare una release con tutti i pacchetti:

```bash
git tag v2.4.0
git push origin v2.4.0
```

Variabili e secrets facoltativi (Settings → Secrets and variables → Actions):

| Nome | Tipo | Uso |
|---|---|---|
| `ACIDTALK_SERVER` | variable | server predefinito della schermata di login |
| `ANDROID_KEYSTORE_BASE64` | secret | keystore release codificato in base64 (`base64 -w0 release.jks`) |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | secret | dati del keystore |
| `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID` | secret | progetto Firebase per le notifiche push |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_APPLE_APP_ID` | secret | ID app Firebase Android (`1:…:android:…`) e Apple (`1:…:ios:…`) |

Creare un keystore Android:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias acidtalk
```

In locale puoi in alternativa creare `android/key.properties` con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.

### iOS e macOS firmati

La CI produce pacchetti non firmati. Per distribuirli (TestFlight, App Store o fuori store con notarizzazione) apri `ios/Runner.xcworkspace` o `macos/Runner.xcworkspace` in Xcode, seleziona il tuo Team e usa Product → Archive. Gli entitlement macOS già impostati sono: rete in uscita, microfono, file scelti dall'utente, cartella Download.

## Notifiche push con Firebase

Le chiavi Firebase si passano in compilazione, senza `google-services.json` né `GoogleService-Info.plist`:

```bash
flutter build apk --release \
  --dart-define=FIREBASE_API_KEY=AIza... \
  --dart-define=FIREBASE_PROJECT_ID=acidtalk-12345 \
  --dart-define=FIREBASE_SENDER_ID=123456789012 \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:123456789012:android:abc123 \
  --dart-define=FIREBASE_APPLE_APP_ID=1:123456789012:ios:def456
```

Senza queste chiavi l'app funziona normalmente con le sole notifiche locali (attive mentre l'app è aperta o in background recente). Dopo il login l'app registra il token del dispositivo sul server (`POST /api/push/devices`) e lo rimuove al logout. Il server invia le push quando in Amministrazione › Push è caricato l'account di servizio Firebase. La procedura completa (progetto Firebase, chiave APNs per iOS, capability Xcode, account di servizio) è in `docs/push-firebase.md` del backend.

**Windows e Linux** non usano Firebase. Il plugin `firebase_core` per Windows scaricherebbe a ogni build un SDK C++ da circa 940 MB, per cui prima di compilare per desktop si usa lo script (la CI lo fa in automatico):

```bash
bash tool/no_firebase.sh     # rimuove Firebase da pubspec.yaml e usa lib/services/push_stub.dart
flutter pub get && flutter build windows
git checkout pubspec.yaml lib/services/push.dart   # per tornare alla versione con Firebase
```

## Windows: errore "Impossibile accedere al dispositivo, al percorso o al file specificato"

Le build della CI non sono firmate digitalmente. Su Windows 11 **Smart App Control**, alcuni criteri aziendali (regole ASR di Defender, AppLocker) e alcuni antivirus bloccano gli eseguibili non firmati scaricati da internet, e Windows mostra questo messaggio sia per il setup sia per `acidtalk.exe`. I file della release sono integri: si tratta di un blocco del sistema, non di un errore dell'app.

Soluzioni immediate, da provare in ordine:

1. **Sblocca il file**: tasto destro su `AcidTalk-windows-setup.exe` (o sullo zip *prima* di estrarlo) › Proprietà › spunta **Sblocca** › OK. In PowerShell: `Get-ChildItem $env:USERPROFILE\Downloads\AcidTalk* | Unblock-File`.
2. **Zip**: estrai tutto il contenuto (tasto destro › Estrai tutto) in una cartella locale, ad esempio `C:\Users\<nome>\AcidTalk`, e non avviare `acidtalk.exe` dall'anteprima dello zip, da una cartella di rete o da OneDrive con file "solo online".
3. **Antivirus**: controlla in Sicurezza di Windows › Protezione da virus e minacce › Cronologia protezione se il file è stato bloccato o messo in quarantena e, nel caso, consentilo.
4. **Smart App Control**: in Sicurezza di Windows › Controllo app e browser › Impostazioni di Smart App Control. Se è *Attivato* blocca qualunque app non firmata; disattivarlo sblocca AcidTalk, ma **non si può riattivare senza reinstallare Windows**: valutalo bene, oppure usa la firma del codice.
5. **PC aziendali gestiti** (Intune/criteri di dominio): serve l'eccezione dell'amministratore IT oppure la build firmata.

### Firma dell'app Windows (soluzione definitiva)

La CI firma `acidtalk.exe`, le DLL e il setup con **Azure Artifact Signing** (ex Trusted Signing) quando sono configurati questi valori nel repository:

| Nome | Tipo | Valore |
|---|---|---|
| `AZURE_TENANT_ID` | secret | ID tenant di Microsoft Entra |
| `AZURE_CLIENT_ID` | secret | ID applicazione della App Registration usata per firmare |
| `AZURE_CLIENT_SECRET` | secret | segreto client della App Registration |
| `WINDOWS_SIGNING_ENDPOINT` | variable | endpoint della regione, ad esempio `https://weu.codesigning.azure.net/` |
| `WINDOWS_SIGNING_ACCOUNT` | variable | nome dell'account Artifact Signing |
| `WINDOWS_SIGNING_PROFILE` | variable | nome del profilo certificato (Public Trust) |

Passi su Azure:

1. Crea l'account Artifact Signing.
2. Completa la convalida dell'identità dell'organizzazione (AcidSoft).
3. Crea un profilo certificato *Public Trust*.
4. Assegna alla App Registration il ruolo **Artifact Signing Certificate Profile Signer** sull'account.

Senza questi valori i passaggi di firma vengono saltati e la build resta non firmata come oggi. Il passo "Verifica firma" del workflow mostra lo stato della firma di `acidtalk.exe` e del setup.

Con la firma Smart App Control lascia avviare l'app. SmartScreen può mostrare ancora l'avviso "app non riconosciuta" per le prime installazioni, finché il certificato non acquisisce reputazione.

## Note sulle piattaforme

- **Messaggi vocali registrati dal browser** (formato WebM/Opus): si ascoltano su Android, Windows e Linux; su iPhone e Mac il formato non è supportato da Apple e il player lo segnala. I vocali registrati dall'app (AAC .m4a) funzionano ovunque.
- **Notifiche Windows**: compaiono come notifiche di sistema quando l'app è aperta o ridotta a icona. L'installer crea il collegamento con l'ID applicazione corretto.
- **Notifiche con app chiusa** (push vere su Android/iOS) richiedono Firebase Cloud Messaging e APNs, non ancora inclusi: l'app notifica mentre è aperta o in background recente, e le email del server coprono il resto.
