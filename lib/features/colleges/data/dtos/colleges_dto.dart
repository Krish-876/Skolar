import '../../domain/entities/colleges_entity.dart';

class CollegesDto {
  final String id;
  final String name;
  final String location;

  const CollegesDto({
    required this.id,
    required this.name,
    required this.location,
  });

  factory CollegesDto.fromJson(Map<String, dynamic> json) => CollegesDto(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
  };

  CollegesEntity toEntity() =>
      CollegesEntity(id: id, name: name, location: location);
}
