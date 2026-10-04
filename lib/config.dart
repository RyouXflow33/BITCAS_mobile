class AppConfig {
  /// Android emulator reaches this PC as 10.0.2.2.
  /// A phone on the same Wi-Fi needs the PC's address, for example
  /// http://192.168.1.20/BITCAS_UI_Skeleton
  static const baseUrl = 'http://192.168.1.9/BITCAS_UI_Skeleton';

  /// Public OneSignal App ID. The REST API key stays on the PHP side.
  static const oneSignalAppId = '564f6ed3-9f7a-4513-8173-706c635905ae';

  static const cameraLat = 10.6642688;
  static const cameraLng = 122.9675934;
  static const staleAfter = Duration(seconds: 30);
  static const mapPoll = Duration(seconds: 3);
  static const advisoryPoll = Duration(seconds: 5);
}
