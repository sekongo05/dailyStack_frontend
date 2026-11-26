// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Détecte si l'application Web tourne dans un onglet navigateur classique
/// (non installée en mode PWA standalone).
bool get isRunningInBrowserTab {
  try {
    final isStandalone =
        html.window.matchMedia('(display-mode: standalone)').matches;
    return !isStandalone;
  } catch (_) {
    return false;
  }
}

/// Détecte un appareil iOS (iPhone, iPad, iPod) via le User-Agent.
bool get isIosDevice {
  try {
    final ua = html.window.navigator.userAgent;
    return RegExp(r'iPhone|iPad|iPod', caseSensitive: false).hasMatch(ua);
  } catch (_) {
    return false;
  }
}
