class AppConfig {
  /// Primary public Hostinger deployment.
  static const baseUrl = 'https://rosybrown-hamster-349004.hostingersite.com';

  /// Local XAMPP fallback when testing on the same Wi-Fi before or alongside Hostinger.
  static const localBaseUrl = 'http://192.168.1.5/BITCAS_UI_Skeleton';

  /// Public OneSignal App ID. The REST API key stays on the PHP side.
  static const oneSignalAppId = '564f6ed3-9f7a-4513-8173-706c635905ae';

  static const cameraLat = 10.6642688;
  static const cameraLng = 122.9675934;
  static const staleAfter = Duration(seconds: 30);
  static const mapPoll = Duration(seconds: 3);
  static const advisoryPoll = Duration(seconds: 5);
}
