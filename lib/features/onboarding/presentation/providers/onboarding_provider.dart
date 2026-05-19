import 'package:flutter/foundation.dart';
import '../../domain/entities/onboarding_entity.dart';

class OnboardingProvider extends ChangeNotifier {
  List<OnboardingEntity> _items = [];
  bool _loading = false;
  String? _error;

  List<OnboardingEntity> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 500));
    _loading = false;
    notifyListeners();
  }
}
