abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure([super.m = 'Server error']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.m = 'Network error']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.m = 'Cache error']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.m = 'Unknown error']);
}
