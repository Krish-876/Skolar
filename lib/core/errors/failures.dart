abstract class Failure {
  final String message;
  const Failure(this.message);
}
class ServerFailure  extends Failure { const ServerFailure ([String m = 'Server error'])  : super(m); }
class NetworkFailure extends Failure { const NetworkFailure([String m = 'Network error']) : super(m); }
class CacheFailure   extends Failure { const CacheFailure  ([String m = 'Cache error'])   : super(m); }
class UnknownFailure extends Failure { const UnknownFailure([String m = 'Unknown error']) : super(m); }
