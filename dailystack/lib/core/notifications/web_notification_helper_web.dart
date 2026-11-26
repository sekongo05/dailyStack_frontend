// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

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
