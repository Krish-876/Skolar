// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_prediction_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GeneratedQuestion {
  String get question => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  int get examplesUsed => throw _privateConstructorUsedError;

  /// Create a copy of GeneratedQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GeneratedQuestionCopyWith<GeneratedQuestion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GeneratedQuestionCopyWith<$Res> {
  factory $GeneratedQuestionCopyWith(
    GeneratedQuestion value,
    $Res Function(GeneratedQuestion) then,
  ) = _$GeneratedQuestionCopyWithImpl<$Res, GeneratedQuestion>;
  @useResult
  $Res call({String question, String subject, int examplesUsed});
}

/// @nodoc
class _$GeneratedQuestionCopyWithImpl<$Res, $Val extends GeneratedQuestion>
    implements $GeneratedQuestionCopyWith<$Res> {
  _$GeneratedQuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GeneratedQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? subject = null,
    Object? examplesUsed = null,
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
            examplesUsed: null == examplesUsed
                ? _value.examplesUsed
                : examplesUsed // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GeneratedQuestionImplCopyWith<$Res>
    implements $GeneratedQuestionCopyWith<$Res> {
  factory _$$GeneratedQuestionImplCopyWith(
    _$GeneratedQuestionImpl value,
    $Res Function(_$GeneratedQuestionImpl) then,
  ) = __$$GeneratedQuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String question, String subject, int examplesUsed});
}

/// @nodoc
class __$$GeneratedQuestionImplCopyWithImpl<$Res>
    extends _$GeneratedQuestionCopyWithImpl<$Res, _$GeneratedQuestionImpl>
    implements _$$GeneratedQuestionImplCopyWith<$Res> {
  __$$GeneratedQuestionImplCopyWithImpl(
    _$GeneratedQuestionImpl _value,
    $Res Function(_$GeneratedQuestionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GeneratedQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? subject = null,
    Object? examplesUsed = null,
  }) {
    return _then(
      _$GeneratedQuestionImpl(
        question: null == question
            ? _value.question
            : question // ignore: cast_nullable_to_non_nullable
                  as String,
        subject: null == subject
            ? _value.subject
            : subject // ignore: cast_nullable_to_non_nullable
                  as String,
        examplesUsed: null == examplesUsed
            ? _value.examplesUsed
            : examplesUsed // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$GeneratedQuestionImpl implements _GeneratedQuestion {
  const _$GeneratedQuestionImpl({
    required this.question,
    required this.subject,
    required this.examplesUsed,
  });

  @override
  final String question;
  @override
  final String subject;
  @override
  final int examplesUsed;

  @override
  String toString() {
    return 'GeneratedQuestion(question: $question, subject: $subject, examplesUsed: $examplesUsed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GeneratedQuestionImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.examplesUsed, examplesUsed) ||
                other.examplesUsed == examplesUsed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, question, subject, examplesUsed);

  /// Create a copy of GeneratedQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GeneratedQuestionImplCopyWith<_$GeneratedQuestionImpl> get copyWith =>
      __$$GeneratedQuestionImplCopyWithImpl<_$GeneratedQuestionImpl>(
        this,
        _$identity,
      );
}

abstract class _GeneratedQuestion implements GeneratedQuestion {
  const factory _GeneratedQuestion({
    required final String question,
    required final String subject,
    required final int examplesUsed,
  }) = _$GeneratedQuestionImpl;

  @override
  String get question;
  @override
  String get subject;
  @override
  int get examplesUsed;

  /// Create a copy of GeneratedQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GeneratedQuestionImplCopyWith<_$GeneratedQuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$UploadResult {
  String get message => throw _privateConstructorUsedError;
  int get added => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  List<String> get preview => throw _privateConstructorUsedError;

  /// Create a copy of UploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UploadResultCopyWith<UploadResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UploadResultCopyWith<$Res> {
  factory $UploadResultCopyWith(
    UploadResult value,
    $Res Function(UploadResult) then,
  ) = _$UploadResultCopyWithImpl<$Res, UploadResult>;
  @useResult
  $Res call({String message, int added, int total, List<String> preview});
}

/// @nodoc
class _$UploadResultCopyWithImpl<$Res, $Val extends UploadResult>
    implements $UploadResultCopyWith<$Res> {
  _$UploadResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? added = null,
    Object? total = null,
    Object? preview = null,
  }) {
    return _then(
      _value.copyWith(
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            added: null == added
                ? _value.added
                : added // ignore: cast_nullable_to_non_nullable
                      as int,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            preview: null == preview
                ? _value.preview
                : preview // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UploadResultImplCopyWith<$Res>
    implements $UploadResultCopyWith<$Res> {
  factory _$$UploadResultImplCopyWith(
    _$UploadResultImpl value,
    $Res Function(_$UploadResultImpl) then,
  ) = __$$UploadResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message, int added, int total, List<String> preview});
}

/// @nodoc
class __$$UploadResultImplCopyWithImpl<$Res>
    extends _$UploadResultCopyWithImpl<$Res, _$UploadResultImpl>
    implements _$$UploadResultImplCopyWith<$Res> {
  __$$UploadResultImplCopyWithImpl(
    _$UploadResultImpl _value,
    $Res Function(_$UploadResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? added = null,
    Object? total = null,
    Object? preview = null,
  }) {
    return _then(
      _$UploadResultImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        added: null == added
            ? _value.added
            : added // ignore: cast_nullable_to_non_nullable
                  as int,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        preview: null == preview
            ? _value._preview
            : preview // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$UploadResultImpl implements _UploadResult {
  const _$UploadResultImpl({
    required this.message,
    required this.added,
    required this.total,
    final List<String> preview = const [],
  }) : _preview = preview;

  @override
  final String message;
  @override
  final int added;
  @override
  final int total;
  final List<String> _preview;
  @override
  @JsonKey()
  List<String> get preview {
    if (_preview is EqualUnmodifiableListView) return _preview;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_preview);
  }

  @override
  String toString() {
    return 'UploadResult(message: $message, added: $added, total: $total, preview: $preview)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UploadResultImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.added, added) || other.added == added) &&
            (identical(other.total, total) || other.total == total) &&
            const DeepCollectionEquality().equals(other._preview, _preview));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    message,
    added,
    total,
    const DeepCollectionEquality().hash(_preview),
  );

  /// Create a copy of UploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UploadResultImplCopyWith<_$UploadResultImpl> get copyWith =>
      __$$UploadResultImplCopyWithImpl<_$UploadResultImpl>(this, _$identity);
}

abstract class _UploadResult implements UploadResult {
  const factory _UploadResult({
    required final String message,
    required final int added,
    required final int total,
    final List<String> preview,
  }) = _$UploadResultImpl;

  @override
  String get message;
  @override
  int get added;
  @override
  int get total;
  @override
  List<String> get preview;

  /// Create a copy of UploadResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UploadResultImplCopyWith<_$UploadResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$QuestionBankStats {
  int get totalQuestions => throw _privateConstructorUsedError;
  Map<String, int> get subjects => throw _privateConstructorUsedError;
  List<int> get years => throw _privateConstructorUsedError;

  /// Create a copy of QuestionBankStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionBankStatsCopyWith<QuestionBankStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionBankStatsCopyWith<$Res> {
  factory $QuestionBankStatsCopyWith(
    QuestionBankStats value,
    $Res Function(QuestionBankStats) then,
  ) = _$QuestionBankStatsCopyWithImpl<$Res, QuestionBankStats>;
  @useResult
  $Res call({int totalQuestions, Map<String, int> subjects, List<int> years});
}

/// @nodoc
class _$QuestionBankStatsCopyWithImpl<$Res, $Val extends QuestionBankStats>
    implements $QuestionBankStatsCopyWith<$Res> {
  _$QuestionBankStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionBankStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalQuestions = null,
    Object? subjects = null,
    Object? years = null,
  }) {
    return _then(
      _value.copyWith(
            totalQuestions: null == totalQuestions
                ? _value.totalQuestions
                : totalQuestions // ignore: cast_nullable_to_non_nullable
                      as int,
            subjects: null == subjects
                ? _value.subjects
                : subjects // ignore: cast_nullable_to_non_nullable
                      as Map<String, int>,
            years: null == years
                ? _value.years
                : years // ignore: cast_nullable_to_non_nullable
                      as List<int>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuestionBankStatsImplCopyWith<$Res>
    implements $QuestionBankStatsCopyWith<$Res> {
  factory _$$QuestionBankStatsImplCopyWith(
    _$QuestionBankStatsImpl value,
    $Res Function(_$QuestionBankStatsImpl) then,
  ) = __$$QuestionBankStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int totalQuestions, Map<String, int> subjects, List<int> years});
}

/// @nodoc
class __$$QuestionBankStatsImplCopyWithImpl<$Res>
    extends _$QuestionBankStatsCopyWithImpl<$Res, _$QuestionBankStatsImpl>
    implements _$$QuestionBankStatsImplCopyWith<$Res> {
  __$$QuestionBankStatsImplCopyWithImpl(
    _$QuestionBankStatsImpl _value,
    $Res Function(_$QuestionBankStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuestionBankStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalQuestions = null,
    Object? subjects = null,
    Object? years = null,
  }) {
    return _then(
      _$QuestionBankStatsImpl(
        totalQuestions: null == totalQuestions
            ? _value.totalQuestions
            : totalQuestions // ignore: cast_nullable_to_non_nullable
                  as int,
        subjects: null == subjects
            ? _value._subjects
            : subjects // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
        years: null == years
            ? _value._years
            : years // ignore: cast_nullable_to_non_nullable
                  as List<int>,
      ),
    );
  }
}

/// @nodoc

class _$QuestionBankStatsImpl implements _QuestionBankStats {
  const _$QuestionBankStatsImpl({
    required this.totalQuestions,
    required final Map<String, int> subjects,
    final List<int> years = const [],
  }) : _subjects = subjects,
       _years = years;

  @override
  final int totalQuestions;
  final Map<String, int> _subjects;
  @override
  Map<String, int> get subjects {
    if (_subjects is EqualUnmodifiableMapView) return _subjects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_subjects);
  }

  final List<int> _years;
  @override
  @JsonKey()
  List<int> get years {
    if (_years is EqualUnmodifiableListView) return _years;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_years);
  }

  @override
  String toString() {
    return 'QuestionBankStats(totalQuestions: $totalQuestions, subjects: $subjects, years: $years)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionBankStatsImpl &&
            (identical(other.totalQuestions, totalQuestions) ||
                other.totalQuestions == totalQuestions) &&
            const DeepCollectionEquality().equals(other._subjects, _subjects) &&
            const DeepCollectionEquality().equals(other._years, _years));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalQuestions,
    const DeepCollectionEquality().hash(_subjects),
    const DeepCollectionEquality().hash(_years),
  );

  /// Create a copy of QuestionBankStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionBankStatsImplCopyWith<_$QuestionBankStatsImpl> get copyWith =>
      __$$QuestionBankStatsImplCopyWithImpl<_$QuestionBankStatsImpl>(
        this,
        _$identity,
      );
}

abstract class _QuestionBankStats implements QuestionBankStats {
  const factory _QuestionBankStats({
    required final int totalQuestions,
    required final Map<String, int> subjects,
    final List<int> years,
  }) = _$QuestionBankStatsImpl;

  @override
  int get totalQuestions;
  @override
  Map<String, int> get subjects;
  @override
  List<int> get years;

  /// Create a copy of QuestionBankStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionBankStatsImplCopyWith<_$QuestionBankStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$QuestionItem {
  String get questionText => throw _privateConstructorUsedError;
  int get marks => throw _privateConstructorUsedError;
  String get questionType => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  int get year => throw _privateConstructorUsedError;
  String get examType => throw _privateConstructorUsedError;

  /// Create a copy of QuestionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionItemCopyWith<QuestionItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionItemCopyWith<$Res> {
  factory $QuestionItemCopyWith(
    QuestionItem value,
    $Res Function(QuestionItem) then,
  ) = _$QuestionItemCopyWithImpl<$Res, QuestionItem>;
  @useResult
  $Res call({
    String questionText,
    int marks,
    String questionType,
    String subject,
    int year,
    String examType,
  });
}

/// @nodoc
class _$QuestionItemCopyWithImpl<$Res, $Val extends QuestionItem>
    implements $QuestionItemCopyWith<$Res> {
  _$QuestionItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionText = null,
    Object? marks = null,
    Object? questionType = null,
    Object? subject = null,
    Object? year = null,
    Object? examType = null,
  }) {
    return _then(
      _value.copyWith(
            questionText: null == questionText
                ? _value.questionText
                : questionText // ignore: cast_nullable_to_non_nullable
                      as String,
            marks: null == marks
                ? _value.marks
                : marks // ignore: cast_nullable_to_non_nullable
                      as int,
            questionType: null == questionType
                ? _value.questionType
                : questionType // ignore: cast_nullable_to_non_nullable
                      as String,
            subject: null == subject
                ? _value.subject
                : subject // ignore: cast_nullable_to_non_nullable
                      as String,
            year: null == year
                ? _value.year
                : year // ignore: cast_nullable_to_non_nullable
                      as int,
            examType: null == examType
                ? _value.examType
                : examType // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuestionItemImplCopyWith<$Res>
    implements $QuestionItemCopyWith<$Res> {
  factory _$$QuestionItemImplCopyWith(
    _$QuestionItemImpl value,
    $Res Function(_$QuestionItemImpl) then,
  ) = __$$QuestionItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String questionText,
    int marks,
    String questionType,
    String subject,
    int year,
    String examType,
  });
}

/// @nodoc
class __$$QuestionItemImplCopyWithImpl<$Res>
    extends _$QuestionItemCopyWithImpl<$Res, _$QuestionItemImpl>
    implements _$$QuestionItemImplCopyWith<$Res> {
  __$$QuestionItemImplCopyWithImpl(
    _$QuestionItemImpl _value,
    $Res Function(_$QuestionItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuestionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionText = null,
    Object? marks = null,
    Object? questionType = null,
    Object? subject = null,
    Object? year = null,
    Object? examType = null,
  }) {
    return _then(
      _$QuestionItemImpl(
        questionText: null == questionText
            ? _value.questionText
            : questionText // ignore: cast_nullable_to_non_nullable
                  as String,
        marks: null == marks
            ? _value.marks
            : marks // ignore: cast_nullable_to_non_nullable
                  as int,
        questionType: null == questionType
            ? _value.questionType
            : questionType // ignore: cast_nullable_to_non_nullable
                  as String,
        subject: null == subject
            ? _value.subject
            : subject // ignore: cast_nullable_to_non_nullable
                  as String,
        year: null == year
            ? _value.year
            : year // ignore: cast_nullable_to_non_nullable
                  as int,
        examType: null == examType
            ? _value.examType
            : examType // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$QuestionItemImpl implements _QuestionItem {
  const _$QuestionItemImpl({
    required this.questionText,
    required this.marks,
    required this.questionType,
    required this.subject,
    required this.year,
    required this.examType,
  });

  @override
  final String questionText;
  @override
  final int marks;
  @override
  final String questionType;
  @override
  final String subject;
  @override
  final int year;
  @override
  final String examType;

  @override
  String toString() {
    return 'QuestionItem(questionText: $questionText, marks: $marks, questionType: $questionType, subject: $subject, year: $year, examType: $examType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionItemImpl &&
            (identical(other.questionText, questionText) ||
                other.questionText == questionText) &&
            (identical(other.marks, marks) || other.marks == marks) &&
            (identical(other.questionType, questionType) ||
                other.questionType == questionType) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.examType, examType) ||
                other.examType == examType));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    questionText,
    marks,
    questionType,
    subject,
    year,
    examType,
  );

  /// Create a copy of QuestionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionItemImplCopyWith<_$QuestionItemImpl> get copyWith =>
      __$$QuestionItemImplCopyWithImpl<_$QuestionItemImpl>(this, _$identity);
}

abstract class _QuestionItem implements QuestionItem {
  const factory _QuestionItem({
    required final String questionText,
    required final int marks,
    required final String questionType,
    required final String subject,
    required final int year,
    required final String examType,
  }) = _$QuestionItemImpl;

  @override
  String get questionText;
  @override
  int get marks;
  @override
  String get questionType;
  @override
  String get subject;
  @override
  int get year;
  @override
  String get examType;

  /// Create a copy of QuestionItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionItemImplCopyWith<_$QuestionItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$QuestionsResponse {
  int get total => throw _privateConstructorUsedError;
  List<QuestionItem> get questions => throw _privateConstructorUsedError;

  /// Create a copy of QuestionsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionsResponseCopyWith<QuestionsResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionsResponseCopyWith<$Res> {
  factory $QuestionsResponseCopyWith(
    QuestionsResponse value,
    $Res Function(QuestionsResponse) then,
  ) = _$QuestionsResponseCopyWithImpl<$Res, QuestionsResponse>;
  @useResult
  $Res call({int total, List<QuestionItem> questions});
}

/// @nodoc
class _$QuestionsResponseCopyWithImpl<$Res, $Val extends QuestionsResponse>
    implements $QuestionsResponseCopyWith<$Res> {
  _$QuestionsResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? total = null, Object? questions = null}) {
    return _then(
      _value.copyWith(
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            questions: null == questions
                ? _value.questions
                : questions // ignore: cast_nullable_to_non_nullable
                      as List<QuestionItem>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuestionsResponseImplCopyWith<$Res>
    implements $QuestionsResponseCopyWith<$Res> {
  factory _$$QuestionsResponseImplCopyWith(
    _$QuestionsResponseImpl value,
    $Res Function(_$QuestionsResponseImpl) then,
  ) = __$$QuestionsResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int total, List<QuestionItem> questions});
}

/// @nodoc
class __$$QuestionsResponseImplCopyWithImpl<$Res>
    extends _$QuestionsResponseCopyWithImpl<$Res, _$QuestionsResponseImpl>
    implements _$$QuestionsResponseImplCopyWith<$Res> {
  __$$QuestionsResponseImplCopyWithImpl(
    _$QuestionsResponseImpl _value,
    $Res Function(_$QuestionsResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuestionsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? total = null, Object? questions = null}) {
    return _then(
      _$QuestionsResponseImpl(
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        questions: null == questions
            ? _value._questions
            : questions // ignore: cast_nullable_to_non_nullable
                  as List<QuestionItem>,
      ),
    );
  }
}

/// @nodoc

class _$QuestionsResponseImpl implements _QuestionsResponse {
  const _$QuestionsResponseImpl({
    required this.total,
    required final List<QuestionItem> questions,
  }) : _questions = questions;

  @override
  final int total;
  final List<QuestionItem> _questions;
  @override
  List<QuestionItem> get questions {
    if (_questions is EqualUnmodifiableListView) return _questions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_questions);
  }

  @override
  String toString() {
    return 'QuestionsResponse(total: $total, questions: $questions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionsResponseImpl &&
            (identical(other.total, total) || other.total == total) &&
            const DeepCollectionEquality().equals(
              other._questions,
              _questions,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    total,
    const DeepCollectionEquality().hash(_questions),
  );

  /// Create a copy of QuestionsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionsResponseImplCopyWith<_$QuestionsResponseImpl> get copyWith =>
      __$$QuestionsResponseImplCopyWithImpl<_$QuestionsResponseImpl>(
        this,
        _$identity,
      );
}

abstract class _QuestionsResponse implements QuestionsResponse {
  const factory _QuestionsResponse({
    required final int total,
    required final List<QuestionItem> questions,
  }) = _$QuestionsResponseImpl;

  @override
  int get total;
  @override
  List<QuestionItem> get questions;

  /// Create a copy of QuestionsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionsResponseImplCopyWith<_$QuestionsResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
