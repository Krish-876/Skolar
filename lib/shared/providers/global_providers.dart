import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/shared/models/user_model.dart';

/// Global loading state provider
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Global error state provider
final errorMessageProvider = StateProvider<String?>((ref) => null);

/// Global success message provider
final successMessageProvider = StateProvider<String?>((ref) => null);

/// Utility function to handle async operations
Future<T> withLoadingState<T>(
  WidgetRef ref,
  Future<T> Function() operation,
) async {
  ref.read(isLoadingProvider.notifier).state = true;
  try {
    final result = await operation();
    ref.read(isLoadingProvider.notifier).state = false;
    return result;
  } catch (e) {
    ref.read(isLoadingProvider.notifier).state = false;
    ref.read(errorMessageProvider.notifier).state = e.toString();
    rethrow;
  }
}

final userProvider = Provider<UserModel>((ref) {
  return UserModel(
    name: 'Krishna',
    email: 'f20240175@hyderabad.bits-pilani.ac.in',
    college: 'BPHC',
    rollNumber: '2024A7PS0175H',
    academicYear: 1,
    streakDays: 15,
    targetDays: 90,
    totalWatch: '24h 30m',
    totalUploads: 8,
    friendCount: 12,
    weekProgress: [true, true, true, false, null, null, null],
    weekLabels: ['Mon', 'Tue', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'],
  );
});