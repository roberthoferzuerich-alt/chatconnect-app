# 📱 ChatConnect - Mobile Application (Flutter)

[![Flutter](https://img.shields.io/badge/Flutter-^3.12-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-^3.12-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/State_Management-Riverpod-00599C?style=for-the-badge)](https://riverpod.dev)
[![GoRouter](https://img.shields.io/badge/Navigation-GoRouter-4285F4?style=for-the-badge)](https://pub.dev/packages/go_router)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

**ChatConnect App** ist eine moderne, plattformübergreifende Echtzeit-Chat- & VoIP-Anwendung für Android und iOS. Sie basiert auf **Flutter** und **Riverpod** und bietet eine intuitive Benutzeroberfläche nach Material 3 Standards mit Unterstützung für Chats, Audio- & Videoanrufe, 24h-Storys, Sprachnachrichten und Push-Benachrichtigungen.

---

## 📸 Hauptfunktionen

- 💬 **Echtzeit-Messaging**:
  - Sofortiger Nachrichten-Austausch via WebSockets (**Laravel Echo** & **Reverb**).
  - Unterstützung für Text, Emojis, Bilder und Anhänge.
  - Lesebestätigungen (Read Receipts) & Ungelesen-Zähler.
  - Long-Press Kontextmenü zum Kopieren und Löschen von Nachrichten (mit automatischer Medienbereinigung).

- 📞 **HD Audio- & Video-Anrufe**:
  - Integrierte 1-zu-1 Sprach- & Videoanrufe basierend auf **ZEGO Express UI Kit** und **Signaling Plugin**.
  - In-App-Anrufeinladungen mit nativer Anrufschnittstelle.

- 📸 **Story- & Status-Funktion**:
  - Erstellen und Teilen von Status-Updates (Bild & Text).
  - Automatischer Ablauf nach 24 Stunden.
  - Ansichtsstatus (Story Views) und Löschmöglichkeit.

- 🎤 **Sprachnachrichten**:
  - Aufnahme von Audio-Nachrichten mit Live-Vorschau und Audioplayer-Wiedergabe (`record`, `audioplayers`).

- 🔔 **Push-Benachrichtigungen**:
  - Integration von **Firebase Cloud Messaging (FCM)** & `flutter_local_notifications` für Benachrichtigungen im Hintergrund.

- 🎨 **Modernes UI/UX**:
  - Dynamische Farbschemas (Material 3 Dynamic Color / Seed-based Themes).
  - Nahtlose Umschaltung zwischen Light Mode und Dark Mode.
  - Integrierter Emoji-Picker, Bildzuschnitt (Image Cropper) & Caching für ein flüssiges Erlebnis.

- 🔒 **Sicherheit & Speicher**:
  - Verschlüsselte Token-Speicherung mit `flutter_secure_storage`.
  - Sichere Authentifizierung via Sanctum API-Token.

---

## 🏗️ Architektur & Tech Stack

| Komponente | Technologie / Package |
| :--- | :--- |
| **Framework** | Flutter (Dart ^3.12.2) |
| **State Management** | Riverpod (`flutter_riverpod`, `riverpod_annotation`) |
| **Routing & Navigation** | GoRouter (`go_router`) |
| **HTTP Client & Storage** | Dio (`dio`), `flutter_secure_storage` |
| **Echtzeit / Sockets** | `laravel_echo`, `dart_pusher_channels`, `pusher_client_fixed` |
| **VoIP & Calling** | `zego_uikit_prebuilt_call`, `zego_uikit_signaling_plugin`, `zego_zpns` |
| **Push Notifications** | Firebase Core & Messaging, `flutter_local_notifications` |
| **Medienbearbeitung** | `image_picker`, `image_cropper`, `cached_network_image`, `record`, `audioplayers`, `gal` |
| **Kontakte & Sharing** | `flutter_contacts`, `share_plus` |

---

## 📁 Projektstruktur

```text
lib/
├── app/
│   ├── router.dart          # GoRouter Routen-Definitionen
│   └── theme_provider.dart  # Riverpod Provider für Theme & Dark Mode
├── core/
│   ├── network/             # Dio HTTP Client & Websocket-Clients
│   ├── constants/           # API-Pfade & App-Konstanten
│   └── utils/               # Hilfsfunktionen & Formatter
├── features/
│   ├── auth/                # Login, Registrierung & Token-Handling
│   ├── chat/                # Chat-Fenster, Nachrichten-Streams & Kontextmenü
│   ├── conversations/       # Übersicht aller aktiven Dialoge
│   ├── contacts/            # Kontaktliste & Nutzersuche
│   ├── messages/            # Audio- & Mediennachrichten
│   ├── profile/             # Profilverwaltung & Avatar-Upload
│   ├── settings/            # App-Einstellungen & Design-Wahl
│   └── story/               # Story-Feed, Story-Viewer & Kamera-Upload
├── firebase_options.dart    # Firebase Plattform-Konfiguration
└── main.dart                # App-Einstiegspunkt & Zego/Firebase Init
```

---

## 🚀 Erste Schritte

### Voraussetzungen

Stelle sicher, dass folgende Software auf deinem Entwicklungsrechner installiert ist:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version >= 3.29.0)
- [Dart SDK](https://dart.dev/get-dart) (Version >= 3.12.2)
- Android Studio oder Xcode (für iOS)
- Ein Mobilgerät oder Emulator

### Installation & Ausführung

1. **Repository klonen**:
   ```bash
   git clone https://github.com/roberthoferzuerich-alt/chatconnect-app.git
   cd chatconnect-app
   ```

2. **Abhängigkeiten installieren**:
   ```bash
   flutter pub get
   ```

3. **Konfiguration anpassen**:
   - Trage deine Backend-URL in den Netzwerk-Einstellungen ein (`lib/core/network/`).
   - Füge deine `google-services.json` (Android) bzw. `GoogleService-Info.plist` (iOS) für Firebase hinzu.
   - Konfiguriere deine ZEGO AppID und AppSign Schlüssel für Videoanrufe.

4. **App auf einem Gerät/Emulator starten**:
   ```bash
   flutter run
   ```

---

## 🔗 Backend-Repository

Das passende Backend für diese Anwendung (Laravel REST-API & WebSockets) findest du im Repository:  
👉 **[ChatConnect Backend Repository](https://github.com/roberthoferzuerich-alt/chatconnect-backend.git)**

---

## 📄 Lizenz

Dieses Projekt steht unter der **MIT Lizenz**.
