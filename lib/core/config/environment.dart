/// Environment configuration for the application
/// Manages different environments (dev, staging, prod)
class Environment {
  final String apiBaseUrl;
  final String environment;
  final bool enableLogging;
  final bool enableCrashReporting;

  const Environment({
    required this.apiBaseUrl,
    required this.environment,
    this.enableLogging = true,
    this.enableCrashReporting = false,
  });

  /// Development environment
  static const Environment development = Environment(
    apiBaseUrl: 'https://dev-api.nova.local',
    environment: 'development',
    enableLogging: true,
    enableCrashReporting: false,
  );

  /// Staging environment
  static const Environment staging = Environment(
    apiBaseUrl: 'https://staging-api.nova.local',
    environment: 'staging',
    enableLogging: true,
    enableCrashReporting: true,
  );

  /// Production environment
  static const Environment production = Environment(
    apiBaseUrl: 'https://api.nova.local',
    environment: 'production',
    enableLogging: false,
    enableCrashReporting: true,
  );

  /// Get current environment based on flavor
  factory Environment.currentEnvironment() {
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    
    switch (environment) {
      case 'staging':
        return Environment.staging;
      case 'production':
        return Environment.production;
      default:
        return Environment.development;
    }
  }

  bool get isDevelopment => environment == 'development';
  bool get isStaging => environment == 'staging';
  bool get isProduction => environment == 'production';
}
