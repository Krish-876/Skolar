import 'package:flutter/foundation.dart';
import '../../domain/entities/mock_tests_entity.dart';

class MockTestsProvider extends ChangeNotifier {
  List<MockTestsEntity> _items = [];
  bool _loading = false;
  String? _error;

  List<MockTestsEntity> get items => _items;
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
