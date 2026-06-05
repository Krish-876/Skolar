import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/repository_impl/auth_repository_impl.dart';
import '../../domain/usecases/auth_usecases.dart';

// ── Supabase client provider ─────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ── Datasource provider ──────────────────────────────────────────────────────
final authDataSourceProvider = Provider<AuthDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(supabaseClientProvider)),
);

// ── Repository provider ──────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepositoryImpl>(
  (ref) => AuthRepositoryImpl(ref.watch(authDataSourceProvider)),
);

// ── Use case providers ───────────────────────────────────────────────────────
final sendMagicLinkUseCaseProvider = Provider(
  (ref) => SendMagicLinkUseCase(ref.watch(authRepositoryProvider)),
);

final validateEmailUseCaseProvider = Provider(
  (ref) => ValidateCollegeEmailUseCase(ref.watch(authRepositoryProvider)),
);

final getCurrentUserUseCaseProvider = Provider(
  (ref) => GetCurrentUserUseCase(ref.watch(authRepositoryProvider)),
);

final signOutUseCaseProvider = Provider(
  (ref) => SignOutUseCase(ref.watch(authRepositoryProvider)),
);

// ── Auth state ───────────────────────────────────────────────────────────────
enum AuthStatus { initial, loading, magicLinkSent, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  AuthState copyWith({AuthStatus? status, String? errorMessage}) => AuthState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Auth notifier ────────────────────────────────────────────────────────────
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> sendMagicLink(String email) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final isValid = await ref
          .read(validateEmailUseCaseProvider)
          .call(email);

      if (!isValid) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Your college isn\'t on Skolar yet.',
        );
        return;
      }

      await ref.read(sendMagicLinkUseCaseProvider).call(email);
      state = state.copyWith(status: AuthStatus.magicLinkSent);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  void reset() => state = const AuthState();
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// ── Current session stream ───────────────────────────────────────────────────
final authSessionProvider = StreamProvider<Session?>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session,
  ),
);