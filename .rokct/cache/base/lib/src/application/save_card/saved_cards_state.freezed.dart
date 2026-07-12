// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_cards_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SavedCardsState {
  List<SavedCardModel> get cards => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of SavedCardsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SavedCardsStateCopyWith<SavedCardsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SavedCardsStateCopyWith<$Res> {
  factory $SavedCardsStateCopyWith(
    SavedCardsState value,
    $Res Function(SavedCardsState) then,
  ) = _$SavedCardsStateCopyWithImpl<$Res, SavedCardsState>;
  @useResult
  $Res call({List<SavedCardModel> cards, bool isLoading, String? error});
}

/// @nodoc
class _$SavedCardsStateCopyWithImpl<$Res, $Val extends SavedCardsState>
    implements $SavedCardsStateCopyWith<$Res> {
  _$SavedCardsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SavedCardsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cards = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            cards: null == cards
                ? _value.cards
                : cards // ignore: cast_nullable_to_non_nullable
                      as List<SavedCardModel>,
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SavedCardsStateImplCopyWith<$Res>
    implements $SavedCardsStateCopyWith<$Res> {
  factory _$$SavedCardsStateImplCopyWith(
    _$SavedCardsStateImpl value,
    $Res Function(_$SavedCardsStateImpl) then,
  ) = __$$SavedCardsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<SavedCardModel> cards, bool isLoading, String? error});
}

/// @nodoc
class __$$SavedCardsStateImplCopyWithImpl<$Res>
    extends _$SavedCardsStateCopyWithImpl<$Res, _$SavedCardsStateImpl>
    implements _$$SavedCardsStateImplCopyWith<$Res> {
  __$$SavedCardsStateImplCopyWithImpl(
    _$SavedCardsStateImpl _value,
    $Res Function(_$SavedCardsStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SavedCardsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cards = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$SavedCardsStateImpl(
        cards: null == cards
            ? _value._cards
            : cards // ignore: cast_nullable_to_non_nullable
                  as List<SavedCardModel>,
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$SavedCardsStateImpl extends _SavedCardsState {
  const _$SavedCardsStateImpl({
    final List<SavedCardModel> cards = const [],
    this.isLoading = false,
    this.error,
  }) : _cards = cards,
       super._();

  final List<SavedCardModel> _cards;
  @override
  @JsonKey()
  List<SavedCardModel> get cards {
    if (_cards is EqualUnmodifiableListView) return _cards;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_cards);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString() {
    return 'SavedCardsState(cards: $cards, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SavedCardsStateImpl &&
            const DeepCollectionEquality().equals(other._cards, _cards) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_cards),
    isLoading,
    error,
  );

  /// Create a copy of SavedCardsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SavedCardsStateImplCopyWith<_$SavedCardsStateImpl> get copyWith =>
      __$$SavedCardsStateImplCopyWithImpl<_$SavedCardsStateImpl>(
        this,
        _$identity,
      );
}

abstract class _SavedCardsState extends SavedCardsState {
  const factory _SavedCardsState({
    final List<SavedCardModel> cards,
    final bool isLoading,
    final String? error,
  }) = _$SavedCardsStateImpl;
  const _SavedCardsState._() : super._();

  @override
  List<SavedCardModel> get cards;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of SavedCardsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SavedCardsStateImplCopyWith<_$SavedCardsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
