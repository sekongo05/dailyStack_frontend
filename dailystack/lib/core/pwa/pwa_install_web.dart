// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_interop';

@JS('__dsHasInstallPrompt')
external bool _jsHasInstallPrompt();

@JS('__dsTriggerInstallPrompt')
external JSPromise<JSBoolean> _jsTriggerInstallPrompt();

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

/// Indique si le navigateur propose un prompt natif `beforeinstallprompt`.
bool get canTriggerNativeInstallPrompt {
  try {
    return _jsHasInstallPrompt();
  } catch (_) {
    return false;
  }
}

/// Déclenche le prompt natif d'installation PWA (Android Chrome / Edge / Desktop).
Future<bool> triggerNativeInstallPrompt() async {
  try {
    final result = await _jsTriggerInstallPrompt().toDart;
    return result.toDart;
  } catch (_) {
    return false;
  }
}
