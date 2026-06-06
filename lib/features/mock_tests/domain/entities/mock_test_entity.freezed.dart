// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mock_test_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$QuizQuestion {
  String get question => throw _privateConstructorUsedError;
  List<String> get options => throw _privateConstructorUsedError;
  int get correctIndex => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  int get marks => throw _privateConstructorUsedError;

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuizQuestionCopyWith<QuizQuestion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuizQuestionCopyWith<$Res> {
  factory $QuizQuestionCopyWith(
    QuizQuestion value,
    $Res Function(QuizQuestion) then,
  ) = _$QuizQuestionCopyWithImpl<$Res, QuizQuestion>;
  @useResult
  $Res call({
    String question,
    List<String> options,
    int correctIndex,
    String subject,
    int marks,
  });
}

/// @nodoc
class _$QuizQuestionCopyWithImpl<$Res, $Val extends QuizQuestion>
    implements $QuizQuestionCopyWith<$Res> {
  _$QuizQuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? options = null,
    Object? correctIndex = null,
    Object? subject = null,
    Object? marks = null,
  }) {
    return _then(
      _value.copyWith(
            question: null == question
                ? _value.question
                : question // ignore: cast_nullable_to_non_nullable
                      as String,
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            correctIndex: null == correctIndex
                ? _value.correctIndex
                : correctIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            subject: null == subject
                ? _value.subject
                : subject // ignore: cast_nullable_to_non_nullable
                      as String,
            marks: null == marks
                ? _value.marks
                : marks // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuizQuestionImplCopyWith<$Res>
    implements $QuizQuestionCopyWith<$Res> {
  factory _$$QuizQuestionImplCopyWith(
    _$QuizQuestionImpl value,
    $Res Function(_$QuizQuestionImpl) then,
  ) = __$$QuizQuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String question,
    List<String> options,
    int correctIndex,
    String subject,
    int marks,
  });
}

/// @nodoc
class __$$QuizQuestionImplCopyWithImpl<$Res>
    extends _$QuizQuestionCopyWithImpl<$Res, _$QuizQuestionImpl>
    implements _$$QuizQuestionImplCopyWith<$Res> {
  __$$QuizQuestionImplCopyWithImpl(
    _$QuizQuestionImpl _value,
    $Res Function(_$QuizQuestionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? options = null,
    Object? correctIndex = null,
    Object? subject = null,
    Object? marks = null,
  }) {
    return _then(
      _$QuizQuestionImpl(
        question: null == question
            ? _value.question
            : question // ignore: cast_nullable_to_non_nullable
                  as String,
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        correctIndex: null == correctIndex
            ? _value.correctIndex
            : correctIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        subject: null == subject
            ? _value.subject
            : subject // ignore: cast_nullable_to_non_nullable
                  as String,
        marks: null == marks
            ? _value.marks
            : marks // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$QuizQuestionImpl implements _QuizQuestion {
  const _$QuizQuestionImpl({
    required this.question,
    required final List<String> options,
    required this.correctIndex,
    required this.subject,
    required this.marks,
  }) : _options = options;

  @override
  final String question;
  final List<String> _options;
  @override
  List<String> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  final int correctIndex;
  @override
  final String subject;
  @override
  final int marks;

  @override
  String toString() {
    return 'QuizQuestion(question: $question, options: $options, correctIndex: $correctIndex, subject: $subject, marks: $marks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuizQuestionImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            (identical(other.correctIndex, correctIndex) ||
                other.correctIndex == correctIndex) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.marks, marks) || other.marks == marks));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    question,
    const DeepCollectionEquality().hash(_options),
    correctIndex,
    subject,
    marks,
  );

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuizQuestionImplCopyWith<_$QuizQuestionImpl> get copyWith =>
      __$$QuizQuestionImplCopyWithImpl<_$QuizQuestionImpl>(this, _$identity);
}

abstract class _QuizQuestion implements QuizQuestion {
  const factory _QuizQuestion({
    required final String question,
    required final List<String> options,
    required final int correctIndex,
    required final String subject,
    required final int marks,
  }) = _$QuizQuestionImpl;

  @override
  String get question;
  @override
  List<String> get options;
  @override
  int get correctIndex;
  @override
  String get subject;
  @override
  int get marks;

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuizQuestionImplCopyWith<_$QuizQuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$OpenQuestion {
  String get question => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  int get marks => throw _privateConstructorUsedError;
  String get modelAnswer => throw _privateConstructorUsedError;

  /// Create a copy of OpenQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OpenQuestionCopyWith<OpenQuestion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OpenQuestionCopyWith<$Res> {
  factory $OpenQuestionCopyWith(
    OpenQuestion value,
    $Res Function(OpenQuestion) then,
  ) = _$OpenQuestionCopyWithImpl<$Res, OpenQuestion>;
  @useResult
  $Res call({String question, String subject, int marks, String modelAnswer});
}

/// @nodoc
class _$OpenQuestionCopyWithImpl<$Res, $Val extends OpenQuestion>
    implements $OpenQuestionCopyWith<$Res> {
  _$OpenQuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OpenQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? subject = null,
    Object? marks = null,
    Object? modelAnswer = null,
  }) {
    return _then(
      _value.copyWith(
            question: null == question
                ? _value.question
                : question // ignore: cast_nullable_to_non_nullable
                      as String,
            subject: null == subject
                ? _value.subject
                : subject // ignore: cast_nullable_to_non_nullable
                      as String,
            marks: null == marks
                ? _value.marks
                : marks // ignore: cast_nullable_to_non_nullable
                      as int,
            modelAnswer: null == modelAnswer
                ? _value.modelAnswer
                : modelAnswer // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OpenQuestionImplCopyWith<$Res>
    implements $OpenQuestionCopyWith<$Res> {
  factory _$$OpenQuestionImplCopyWith(
    _$OpenQuestionImpl value,
    $Res Function(_$OpenQuestionImpl) then,
  ) = __$$OpenQuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String question, String subject, int marks, String modelAnswer});
}

/// @nodoc
class __$$OpenQuestionImplCopyWithImpl<$Res>
    extends _$OpenQuestionCopyWithImpl<$Res, _$OpenQuestionImpl>
    implements _$$OpenQuestionImplCopyWith<$Res> {
  __$$OpenQuestionImplCopyWithImpl(
    _$OpenQuestionImpl _value,
    $Res Function(_$OpenQuestionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OpenQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? subject = null,
    Object? marks = null,
    Object? modelAnswer = null,
  }) {
    return _then(
      _$OpenQuestionImpl(
        question: null == question
            ? _value.question
            : question // ignore: cast_nullable_to_non_nullable
                  as String,
        subject: null == subject
            ? _value.subject
            : subject // ignore: cast_nullable_to_non_nullable
                  as String,
        marks: null == marks
            ? _value.marks
            : marks // ignore: cast_nullable_to_non_nullable
                  as int,
        modelAnswer: null == modelAnswer
            ? _value.modelAnswer
            : modelAnswer // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$OpenQuestionImpl implements _OpenQuestion {
  const _$OpenQuestionImpl({
    required this.question,
    required this.subject,
    required this.marks,
    required this.modelAnswer,
  });

  @override
  final String question;
  @override
  final String subject;
  @override
  final int marks;
  @override
  final String modelAnswer;

  @override
  String toString() {
    return 'OpenQuestion(question: $question, subject: $subject, marks: $marks, modelAnswer: $modelAnswer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OpenQuestionImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.marks, marks) || other.marks == marks) &&
            (identical(other.modelAnswer, modelAnswer) ||
                other.modelAnswer == modelAnswer));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, question, subject, marks, modelAnswer);

  /// Create a copy of OpenQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OpenQuestionImplCopyWith<_$OpenQuestionImpl> get copyWith =>
      __$$OpenQuestionImplCopyWithImpl<_$OpenQuestionImpl>(this, _$identity);
}

abstract class _OpenQuestion implements OpenQuestion {
  const factory _OpenQuestion({
    required final String question,
    required final String subject,
    required final int marks,
    required final String modelAnswer,
  }) = _$OpenQuestionImpl;

  @override
  String get question;
  @override
  String get subject;
  @override
  int get marks;
  @override
  String get modelAnswer;

  /// Create a copy of OpenQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OpenQuestionImplCopyWith<_$OpenQuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
