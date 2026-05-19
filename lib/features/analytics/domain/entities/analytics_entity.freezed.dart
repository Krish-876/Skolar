// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$WeeklyDataPoint {
  String get label => throw _privateConstructorUsedError;
  double get value => throw _privateConstructorUsedError;

  /// Create a copy of WeeklyDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WeeklyDataPointCopyWith<WeeklyDataPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WeeklyDataPointCopyWith<$Res> {
  factory $WeeklyDataPointCopyWith(
    WeeklyDataPoint value,
    $Res Function(WeeklyDataPoint) then,
  ) = _$WeeklyDataPointCopyWithImpl<$Res, WeeklyDataPoint>;
  @useResult
  $Res call({String label, double value});
}

/// @nodoc
class _$WeeklyDataPointCopyWithImpl<$Res, $Val extends WeeklyDataPoint>
    implements $WeeklyDataPointCopyWith<$Res> {
  _$WeeklyDataPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WeeklyDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? label = null, Object? value = null}) {
    return _then(
      _value.copyWith(
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WeeklyDataPointImplCopyWith<$Res>
    implements $WeeklyDataPointCopyWith<$Res> {
  factory _$$WeeklyDataPointImplCopyWith(
    _$WeeklyDataPointImpl value,
    $Res Function(_$WeeklyDataPointImpl) then,
  ) = __$$WeeklyDataPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String label, double value});
}

/// @nodoc
class __$$WeeklyDataPointImplCopyWithImpl<$Res>
    extends _$WeeklyDataPointCopyWithImpl<$Res, _$WeeklyDataPointImpl>
    implements _$$WeeklyDataPointImplCopyWith<$Res> {
  __$$WeeklyDataPointImplCopyWithImpl(
    _$WeeklyDataPointImpl _value,
    $Res Function(_$WeeklyDataPointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WeeklyDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? label = null, Object? value = null}) {
    return _then(
      _$WeeklyDataPointImpl(
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$WeeklyDataPointImpl implements _WeeklyDataPoint {
  const _$WeeklyDataPointImpl({required this.label, required this.value});

  @override
  final String label;
  @override
  final double value;

  @override
  String toString() {
    return 'WeeklyDataPoint(label: $label, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyDataPointImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, label, value);

  /// Create a copy of WeeklyDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WeeklyDataPointImplCopyWith<_$WeeklyDataPointImpl> get copyWith =>
      __$$WeeklyDataPointImplCopyWithImpl<_$WeeklyDataPointImpl>(
        this,
        _$identity,
      );
}

abstract class _WeeklyDataPoint implements WeeklyDataPoint {
  const factory _WeeklyDataPoint({
    required final String label,
    required final double value,
  }) = _$WeeklyDataPointImpl;

  @override
  String get label;
  @override
  double get value;

  /// Create a copy of WeeklyDataPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WeeklyDataPointImplCopyWith<_$WeeklyDataPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RecentActivity {
  String get time => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get subtitle => throw _privateConstructorUsedError;
  String get dueDate => throw _privateConstructorUsedError;
  List<String> get participantAvatars => throw _privateConstructorUsedError;

  /// Create a copy of RecentActivity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecentActivityCopyWith<RecentActivity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecentActivityCopyWith<$Res> {
  factory $RecentActivityCopyWith(
    RecentActivity value,
    $Res Function(RecentActivity) then,
  ) = _$RecentActivityCopyWithImpl<$Res, RecentActivity>;
  @useResult
  $Res call({
    String time,
    String title,
    String subtitle,
    String dueDate,
    List<String> participantAvatars,
  });
}

/// @nodoc
class _$RecentActivityCopyWithImpl<$Res, $Val extends RecentActivity>
    implements $RecentActivityCopyWith<$Res> {
  _$RecentActivityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecentActivity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? title = null,
    Object? subtitle = null,
    Object? dueDate = null,
    Object? participantAvatars = null,
  }) {
    return _then(
      _value.copyWith(
            time: null == time
                ? _value.time
                : time // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            subtitle: null == subtitle
                ? _value.subtitle
                : subtitle // ignore: cast_nullable_to_non_nullable
                      as String,
            dueDate: null == dueDate
                ? _value.dueDate
                : dueDate // ignore: cast_nullable_to_non_nullable
                      as String,
            participantAvatars: null == participantAvatars
                ? _value.participantAvatars
                : participantAvatars // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecentActivityImplCopyWith<$Res>
    implements $RecentActivityCopyWith<$Res> {
  factory _$$RecentActivityImplCopyWith(
    _$RecentActivityImpl value,
    $Res Function(_$RecentActivityImpl) then,
  ) = __$$RecentActivityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String time,
    String title,
    String subtitle,
    String dueDate,
    List<String> participantAvatars,
  });
}

/// @nodoc
class __$$RecentActivityImplCopyWithImpl<$Res>
    extends _$RecentActivityCopyWithImpl<$Res, _$RecentActivityImpl>
    implements _$$RecentActivityImplCopyWith<$Res> {
  __$$RecentActivityImplCopyWithImpl(
    _$RecentActivityImpl _value,
    $Res Function(_$RecentActivityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecentActivity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = null,
    Object? title = null,
    Object? subtitle = null,
    Object? dueDate = null,
    Object? participantAvatars = null,
  }) {
    return _then(
      _$RecentActivityImpl(
        time: null == time
            ? _value.time
            : time // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        subtitle: null == subtitle
            ? _value.subtitle
            : subtitle // ignore: cast_nullable_to_non_nullable
                  as String,
        dueDate: null == dueDate
            ? _value.dueDate
            : dueDate // ignore: cast_nullable_to_non_nullable
                  as String,
        participantAvatars: null == participantAvatars
            ? _value._participantAvatars
            : participantAvatars // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$RecentActivityImpl implements _RecentActivity {
  const _$RecentActivityImpl({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.dueDate,
    final List<String> participantAvatars = const [],
  }) : _participantAvatars = participantAvatars;

  @override
  final String time;
  @override
  final String title;
  @override
  final String subtitle;
  @override
  final String dueDate;
  final List<String> _participantAvatars;
  @override
  @JsonKey()
  List<String> get participantAvatars {
    if (_participantAvatars is EqualUnmodifiableListView)
      return _participantAvatars;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participantAvatars);
  }

  @override
  String toString() {
    return 'RecentActivity(time: $time, title: $title, subtitle: $subtitle, dueDate: $dueDate, participantAvatars: $participantAvatars)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecentActivityImpl &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            const DeepCollectionEquality().equals(
              other._participantAvatars,
              _participantAvatars,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    time,
    title,
    subtitle,
    dueDate,
    const DeepCollectionEquality().hash(_participantAvatars),
  );

  /// Create a copy of RecentActivity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecentActivityImplCopyWith<_$RecentActivityImpl> get copyWith =>
      __$$RecentActivityImplCopyWithImpl<_$RecentActivityImpl>(
        this,
        _$identity,
      );
}

abstract class _RecentActivity implements RecentActivity {
  const factory _RecentActivity({
    required final String time,
    required final String title,
    required final String subtitle,
    required final String dueDate,
    final List<String> participantAvatars,
  }) = _$RecentActivityImpl;

  @override
  String get time;
  @override
  String get title;
  @override
  String get subtitle;
  @override
  String get dueDate;
  @override
  List<String> get participantAvatars;

  /// Create a copy of RecentActivity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecentActivityImplCopyWith<_$RecentActivityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TaskItem {
  String get title => throw _privateConstructorUsedError;
  String get dueDate => throw _privateConstructorUsedError;
  List<String> get assigneeAvatars => throw _privateConstructorUsedError;

  /// Create a copy of TaskItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskItemCopyWith<TaskItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskItemCopyWith<$Res> {
  factory $TaskItemCopyWith(TaskItem value, $Res Function(TaskItem) then) =
      _$TaskItemCopyWithImpl<$Res, TaskItem>;
  @useResult
  $Res call({String title, String dueDate, List<String> assigneeAvatars});
}

/// @nodoc
class _$TaskItemCopyWithImpl<$Res, $Val extends TaskItem>
    implements $TaskItemCopyWith<$Res> {
  _$TaskItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? dueDate = null,
    Object? assigneeAvatars = null,
  }) {
    return _then(
      _value.copyWith(
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            dueDate: null == dueDate
                ? _value.dueDate
                : dueDate // ignore: cast_nullable_to_non_nullable
                      as String,
            assigneeAvatars: null == assigneeAvatars
                ? _value.assigneeAvatars
                : assigneeAvatars // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskItemImplCopyWith<$Res>
    implements $TaskItemCopyWith<$Res> {
  factory _$$TaskItemImplCopyWith(
    _$TaskItemImpl value,
    $Res Function(_$TaskItemImpl) then,
  ) = __$$TaskItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, String dueDate, List<String> assigneeAvatars});
}

/// @nodoc
class __$$TaskItemImplCopyWithImpl<$Res>
    extends _$TaskItemCopyWithImpl<$Res, _$TaskItemImpl>
    implements _$$TaskItemImplCopyWith<$Res> {
  __$$TaskItemImplCopyWithImpl(
    _$TaskItemImpl _value,
    $Res Function(_$TaskItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? dueDate = null,
    Object? assigneeAvatars = null,
  }) {
    return _then(
      _$TaskItemImpl(
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        dueDate: null == dueDate
            ? _value.dueDate
            : dueDate // ignore: cast_nullable_to_non_nullable
                  as String,
        assigneeAvatars: null == assigneeAvatars
            ? _value._assigneeAvatars
            : assigneeAvatars // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$TaskItemImpl implements _TaskItem {
  const _$TaskItemImpl({
    required this.title,
    required this.dueDate,
    final List<String> assigneeAvatars = const [],
  }) : _assigneeAvatars = assigneeAvatars;

  @override
  final String title;
  @override
  final String dueDate;
  final List<String> _assigneeAvatars;
  @override
  @JsonKey()
  List<String> get assigneeAvatars {
    if (_assigneeAvatars is EqualUnmodifiableListView) return _assigneeAvatars;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assigneeAvatars);
  }

  @override
  String toString() {
    return 'TaskItem(title: $title, dueDate: $dueDate, assigneeAvatars: $assigneeAvatars)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskItemImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            const DeepCollectionEquality().equals(
              other._assigneeAvatars,
              _assigneeAvatars,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    title,
    dueDate,
    const DeepCollectionEquality().hash(_assigneeAvatars),
  );

  /// Create a copy of TaskItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskItemImplCopyWith<_$TaskItemImpl> get copyWith =>
      __$$TaskItemImplCopyWithImpl<_$TaskItemImpl>(this, _$identity);
}

abstract class _TaskItem implements TaskItem {
  const factory _TaskItem({
    required final String title,
    required final String dueDate,
    final List<String> assigneeAvatars,
  }) = _$TaskItemImpl;

  @override
  String get title;
  @override
  String get dueDate;
  @override
  List<String> get assigneeAvatars;

  /// Create a copy of TaskItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskItemImplCopyWith<_$TaskItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AnalyticsData {
  int get totalTasksCompleted => throw _privateConstructorUsedError;
  double get todoPercent => throw _privateConstructorUsedError;
  double get inProgressPercent => throw _privateConstructorUsedError;
  double get completedPercent => throw _privateConstructorUsedError;
  List<WeeklyDataPoint> get weeklyProgress =>
      throw _privateConstructorUsedError;
  List<TaskItem> get tasks => throw _privateConstructorUsedError;
  List<RecentActivity> get recentActivities =>
      throw _privateConstructorUsedError;
  double get syllabusProgress => throw _privateConstructorUsedError;
  double get accuracy => throw _privateConstructorUsedError;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalyticsDataCopyWith<AnalyticsData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalyticsDataCopyWith<$Res> {
  factory $AnalyticsDataCopyWith(
    AnalyticsData value,
    $Res Function(AnalyticsData) then,
  ) = _$AnalyticsDataCopyWithImpl<$Res, AnalyticsData>;
  @useResult
  $Res call({
    int totalTasksCompleted,
    double todoPercent,
    double inProgressPercent,
    double completedPercent,
    List<WeeklyDataPoint> weeklyProgress,
    List<TaskItem> tasks,
    List<RecentActivity> recentActivities,
    double syllabusProgress,
    double accuracy,
  });
}

/// @nodoc
class _$AnalyticsDataCopyWithImpl<$Res, $Val extends AnalyticsData>
    implements $AnalyticsDataCopyWith<$Res> {
  _$AnalyticsDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalTasksCompleted = null,
    Object? todoPercent = null,
    Object? inProgressPercent = null,
    Object? completedPercent = null,
    Object? weeklyProgress = null,
    Object? tasks = null,
    Object? recentActivities = null,
    Object? syllabusProgress = null,
    Object? accuracy = null,
  }) {
    return _then(
      _value.copyWith(
            totalTasksCompleted: null == totalTasksCompleted
                ? _value.totalTasksCompleted
                : totalTasksCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            todoPercent: null == todoPercent
                ? _value.todoPercent
                : todoPercent // ignore: cast_nullable_to_non_nullable
                      as double,
            inProgressPercent: null == inProgressPercent
                ? _value.inProgressPercent
                : inProgressPercent // ignore: cast_nullable_to_non_nullable
                      as double,
            completedPercent: null == completedPercent
                ? _value.completedPercent
                : completedPercent // ignore: cast_nullable_to_non_nullable
                      as double,
            weeklyProgress: null == weeklyProgress
                ? _value.weeklyProgress
                : weeklyProgress // ignore: cast_nullable_to_non_nullable
                      as List<WeeklyDataPoint>,
            tasks: null == tasks
                ? _value.tasks
                : tasks // ignore: cast_nullable_to_non_nullable
                      as List<TaskItem>,
            recentActivities: null == recentActivities
                ? _value.recentActivities
                : recentActivities // ignore: cast_nullable_to_non_nullable
                      as List<RecentActivity>,
            syllabusProgress: null == syllabusProgress
                ? _value.syllabusProgress
                : syllabusProgress // ignore: cast_nullable_to_non_nullable
                      as double,
            accuracy: null == accuracy
                ? _value.accuracy
                : accuracy // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnalyticsDataImplCopyWith<$Res>
    implements $AnalyticsDataCopyWith<$Res> {
  factory _$$AnalyticsDataImplCopyWith(
    _$AnalyticsDataImpl value,
    $Res Function(_$AnalyticsDataImpl) then,
  ) = __$$AnalyticsDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int totalTasksCompleted,
    double todoPercent,
    double inProgressPercent,
    double completedPercent,
    List<WeeklyDataPoint> weeklyProgress,
    List<TaskItem> tasks,
    List<RecentActivity> recentActivities,
    double syllabusProgress,
    double accuracy,
  });
}

/// @nodoc
class __$$AnalyticsDataImplCopyWithImpl<$Res>
    extends _$AnalyticsDataCopyWithImpl<$Res, _$AnalyticsDataImpl>
    implements _$$AnalyticsDataImplCopyWith<$Res> {
  __$$AnalyticsDataImplCopyWithImpl(
    _$AnalyticsDataImpl _value,
    $Res Function(_$AnalyticsDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalTasksCompleted = null,
    Object? todoPercent = null,
    Object? inProgressPercent = null,
    Object? completedPercent = null,
    Object? weeklyProgress = null,
    Object? tasks = null,
    Object? recentActivities = null,
    Object? syllabusProgress = null,
    Object? accuracy = null,
  }) {
    return _then(
      _$AnalyticsDataImpl(
        totalTasksCompleted: null == totalTasksCompleted
            ? _value.totalTasksCompleted
            : totalTasksCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        todoPercent: null == todoPercent
            ? _value.todoPercent
            : todoPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        inProgressPercent: null == inProgressPercent
            ? _value.inProgressPercent
            : inProgressPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        completedPercent: null == completedPercent
            ? _value.completedPercent
            : completedPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        weeklyProgress: null == weeklyProgress
            ? _value._weeklyProgress
            : weeklyProgress // ignore: cast_nullable_to_non_nullable
                  as List<WeeklyDataPoint>,
        tasks: null == tasks
            ? _value._tasks
            : tasks // ignore: cast_nullable_to_non_nullable
                  as List<TaskItem>,
        recentActivities: null == recentActivities
            ? _value._recentActivities
            : recentActivities // ignore: cast_nullable_to_non_nullable
                  as List<RecentActivity>,
        syllabusProgress: null == syllabusProgress
            ? _value.syllabusProgress
            : syllabusProgress // ignore: cast_nullable_to_non_nullable
                  as double,
        accuracy: null == accuracy
            ? _value.accuracy
            : accuracy // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$AnalyticsDataImpl implements _AnalyticsData {
  const _$AnalyticsDataImpl({
    required this.totalTasksCompleted,
    required this.todoPercent,
    required this.inProgressPercent,
    required this.completedPercent,
    required final List<WeeklyDataPoint> weeklyProgress,
    required final List<TaskItem> tasks,
    required final List<RecentActivity> recentActivities,
    this.syllabusProgress = 0.0,
    this.accuracy = 0.0,
  }) : _weeklyProgress = weeklyProgress,
       _tasks = tasks,
       _recentActivities = recentActivities;

  @override
  final int totalTasksCompleted;
  @override
  final double todoPercent;
  @override
  final double inProgressPercent;
  @override
  final double completedPercent;
  final List<WeeklyDataPoint> _weeklyProgress;
  @override
  List<WeeklyDataPoint> get weeklyProgress {
    if (_weeklyProgress is EqualUnmodifiableListView) return _weeklyProgress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weeklyProgress);
  }

  final List<TaskItem> _tasks;
  @override
  List<TaskItem> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  final List<RecentActivity> _recentActivities;
  @override
  List<RecentActivity> get recentActivities {
    if (_recentActivities is EqualUnmodifiableListView)
      return _recentActivities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentActivities);
  }

  @override
  @JsonKey()
  final double syllabusProgress;
  @override
  @JsonKey()
  final double accuracy;

  @override
  String toString() {
    return 'AnalyticsData(totalTasksCompleted: $totalTasksCompleted, todoPercent: $todoPercent, inProgressPercent: $inProgressPercent, completedPercent: $completedPercent, weeklyProgress: $weeklyProgress, tasks: $tasks, recentActivities: $recentActivities, syllabusProgress: $syllabusProgress, accuracy: $accuracy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalyticsDataImpl &&
            (identical(other.totalTasksCompleted, totalTasksCompleted) ||
                other.totalTasksCompleted == totalTasksCompleted) &&
            (identical(other.todoPercent, todoPercent) ||
                other.todoPercent == todoPercent) &&
            (identical(other.inProgressPercent, inProgressPercent) ||
                other.inProgressPercent == inProgressPercent) &&
            (identical(other.completedPercent, completedPercent) ||
                other.completedPercent == completedPercent) &&
            const DeepCollectionEquality().equals(
              other._weeklyProgress,
              _weeklyProgress,
            ) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            const DeepCollectionEquality().equals(
              other._recentActivities,
              _recentActivities,
            ) &&
            (identical(other.syllabusProgress, syllabusProgress) ||
                other.syllabusProgress == syllabusProgress) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalTasksCompleted,
    todoPercent,
    inProgressPercent,
    completedPercent,
    const DeepCollectionEquality().hash(_weeklyProgress),
    const DeepCollectionEquality().hash(_tasks),
    const DeepCollectionEquality().hash(_recentActivities),
    syllabusProgress,
    accuracy,
  );

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      __$$AnalyticsDataImplCopyWithImpl<_$AnalyticsDataImpl>(this, _$identity);
}

abstract class _AnalyticsData implements AnalyticsData {
  const factory _AnalyticsData({
    required final int totalTasksCompleted,
    required final double todoPercent,
    required final double inProgressPercent,
    required final double completedPercent,
    required final List<WeeklyDataPoint> weeklyProgress,
    required final List<TaskItem> tasks,
    required final List<RecentActivity> recentActivities,
    final double syllabusProgress,
    final double accuracy,
  }) = _$AnalyticsDataImpl;

  @override
  int get totalTasksCompleted;
  @override
  double get todoPercent;
  @override
  double get inProgressPercent;
  @override
  double get completedPercent;
  @override
  List<WeeklyDataPoint> get weeklyProgress;
  @override
  List<TaskItem> get tasks;
  @override
  List<RecentActivity> get recentActivities;
  @override
  double get syllabusProgress;
  @override
  double get accuracy;

  /// Create a copy of AnalyticsData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
