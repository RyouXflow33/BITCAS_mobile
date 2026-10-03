import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'config.dart';

Future<void> startDriverPush() async {
  final appId = AppConfig.oneSignalAppId.trim();
  if (appId.isEmpty || appId.startsWith('YOUR_')) return;
  OneSignal.initialize(appId);
  await OneSignal.Notifications.requestPermission(true);
}
