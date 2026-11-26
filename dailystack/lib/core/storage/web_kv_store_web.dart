// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Stockage clé-valeur persistant via `window.localStorage` pour Flutter Web PWA.
class WebKvStore {
  static const String _prefix = 'dailystack_kv_';
  static final Map<String, String> _fallbackStore = <String, String>{};

  String? read(String key) {
    try {
      final stored = html.window.localStorage['$_prefix$key'];
      if (stored != null) return stored;
    } catch (_) {
      // Fallback mémoire si localStorage est restreint (navigation privée stricte).
    }
    return _fallbackStore[key];
  }

  void write(String key, String value) {
    _fallbackStore[key] = value;
    try {
      html.window.localStorage['$_prefix$key'] = value;
    } catch (_) {
      // Protection contre QuotaExceededError : tentative de purge des anciens caches non critiques.
      try {
        html.window.localStorage.remove('${_prefix}dailystack_news_v1');
        html.window.localStorage['$_prefix$key'] = value;
      } catch (_) {}
    }
  }

  void remove(String key) {
    _fallbackStore.remove(key);
    try {
      html.window.localStorage.remove('$_prefix$key');
    } catch (_) {}
  }

  void clearAll() {
    _fallbackStore.clear();
    try {
      final keysToRemove = html.window.localStorage.keys
          .where((k) => k.startsWith(_prefix))
          .toList();
      for (final k in keysToRemove) {
        html.window.localStorage.remove(k);
      }
    } catch (_) {}
  }
}
