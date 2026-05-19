// import 'package:dartz/dartz.dart';
// import 'package:nova/core/errors/failures.dart';

// /// Base repository abstract class
// /// All repositories must follow this pattern for consistent error handling
// abstract class Repository {
//   /// Wraps an asynchronous operation with error handling
//   /// Catches exceptions and converts them to failures
//   Future<Either<Failure, T>> safeCall<T>(
//     Future<T> Function() operation,
//   ) async {
//     try {
//       final result = await operation();
//       return Right(result);
//     } on Failure catch (failure) {
//       return Left(failure);
//     } catch (e) {
//       return Left(UnknownFailure(e.toString()));
//     }
//   }

//   /// Wraps a synchronous operation with error handling
//   Either<Failure, T> safeSyncCall<T>(
//     T Function() operation,
//   ) {
//     try {
//       final result = operation();
//       return Right(result);
//     } on Failure catch (failure) {
//       return Left(failure);
//     } catch (e) {
//       return Left(UnknownFailure(e.toString()));
//     }
//   }

//   /// Wraps a stream with error handling
//   Stream<Either<Failure, T>> safeStream<T>(
//     Stream<T> Function() streamOperation,
//   ) async* {
//     try {
//       yield* streamOperation().map(
//         (item) => Right<Failure, T>(item),
//       );
//     } on Failure catch (failure) {
//       yield Left(failure);
//     } catch (e) {
//       yield Left(UnknownFailure(e.toString()));
//     }
//   }
// }

// /// Repository for local storage operations
// abstract class LocalRepository extends Repository {}

// /// Repository for remote API operations
// abstract class RemoteRepository extends Repository {}

// /// Repository combining both local and remote
// abstract class CachedRepository extends Repository {}
