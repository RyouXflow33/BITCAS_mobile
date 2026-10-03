class AppConfig {
  /// Android emulator reaches this PC as 10.0.2.2.
  /// A phone on the same Wi-Fi needs the PC's address, for example
  /// http://192.168.1.20/BITCAS_UI_Skeleton
  static const baseUrl = 'http://192.168.1.6/BITCAS_UI_Skeleton';

  /// Same App ID as api/onesignal.local.php on the web project.
  /// Leave this empty until the OneSignal app exists. The map still loads.
  static const oneSignalAppId = '';

  static const cameraLat = 10.6642688;
  static const cameraLng = 122.9675934;
  static const staleAfter = Duration(seconds: 30);
  static const mapPoll = Duration(seconds: 3);
  static const advisoryPoll = Duration(seconds: 15);
}
