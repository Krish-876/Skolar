// // ignore_for_file: prefer_const_constructors_in_immutables

// import 'package:freezed_annotation/freezed_annotation.dart';

// part 'failure_model.freezed.dart';

// /// Base failure model for all application errors
// @freezed
// class Failure with _$Failure {
//   const factory Failure.serverError({
//     @Default('Server Error') String message,
//     int? statusCode,
//   }) = ServerError;

//   const factory Failure.networkError({
//     @Default('Network Error') String message,
//   }) = NetworkError;

//   const factory Failure.cacheError({
//     @Default('Cache Error') String message,
//   }) = CacheError;

//   const factory Failure.validationError({
//     required String message,
//     Map<String, String>? fieldErrors,
//   }) = ValidationError;

//   const factory Failure.authenticationError({
//     @Default('Authentication Failed') String message,
//   }) = AuthenticationError;

//   const factory Failure.authorizationError({
//     @Default('Authorization Failed') String message,
//   }) = AuthorizationError;

//   const factory Failure.aiError({
//     required String message,
//     String? provider,
//     String? retryMessage,
//   }) = AIError;

//   const factory Failure.unknownError({
//     @Default('Unknown Error') String message,
//   }) = UnknownError;
// }
