// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery_points_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DeliveryPointsState {
  bool get isLoading => throw _privateConstructorUsedError;
  List<DeliveryPointData> get deliveryPoints =>
      throw _privateConstructorUsedError;

  /// Create a copy of DeliveryPointsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeliveryPointsStateCopyWith<DeliveryPointsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeliveryPointsStateCopyWith<$Res> {
  factory $DeliveryPointsStateCopyWith(
    DeliveryPointsState value,
    $Res Function(DeliveryPointsState) then,
  ) = _$DeliveryPointsStateCopyWithImpl<$Res, DeliveryPointsState>;
  @useResult
  $Res call({bool isLoading, List<DeliveryPointData> deliveryPoints});
}

/// @nodoc
class _$DeliveryPointsStateCopyWithImpl<$Res, $Val extends DeliveryPointsState>
    implements $DeliveryPointsStateCopyWith<$Res> {
  _$DeliveryPointsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeliveryPointsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isLoading = null, Object? deliveryPoints = null}) {
    return _then(
      _value.copyWith(
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            deliveryPoints: null == deliveryPoints
                ? _value.deliveryPoints
                : deliveryPoints // ignore: cast_nullable_to_non_nullable
                      as List<DeliveryPointData>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeliveryPointsStateImplCopyWith<$Res>
    implements $DeliveryPointsStateCopyWith<$Res> {
  factory _$$DeliveryPointsStateImplCopyWith(
    _$DeliveryPointsStateImpl value,
    $Res Function(_$DeliveryPointsStateImpl) then,
  ) = __$$DeliveryPointsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isLoading, List<DeliveryPointData> deliveryPoints});
}

/// @nodoc
class __$$DeliveryPointsStateImplCopyWithImpl<$Res>
    extends _$DeliveryPointsStateCopyWithImpl<$Res, _$DeliveryPointsStateImpl>
    implements _$$DeliveryPointsStateImplCopyWith<$Res> {
  __$$DeliveryPointsStateImplCopyWithImpl(
    _$DeliveryPointsStateImpl _value,
    $Res Function(_$DeliveryPointsStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeliveryPointsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isLoading = null, Object? deliveryPoints = null}) {
    return _then(
      _$DeliveryPointsStateImpl(
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        deliveryPoints: null == deliveryPoints
            ? _value._deliveryPoints
            : deliveryPoints // ignore: cast_nullable_to_non_nullable
                  as List<DeliveryPointData>,
      ),
    );
  }
}

/// @nodoc

class _$DeliveryPointsStateImpl extends _DeliveryPointsState {
  const _$DeliveryPointsStateImpl({
    this.isLoading = false,
    final List<DeliveryPointData> deliveryPoints = const [],
  }) : _deliveryPoints = deliveryPoints,
       super._();

  @override
  @JsonKey()
  final bool isLoading;
  final List<DeliveryPointData> _deliveryPoints;
  @override
  @JsonKey()
  List<DeliveryPointData> get deliveryPoints {
    if (_deliveryPoints is EqualUnmodifiableListView) return _deliveryPoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_deliveryPoints);
  }

  @override
  String toString() {
    return 'DeliveryPointsState(isLoading: $isLoading, deliveryPoints: $deliveryPoints)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeliveryPointsStateImpl &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            const DeepCollectionEquality().equals(
              other._deliveryPoints,
              _deliveryPoints,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    isLoading,
    const DeepCollectionEquality().hash(_deliveryPoints),
  );

  /// Create a copy of DeliveryPointsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeliveryPointsStateImplCopyWith<_$DeliveryPointsStateImpl> get copyWith =>
      __$$DeliveryPointsStateImplCopyWithImpl<_$DeliveryPointsStateImpl>(
        this,
        _$identity,
      );
}

abstract class _DeliveryPointsState extends DeliveryPointsState {
  const factory _DeliveryPointsState({
    final bool isLoading,
    final List<DeliveryPointData> deliveryPoints,
  }) = _$DeliveryPointsStateImpl;
  const _DeliveryPointsState._() : super._();

  @override
  bool get isLoading;
  @override
  List<DeliveryPointData> get deliveryPoints;

  /// Create a copy of DeliveryPointsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeliveryPointsStateImplCopyWith<_$DeliveryPointsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
