import 'package:flutter/foundation.dart';
import '../../domain/entities/exam_prediction_entity.dart';

class ExamPredictionProvider extends ChangeNotifier {
  List<ExamPredictionEntity> _items = [];
  bool _loading = false;
  String? _error;

  List<ExamPredictionEntity> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    // TODO: call use case
    await Future.delayed(const Duration(milliseconds: 500));
    _loading = false;
    notifyListeners();
  }
}
