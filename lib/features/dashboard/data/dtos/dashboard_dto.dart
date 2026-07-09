import '../../domain/entities/dashboard_entity.dart';

class DashboardDto {
  final String id;
  final String sectionTitle;

  const DashboardDto({required this.id, required this.sectionTitle});

  factory DashboardDto.fromJson(Map<String, dynamic> json) => DashboardDto(
    id: json['id'] as String,
    sectionTitle: json['sectionTitle'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'sectionTitle': sectionTitle};

  DashboardEntity toEntity() =>
      DashboardEntity(id: id, sectionTitle: sectionTitle);
}
