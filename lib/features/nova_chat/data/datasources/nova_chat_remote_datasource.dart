import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:Skolar/core/config/environment.dart';
import 'package:Skolar/features/nova_chat/data/models/chat_message_dto.dart';
import 'package:Skolar/features/nova_chat/data/models/proposal_dto.dart';
import 'package:Skolar/features/nova_chat/data/models/study_plan_dto.dart';

abstract class INovaChatRemoteDatasource {
  Future<NovaChatResponseDto> sendMessage({
    required String userId,
    required String question,
  });

  Future<StudyPlanDto> runReasoning({
    required String userId,
    String triggerType = 'full_pass',
  });

  Future<Map<String, dynamic>> getFacts({required String userId});

  Future<List<String>> getInitialSuggestions({required String userId});

  Future<bool> checkHealth();

  Future<List<PendingProposalDto>> getPendingProposals({
    required String userId,
  });

  Future<ProposalResolutionDto> confirmProposal({
    required String userId,
    required String proposalId,
  });

  Future<ProposalResolutionDto> rejectProposal({
    required String userId,
    required String proposalId,
  });

  Future<List<ProposalResolutionDto>> confirmProposalTurn({
    required String userId,
    required String turnId,
  });

  Future<List<ProposalResolutionDto>> rejectProposalTurn({
    required String userId,
    required String turnId,
  });
}

class NovaChatRemoteDatasource implements INovaChatRemoteDatasource {
  final Dio _dio;
  final String _baseUrl;

  NovaChatRemoteDatasource({Dio? dio, String? baseUrl})
    : _baseUrl = baseUrl ?? Environment.development.apiBaseUrl,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? Environment.development.apiBaseUrl,
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 45),
              headers: {'Content-Type': 'application/json'},
            ),
          );

  @override
  Future<NovaChatResponseDto> sendMessage({
    required String userId,
    required String question,
  }) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    final fullUrl = '$_baseUrl/chat/$effectiveUserId';
    debugPrint('🔵 [NovaChatDatasource] Sending message to: $fullUrl');
    debugPrint('🔵 [NovaChatDatasource] Payload: {question: "$question"}');

    try {
      final response = await _dio.post(
        '/chat/$effectiveUserId',
        data: {'question': question},
      );

      debugPrint(
        '🟢 [NovaChatDatasource] Response status: ${response.statusCode}',
      );
      debugPrint('🟢 [NovaChatDatasource] Response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          return NovaChatResponseDto.fromJson(Map<String, dynamic>.from(data));
        }
        return NovaChatResponseDto(type: 'chat', message: data.toString());
      }

      throw Exception('Unexpected server response: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('🔴 [NovaChatDatasource] DioException type: ${e.type}');
      debugPrint('🔴 [NovaChatDatasource] DioException message: ${e.message}');
      debugPrint('🔴 [NovaChatDatasource] DioException error: ${e.error}');
      if (e.response != null) {
        debugPrint(
          '🔴 [NovaChatDatasource] Response status: ${e.response?.statusCode}',
        );
        debugPrint(
          '🔴 [NovaChatDatasource] Response body: ${e.response?.data}',
        );
        final data = e.response?.data;
        final errorMsg = data is Map
            ? (data['detail']?.toString() ?? data.toString())
            : (data?.toString() ?? e.message);
        throw Exception('Nova Error ($errorMsg)');
      }
      throw Exception(
        'Unable to reach Nova backend at $_baseUrl. Check if uvicorn is running and adb reverse is active.',
      );
    } catch (e, st) {
      debugPrint('🔴 [NovaChatDatasource] Error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<StudyPlanDto> runReasoning({
    required String userId,
    String triggerType = 'full_pass',
  }) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    debugPrint(
      '🔵 [NovaChatDatasource] runReasoning for $effectiveUserId with trigger: $triggerType',
    );

    try {
      final response = await _dio.post(
        '/reasoning/$effectiveUserId/run',
        data: {'trigger_type': triggerType},
      );

      debugPrint(
        '🟢 [NovaChatDatasource] Reasoning status: ${response.statusCode}',
      );
      if (response.statusCode == 200 && response.data != null) {
        return StudyPlanDto.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to generate reasoning study plan.');
    } on DioException catch (e) {
      debugPrint(
        '🔴 [NovaChatDatasource] Reasoning DioException: ${e.message}',
      );
      if (e.response != null) {
        debugPrint(
          '🔴 [NovaChatDatasource] Reasoning response data: ${e.response?.data}',
        );
        final data = e.response?.data;
        final detail = data is Map
            ? (data['detail']?.toString() ?? data.toString())
            : (data?.toString() ?? e.message);
        throw Exception('Reasoning request failed: $detail');
      }
      throw Exception('Reasoning request failed: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> getFacts({required String userId}) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    try {
      final response = await _dio.get('/facts/$effectiveUserId');
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('🔴 [NovaChatDatasource] getFacts Error: $e');
      return {};
    }
  }

  @override
  Future<List<String>> getInitialSuggestions({required String userId}) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    try {
      final response = await _dio.get('/chat/$effectiveUserId/suggestions');
      if (response.statusCode == 200 && response.data is Map) {
        final rawList = response.data['suggestions'] as List<dynamic>? ?? [];
        final list = rawList.map((s) => s.toString()).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('🔴 [NovaChatDatasource] getInitialSuggestions Error: $e');
    }

    return const [
      'What should I study today?',
      'Explain Quantum Tunneling in simple terms',
      'Review my weak areas in Thermodynamics',
      'Give me a 30-minute high-yield practice quiz',
    ];
  }

  @override
  Future<bool> checkHealth() async {
    try {
      debugPrint('🔵 [NovaChatDatasource] Checking health at $_baseUrl/health');
      final response = await _dio.get('/health');
      debugPrint(
        '🟢 [NovaChatDatasource] Health status: ${response.statusCode}, data: ${response.data}',
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🔴 [NovaChatDatasource] Health check failed: $e');
      return false;
    }
  }

  String _proposalErrorMessage(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      return data is Map
          ? (data['detail']?.toString() ?? data.toString())
          : (data?.toString() ?? e.message ?? 'Unknown error');
    }
    return e.message ?? 'Unable to reach Nova backend';
  }

  @override
  Future<List<PendingProposalDto>> getPendingProposals({
    required String userId,
  }) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    try {
      final response = await _dio.get('/proposals/$effectiveUserId/pending');
      if (response.statusCode == 200 && response.data is Map) {
        final raw = response.data['proposals'] as List<dynamic>? ?? [];
        return raw
            .map(
              (p) => PendingProposalDto.fromJson(
                Map<String, dynamic>.from(p as Map),
              ),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('🔴 [NovaChatDatasource] getPendingProposals Error: $e');
      throw Exception(
        'Could not load pending proposals (${_proposalErrorMessage(e)})',
      );
    }
  }

  @override
  Future<ProposalResolutionDto> confirmProposal({
    required String userId,
    required String proposalId,
  }) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    try {
      final response = await _dio.post(
        '/proposals/$effectiveUserId/$proposalId/confirm',
      );
      return ProposalResolutionDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      debugPrint('🔴 [NovaChatDatasource] confirmProposal Error: $e');
      throw Exception('Could not confirm (${_proposalErrorMessage(e)})');
    }
  }

  @override
  Future<ProposalResolutionDto> rejectProposal({
    required String userId,
    required String proposalId,
  }) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    try {
      final response = await _dio.post(
        '/proposals/$effectiveUserId/$proposalId/reject',
      );
      return ProposalResolutionDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      debugPrint('🔴 [NovaChatDatasource] rejectProposal Error: $e');
      throw Exception('Could not reject (${_proposalErrorMessage(e)})');
    }
  }

  @override
  Future<List<ProposalResolutionDto>> confirmProposalTurn({
    required String userId,
    required String turnId,
  }) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    try {
      final response = await _dio.post(
        '/proposals/$effectiveUserId/turn/$turnId/confirm',
      );
      final raw = response.data['resolutions'] as List<dynamic>? ?? [];
      return raw
          .map(
            (r) => ProposalResolutionDto.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      debugPrint('🔴 [NovaChatDatasource] confirmProposalTurn Error: $e');
      throw Exception('Could not confirm (${_proposalErrorMessage(e)})');
    }
  }

  @override
  Future<List<ProposalResolutionDto>> rejectProposalTurn({
    required String userId,
    required String turnId,
  }) async {
    final effectiveUserId = userId.isNotEmpty ? userId : 'dev-user-001';
    try {
      final response = await _dio.post(
        '/proposals/$effectiveUserId/turn/$turnId/reject',
      );
      final raw = response.data['resolutions'] as List<dynamic>? ?? [];
      return raw
          .map(
            (r) => ProposalResolutionDto.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      debugPrint('🔴 [NovaChatDatasource] rejectProposalTurn Error: $e');
      throw Exception('Could not reject (${_proposalErrorMessage(e)})');
    }
  }
}
