sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  E? get errorOrNull => switch (this) {
        Success() => null,
        Failure(error: final e) => e,
      };

  R fold<R>(R Function(T value) onSuccess, R Function(E error) onFailure) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final e) => onFailure(e),
    };
  }
}

final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;
}
