// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_interop';

@JS('__dsGetFcmToken')
external JSPromise<JSString> _jsGetFcmToken(bool promptIfNeeded);

bool get isWebNotificationSupported => html.Notification.supported;

String get webNotificationPermission {
  try {
    if (!html.Notification.supported) return 'unsupported';
    return html.Notification.permission ?? 'default';
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestWebNotificationPermission() async {
  try {
    if (!html.Notification.supported) return 'unsupported';
    return await html.Notification.requestPermission();
  } catch (_) {
    return 'denied';
  }
}

Future<String?> fetchWebFcmToken({bool promptIfNeeded = false}) async {
  try {
    final token = (await _jsGetFcmToken(promptIfNeeded).toDart).toDart;
    return token.trim().isEmpty ? null : token.trim();
  } catch (_) {
    return null;
  }
}
