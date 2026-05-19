// import 'package:freezed_annotation/freezed_annotation.dart';

// part 'api_response.freezed.dart';
// part 'api_response.g.dart';

// /// Generic API response wrapper for all API calls
// /// Follows a standard response format with data, status, and message
// @freezed
// class ApiResponse<T> with _$ApiResponse<T> {
//   const factory ApiResponse({
//     @JsonKey(name: 'data') required T data,
//     @JsonKey(name: 'success') required bool success,
//     @JsonKey(name: 'message') String? message,
//     @JsonKey(name: 'code') String? code,
//   }) = _ApiResponse<T>;

//   factory ApiResponse.fromJson(
//     Map<String, dynamic> json,
//     T Function(Object? json) fromJsonT,
//   ) =>
//       _$ApiResponseFromJson(json, fromJsonT);
// }

// /// Pagination wrapper for list responses
// @freezed
// class PaginatedResponse<T> with _$PaginatedResponse<T> {
//   const factory PaginatedResponse({
//     required List<T> items,
//     required int page,
//     required int pageSize,
//     required int total,
//     required int totalPages,
//     required bool hasNextPage,
//   }) = _PaginatedResponse<T>;

//   factory PaginatedResponse.fromJson(
//     Map<String, dynamic> json,
//     T Function(Object? json) fromJsonT,
//   ) =>
//       _$PaginatedResponseFromJson(json, fromJsonT);
// }

// /// Standard error response from API
// @freezed
// class ErrorResponse with _$ErrorResponse {
//   const factory ErrorResponse({
//     required String message,
//     required String code,
//     Map<String, dynamic>? details,
//   }) = _ErrorResponse;

//   factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
//       _$ErrorResponseFromJson(json);
// }
