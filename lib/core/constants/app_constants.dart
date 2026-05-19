/// Application constants
class AppConstants {
  // API Endpoints
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';
  static const String collegesEndpoint = '/colleges';
  static const String syllabusEndpoint = '/syllabus';
  static const String pyqEndpoint = '/pyqs';
  static const String examPredictionEndpoint = '/exam-predictions';

  // Cache duration
  static const Duration defaultCacheDuration = Duration(hours: 24);
  static const Duration shortCacheDuration = Duration(hours: 1);
  static const Duration longCacheDuration = Duration(days: 7);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 100;

  // UI Constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 4);

  // Feature Flags
  static const bool enableAIFeatures = true;
  static const bool enableOfflineMode = true;
  static const bool enableAnalytics = true;

  // AI Configuration
  static const int defaultMaxTokens = 2048;
  static const double defaultTemperature = 0.7;
  static const int maxRetries = 3;
  static const Duration aiRequestTimeout = Duration(minutes: 5);
}

/// Cache keys for local storage
class CacheKeys {
  static const String userToken = 'user_token';
  static const String userId = 'user_id';
  static const String userPreferences = 'user_preferences';
  static const String colleges = 'colleges';
  static const String subjects = 'subjects';
  static const String syllabus = 'syllabus_';
  static const String examPredictions = 'exam_predictions_';
  static const String isOnboarded = 'is_onboarded';
  static const String lastSyncTime = 'last_sync_time';
}

/// Route names for navigation
class RouteNames {
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String colleges = '/colleges';
  static const String collegeDetail = '/colleges/:collegeId';
  static const String subjects = '/subjects';
  static const String syllabus = '/syllabus';
  static const String pyqUpload = '/pyq-upload';
  static const String examPrediction = '/exam-prediction';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

/// Error codes from API
class ApiErrorCodes {
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String userNotFound = 'USER_NOT_FOUND';
  static const String emailAlreadyExists = 'EMAIL_ALREADY_EXISTS';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String forbidden = 'FORBIDDEN';
  static const String notFound = 'NOT_FOUND';
  static const String validationError = 'VALIDATION_ERROR';
  static const String serverError = 'SERVER_ERROR';
  static const String networkError = 'NETWORK_ERROR';
}
