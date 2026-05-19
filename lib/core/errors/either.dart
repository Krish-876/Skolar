/// Functional Either type for error handling
abstract class Either<L, R> {
  T fold<T>(
    T Function(L) onLeft,
    T Function(R) onRight,
  );

  Either<L, T> map<T>(T Function(R) f);
  Either<L2, R> mapLeft<L2>(L2 Function(L) f);
  Either<L, T> flatMap<T>(Either<L, T> Function(R) f);

  R? toNullable();
  L? leftToNullable();
  bool isRight();
  bool isLeft();
}

class Left<L, R> implements Either<L, R> {
  final L value;

  Left(this.value);

  @override
  T fold<T>(T Function(L) onLeft, T Function(R) onRight) => onLeft(value);

  @override
  Either<L, T> map<T>(T Function(R) f) => Left(value);

  @override
  Either<L2, R> mapLeft<L2>(L2 Function(L) f) => Left(f(value));

  @override
  Either<L, T> flatMap<T>(Either<L, T> Function(R) f) => Left(value);

  @override
  R? toNullable() => null;

  @override
  L? leftToNullable() => value;

  @override
  bool isRight() => false;

  @override
  bool isLeft() => true;
}

class Right<L, R> implements Either<L, R> {
  final R value;

  Right(this.value);

  @override
  T fold<T>(T Function(L) onLeft, T Function(R) onRight) => onRight(value);

  @override
  Either<L, T> map<T>(T Function(R) f) => Right(f(value));

  @override
  Either<L2, R> mapLeft<L2>(L2 Function(L) f) => Right(value);

  @override
  Either<L, T> flatMap<T>(Either<L, T> Function(R) f) => f(value);

  @override
  R? toNullable() => value;

  @override
  L? leftToNullable() => null;

  @override
  bool isRight() => true;

  @override
  bool isLeft() => false;
}
