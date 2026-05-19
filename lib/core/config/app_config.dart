/// Environment configuration
abstract class AppEnvironment {
  static const String prod = 'prod';
  static const String dev = 'dev';
  static const String staging = 'staging';
}

/// Configuration holder
class AppConfig {
  final String environment;
  final String apiBaseUrl;
  final bool enableLogging;
  final Duration connectionTimeout;
  final Duration receiveTimeout;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.enableLogging = false,
    this.connectionTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
  });

  bool get isDevelopment => environment == AppEnvironment.dev;
  bool get isProduction => environment == AppEnvironment.prod;
  bool get isStaging => environment == AppEnvironment.staging;

  factory AppConfig.development() => const AppConfig(
        environment: AppEnvironment.dev,
        apiBaseUrl: 'https://api-dev.nova.com',
        enableLogging: true,
      );

  factory AppConfig.staging() => const AppConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://api-staging.nova.com',
        enableLogging: true,
      );

  factory AppConfig.production() => const AppConfig(
        environment: AppEnvironment.prod,
        apiBaseUrl: 'https://api.nova.com',
        enableLogging: false,
      );
}
