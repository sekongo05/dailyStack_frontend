// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Ouvre une URL HTTP(S) externe dans un nouvel onglet sécurisé.
Future<bool> openExternalUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  try {
    html.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
    return true;
  } catch (_) {
    return false;
  }
}
