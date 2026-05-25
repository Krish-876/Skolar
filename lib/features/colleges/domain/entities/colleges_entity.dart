import 'package:Skolar/shared/models/base_models.dart';


class CollegesEntity extends BaseEntity {
  final String name;
  final String location;
  const CollegesEntity({required super.id, required this.name, required this.location});
}
