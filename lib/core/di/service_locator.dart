// import 'package:get_it/get_it.dart';
// import 'package:dio/dio.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:Skolar/core/config/environment.dart';
// import 'package:Skolar/core/network/dio_http_client.dart';

// /// Service locator for dependency injection
// /// Manages all singleton and factory dependencies
// final getIt = GetIt.instance;

// /// Initialize all dependencies
// Future<void> setupServiceLocator() async {
//   // Environment
//   final environment = Environment.currentEnvironment();
//   getIt.registerSingleton<Environment>(environment);

//   // HTTP Client
//   getIt.registerSingleton<DioHttpClient>(
//     DioHttpClient(environment: environment),
//   );

//   // Local Storage
//   final prefs = await SharedPreferences.getInstance();
//   getIt.registerSingleton<SharedPreferences>(prefs);

//   // Register repositories, use cases, and providers here
//   // This will be populated as features are added
// }

// /// Register feature dependencies
// /// Call this method when adding a new feature module
// void registerFeatureDependencies() {
//   // Features will register their own dependencies here
//   // Example:
//   // _registerAuthDependencies();
//   // _registerDashboardDependencies();
// }

// /// Helper method to resolve a dependency
// T resolve<T extends Object>() {
//   try {
//     return getIt<T>();
//   } catch (e) {
//     throw Exception('Failed to resolve $T: $e');
//   }
// }

// /// Check if a dependency is registered
// bool isRegistered<T extends Object>() {
//   return getIt.isRegistered<T>();
// }

// /// Unregister a dependency (useful for testing)
// void unregister<T extends Object>({bool? singleton}) {
//   getIt.unregister<T>(singleton: singleton);
// }

// /// Reset all dependencies (useful for testing)
// void resetServiceLocator() {
//   getIt.reset();
// }
