// import '../errors/either.dart';
// import '../errors/failure_model.dart';

// /// Local storage service abstraction
// abstract class StorageService {
//   /// Save data
//   Future<Either<Failure, void>> saveData<T>({
//     required String key,
//     required T value,
//   });

//   /// Retrieve data
//   Future<Either<Failure, T?>> getData<T>({
//     required String key,
//   });

//   /// Delete data
//   Future<Either<Failure, void>> deleteData({
//     required String key,
//   });

//   /// Clear all data
//   Future<Either<Failure, void>> clearAll();

//   /// Check if key exists
//   Future<Either<Failure, bool>> hasKey({
//     required String key,
//   });
// }

// /// Cache metadata
// class CacheMetadata {
//   final String key;
//   final DateTime timestamp;
//   final Duration ttl;

//   CacheMetadata({
//     required this.key,
//     required this.timestamp,
//     required this.ttl,
//   });

//   bool get isExpired => DateTime.now().difference(timestamp) > ttl;
// }
