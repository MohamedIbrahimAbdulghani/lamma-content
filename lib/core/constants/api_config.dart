// Lamma - by Mohamed Ibrahim

class ApiConfig {
  // Default emulator URL: http://10.0.2.2:8000/api/v1
  // For physical phone on Wi-Fi: flutter run --dart-define=API_BASE_URL=http://192.168.1.8:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const String localServerPort = '8080';
  static const int wsPort = 8080;
}
