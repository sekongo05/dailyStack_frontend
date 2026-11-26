/// Stub hors navigateur (VM Dart, Android/iOS natif, tests).
bool get isRunningInBrowserTab => false;

bool get isIosDevice => false;

bool get canTriggerNativeInstallPrompt => false;

Future<bool> triggerNativeInstallPrompt() async => false;
