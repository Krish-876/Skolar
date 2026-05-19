import 'package:nova/shared/models/base_models.dart';

class SyllabusEntity extends BaseEntity {
  final String topic;
  final bool isCompleted;
  const SyllabusEntity({required super.id, required this.topic, required this.isCompleted});
}
