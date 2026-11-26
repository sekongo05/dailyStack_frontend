/// Stub hors navigateur (VM Dart, tests ou mobile natif).
bool get isWebNotificationSupported => false;

String get webNotificationPermission => 'unsupported';

Future<String> requestWebNotificationPermission() async => 'unsupported';
