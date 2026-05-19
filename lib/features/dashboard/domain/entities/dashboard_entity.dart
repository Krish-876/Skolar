import 'package:nova/shared/models/base_models.dart';

class DashboardEntity extends BaseEntity {
  final String sectionTitle;
  const DashboardEntity({required super.id, required this.sectionTitle});
}
