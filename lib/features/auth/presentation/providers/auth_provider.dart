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

final signInWithPasswordUseCaseProvider = Provider(
  (ref) => SignInWithPasswordUseCase(ref.watch(authRepositoryProvider)),
);

final signUpWithPasswordUseCaseProvider = Provider(
  (ref) => SignUpWithPasswordUseCase(ref.watch(authRepositoryProvider)),
);

final sendPasswordResetUseCaseProvider = Provider(
  (ref) => SendPasswordResetUseCase(ref.watch(authRepositoryProvider)),
);

final signInWithGoogleUseCaseProvider = Provider(
  (ref) => SignInWithGoogleUseCase(ref.watch(authRepositoryProvider)),
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
enum AuthStatus {
  initial,
  loading,
  authenticated,
  magicLinkSent,
  passwordResetSent,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? successMessage,
  }) => AuthState(
    status: status ?? this.status,
    errorMessage: errorMessage,
    successMessage: successMessage,
  );
}

// ── Auth notifier ────────────────────────────────────────────────────────────
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Auto-reset state whenever user is signed out
    ref.listen(authSessionProvider, (previous, next) {
      next.whenData((session) {
        if (session == null) {
          reset();
        }
      });
    });
    return const AuthState();
  }

  Future<void> signOut() async {
    await ref.read(signOutUseCaseProvider).call();
    reset();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final isValid = await ref.read(validateEmailUseCaseProvider).call(email);
      if (!isValid) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Please enter a valid BITS institutional email.',
        );
        return;
      }

      await ref
          .read(signInWithPasswordUseCaseProvider)
          .call(email: email, password: password);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        successMessage: 'Signed in successfully!',
      );
    } on AuthException catch (e) {
      String message = e.message;
      if (message.toLowerCase().contains('invalid login credentials')) {
        message = 'Incorrect email or password. Please try again.';
      } else if (message.toLowerCase().contains('email not confirmed')) {
        message = 'Please verify your email address before signing in.';
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Sign in failed. Please try again later.',
      );
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final isValid = await ref.read(validateEmailUseCaseProvider).call(email);
      if (!isValid) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Please register with your BITS institutional email.',
        );
        return;
      }

      final res = await ref
          .read(signUpWithPasswordUseCaseProvider)
          .call(email: email, password: password);

      if (res.session != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          successMessage: 'Account created!',
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.magicLinkSent,
          successMessage:
              'Account created! Please check your email to confirm.',
        );
      }
    } on AuthException catch (e) {
      String message = e.message;
      if (message.toLowerCase().contains('user already registered')) {
        message = 'An account with this email already exists. Please log in.';
      } else if (message.toLowerCase().contains('password')) {
        message = 'Password should be at least 6 characters.';
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Sign up failed. Please try again later.',
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      await ref.read(sendPasswordResetUseCaseProvider).call(email);
      state = state.copyWith(
        status: AuthStatus.passwordResetSent,
        successMessage: 'Password reset email sent! Check your inbox.',
      );
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Could not send reset email. Please try again.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      await ref.read(signInWithGoogleUseCaseProvider).call();
      // Browser opens for OAuth
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Google sign-in failed. Please try again.',
      );
    }
  }

  Future<void> sendMagicLink(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final isValid = await ref.read(validateEmailUseCaseProvider).call(email);
      if (!isValid) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Your college isn\'t on Skolar yet.',
        );
        return;
      }

      await ref.read(sendMagicLinkUseCaseProvider).call(email);
      state = state.copyWith(
        status: AuthStatus.magicLinkSent,
        successMessage: 'Magic link sent! Check your college email.',
      );
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
