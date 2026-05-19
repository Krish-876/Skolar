import 'dart:convert';
import 'package:flutter/services.dart';
import '../dtos/analytics_dto.dart';

abstract class AnalyticsLocalDataSource {
  Future<AnalyticsDataDto> getAnalytics();
}

class AnalyticsLocalDataSourceImpl implements AnalyticsLocalDataSource {
  @override
  Future<AnalyticsDataDto> getAnalytics() async {
    try {
      final raw = await rootBundle.loadString('assets/data/analytics.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AnalyticsDataDto.fromJson(json);
    } catch (e) {
      throw Exception('Failed to load analytics data: $e');
    }
  }
}