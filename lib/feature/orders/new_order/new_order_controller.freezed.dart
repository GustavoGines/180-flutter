// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_order_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NewOrderState {
  Order? get originalOrder; // Si es no nulo, estamos en modo edición
  Client? get selectedClient;
  int? get selectedAddressId;
  bool get isPaid;
  DateTime? get eventDate;
  TimeOfDay? get startTime;
  TimeOfDay? get endTime;
  double get deposit;
  double get deliveryCost;
  String get notes;
  List<OrderItem> get items;
  Map<String, XFile> get filesToUpload;
  bool get isLoading;
  String? get error;

  /// Create a copy of NewOrderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NewOrderStateCopyWith<NewOrderState> get copyWith =>
      _$NewOrderStateCopyWithImpl<NewOrderState>(
          this as NewOrderState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NewOrderState &&
            (identical(other.originalOrder, originalOrder) ||
                other.originalOrder == originalOrder) &&
            (identical(other.selectedClient, selectedClient) ||
                other.selectedClient == selectedClient) &&
            (identical(other.selectedAddressId, selectedAddressId) ||
                other.selectedAddressId == selectedAddressId) &&
            (identical(other.isPaid, isPaid) || other.isPaid == isPaid) &&
            (identical(other.eventDate, eventDate) ||
                other.eventDate == eventDate) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.deposit, deposit) || other.deposit == deposit) &&
            (identical(other.deliveryCost, deliveryCost) ||
                other.deliveryCost == deliveryCost) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            const DeepCollectionEquality()
                .equals(other.filesToUpload, filesToUpload) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      originalOrder,
      selectedClient,
      selectedAddressId,
      isPaid,
      eventDate,
      startTime,
      endTime,
      deposit,
      deliveryCost,
      notes,
      const DeepCollectionEquality().hash(items),
      const DeepCollectionEquality().hash(filesToUpload),
      isLoading,
      error);

  @override
  String toString() {
    return 'NewOrderState(originalOrder: $originalOrder, selectedClient: $selectedClient, selectedAddressId: $selectedAddressId, isPaid: $isPaid, eventDate: $eventDate, startTime: $startTime, endTime: $endTime, deposit: $deposit, deliveryCost: $deliveryCost, notes: $notes, items: $items, filesToUpload: $filesToUpload, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class $NewOrderStateCopyWith<$Res> {
  factory $NewOrderStateCopyWith(
          NewOrderState value, $Res Function(NewOrderState) _then) =
      _$NewOrderStateCopyWithImpl;
  @useResult
  $Res call(
      {Order? originalOrder,
      Client? selectedClient,
      int? selectedAddressId,
      bool isPaid,
      DateTime? eventDate,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      double deposit,
      double deliveryCost,
      String notes,
      List<OrderItem> items,
      Map<String, XFile> filesToUpload,
      bool isLoading,
      String? error});
}

/// @nodoc
class _$NewOrderStateCopyWithImpl<$Res>
    implements $NewOrderStateCopyWith<$Res> {
  _$NewOrderStateCopyWithImpl(this._self, this._then);

  final NewOrderState _self;
  final $Res Function(NewOrderState) _then;

  /// Create a copy of NewOrderState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? originalOrder = freezed,
    Object? selectedClient = freezed,
    Object? selectedAddressId = freezed,
    Object? isPaid = null,
    Object? eventDate = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? deposit = null,
    Object? deliveryCost = null,
    Object? notes = null,
    Object? items = null,
    Object? filesToUpload = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      originalOrder: freezed == originalOrder
          ? _self.originalOrder
          : originalOrder // ignore: cast_nullable_to_non_nullable
              as Order?,
      selectedClient: freezed == selectedClient
          ? _self.selectedClient
          : selectedClient // ignore: cast_nullable_to_non_nullable
              as Client?,
      selectedAddressId: freezed == selectedAddressId
          ? _self.selectedAddressId
          : selectedAddressId // ignore: cast_nullable_to_non_nullable
              as int?,
      isPaid: null == isPaid
          ? _self.isPaid
          : isPaid // ignore: cast_nullable_to_non_nullable
              as bool,
      eventDate: freezed == eventDate
          ? _self.eventDate
          : eventDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      startTime: freezed == startTime
          ? _self.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as TimeOfDay?,
      endTime: freezed == endTime
          ? _self.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as TimeOfDay?,
      deposit: null == deposit
          ? _self.deposit
          : deposit // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryCost: null == deliveryCost
          ? _self.deliveryCost
          : deliveryCost // ignore: cast_nullable_to_non_nullable
              as double,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<OrderItem>,
      filesToUpload: null == filesToUpload
          ? _self.filesToUpload
          : filesToUpload // ignore: cast_nullable_to_non_nullable
              as Map<String, XFile>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [NewOrderState].
extension NewOrderStatePatterns on NewOrderState {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_NewOrderState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NewOrderState() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_NewOrderState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewOrderState():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_NewOrderState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewOrderState() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            Order? originalOrder,
            Client? selectedClient,
            int? selectedAddressId,
            bool isPaid,
            DateTime? eventDate,
            TimeOfDay? startTime,
            TimeOfDay? endTime,
            double deposit,
            double deliveryCost,
            String notes,
            List<OrderItem> items,
            Map<String, XFile> filesToUpload,
            bool isLoading,
            String? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NewOrderState() when $default != null:
        return $default(
            _that.originalOrder,
            _that.selectedClient,
            _that.selectedAddressId,
            _that.isPaid,
            _that.eventDate,
            _that.startTime,
            _that.endTime,
            _that.deposit,
            _that.deliveryCost,
            _that.notes,
            _that.items,
            _that.filesToUpload,
            _that.isLoading,
            _that.error);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            Order? originalOrder,
            Client? selectedClient,
            int? selectedAddressId,
            bool isPaid,
            DateTime? eventDate,
            TimeOfDay? startTime,
            TimeOfDay? endTime,
            double deposit,
            double deliveryCost,
            String notes,
            List<OrderItem> items,
            Map<String, XFile> filesToUpload,
            bool isLoading,
            String? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewOrderState():
        return $default(
            _that.originalOrder,
            _that.selectedClient,
            _that.selectedAddressId,
            _that.isPaid,
            _that.eventDate,
            _that.startTime,
            _that.endTime,
            _that.deposit,
            _that.deliveryCost,
            _that.notes,
            _that.items,
            _that.filesToUpload,
            _that.isLoading,
            _that.error);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            Order? originalOrder,
            Client? selectedClient,
            int? selectedAddressId,
            bool isPaid,
            DateTime? eventDate,
            TimeOfDay? startTime,
            TimeOfDay? endTime,
            double deposit,
            double deliveryCost,
            String notes,
            List<OrderItem> items,
            Map<String, XFile> filesToUpload,
            bool isLoading,
            String? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NewOrderState() when $default != null:
        return $default(
            _that.originalOrder,
            _that.selectedClient,
            _that.selectedAddressId,
            _that.isPaid,
            _that.eventDate,
            _that.startTime,
            _that.endTime,
            _that.deposit,
            _that.deliveryCost,
            _that.notes,
            _that.items,
            _that.filesToUpload,
            _that.isLoading,
            _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _NewOrderState extends NewOrderState {
  const _NewOrderState(
      {this.originalOrder,
      this.selectedClient,
      this.selectedAddressId,
      this.isPaid = false,
      this.eventDate,
      this.startTime,
      this.endTime,
      this.deposit = 0.0,
      this.deliveryCost = 0.0,
      this.notes = '',
      final List<OrderItem> items = const [],
      final Map<String, XFile> filesToUpload = const {},
      this.isLoading = false,
      this.error})
      : _items = items,
        _filesToUpload = filesToUpload,
        super._();

  @override
  final Order? originalOrder;
// Si es no nulo, estamos en modo edición
  @override
  final Client? selectedClient;
  @override
  final int? selectedAddressId;
  @override
  @JsonKey()
  final bool isPaid;
  @override
  final DateTime? eventDate;
  @override
  final TimeOfDay? startTime;
  @override
  final TimeOfDay? endTime;
  @override
  @JsonKey()
  final double deposit;
  @override
  @JsonKey()
  final double deliveryCost;
  @override
  @JsonKey()
  final String notes;
  final List<OrderItem> _items;
  @override
  @JsonKey()
  List<OrderItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  final Map<String, XFile> _filesToUpload;
  @override
  @JsonKey()
  Map<String, XFile> get filesToUpload {
    if (_filesToUpload is EqualUnmodifiableMapView) return _filesToUpload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_filesToUpload);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  /// Create a copy of NewOrderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NewOrderStateCopyWith<_NewOrderState> get copyWith =>
      __$NewOrderStateCopyWithImpl<_NewOrderState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NewOrderState &&
            (identical(other.originalOrder, originalOrder) ||
                other.originalOrder == originalOrder) &&
            (identical(other.selectedClient, selectedClient) ||
                other.selectedClient == selectedClient) &&
            (identical(other.selectedAddressId, selectedAddressId) ||
                other.selectedAddressId == selectedAddressId) &&
            (identical(other.isPaid, isPaid) || other.isPaid == isPaid) &&
            (identical(other.eventDate, eventDate) ||
                other.eventDate == eventDate) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.deposit, deposit) || other.deposit == deposit) &&
            (identical(other.deliveryCost, deliveryCost) ||
                other.deliveryCost == deliveryCost) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            const DeepCollectionEquality()
                .equals(other._filesToUpload, _filesToUpload) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      originalOrder,
      selectedClient,
      selectedAddressId,
      isPaid,
      eventDate,
      startTime,
      endTime,
      deposit,
      deliveryCost,
      notes,
      const DeepCollectionEquality().hash(_items),
      const DeepCollectionEquality().hash(_filesToUpload),
      isLoading,
      error);

  @override
  String toString() {
    return 'NewOrderState(originalOrder: $originalOrder, selectedClient: $selectedClient, selectedAddressId: $selectedAddressId, isPaid: $isPaid, eventDate: $eventDate, startTime: $startTime, endTime: $endTime, deposit: $deposit, deliveryCost: $deliveryCost, notes: $notes, items: $items, filesToUpload: $filesToUpload, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$NewOrderStateCopyWith<$Res>
    implements $NewOrderStateCopyWith<$Res> {
  factory _$NewOrderStateCopyWith(
          _NewOrderState value, $Res Function(_NewOrderState) _then) =
      __$NewOrderStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {Order? originalOrder,
      Client? selectedClient,
      int? selectedAddressId,
      bool isPaid,
      DateTime? eventDate,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      double deposit,
      double deliveryCost,
      String notes,
      List<OrderItem> items,
      Map<String, XFile> filesToUpload,
      bool isLoading,
      String? error});
}

/// @nodoc
class __$NewOrderStateCopyWithImpl<$Res>
    implements _$NewOrderStateCopyWith<$Res> {
  __$NewOrderStateCopyWithImpl(this._self, this._then);

  final _NewOrderState _self;
  final $Res Function(_NewOrderState) _then;

  /// Create a copy of NewOrderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? originalOrder = freezed,
    Object? selectedClient = freezed,
    Object? selectedAddressId = freezed,
    Object? isPaid = null,
    Object? eventDate = freezed,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? deposit = null,
    Object? deliveryCost = null,
    Object? notes = null,
    Object? items = null,
    Object? filesToUpload = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_NewOrderState(
      originalOrder: freezed == originalOrder
          ? _self.originalOrder
          : originalOrder // ignore: cast_nullable_to_non_nullable
              as Order?,
      selectedClient: freezed == selectedClient
          ? _self.selectedClient
          : selectedClient // ignore: cast_nullable_to_non_nullable
              as Client?,
      selectedAddressId: freezed == selectedAddressId
          ? _self.selectedAddressId
          : selectedAddressId // ignore: cast_nullable_to_non_nullable
              as int?,
      isPaid: null == isPaid
          ? _self.isPaid
          : isPaid // ignore: cast_nullable_to_non_nullable
              as bool,
      eventDate: freezed == eventDate
          ? _self.eventDate
          : eventDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      startTime: freezed == startTime
          ? _self.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as TimeOfDay?,
      endTime: freezed == endTime
          ? _self.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as TimeOfDay?,
      deposit: null == deposit
          ? _self.deposit
          : deposit // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryCost: null == deliveryCost
          ? _self.deliveryCost
          : deliveryCost // ignore: cast_nullable_to_non_nullable
              as double,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<OrderItem>,
      filesToUpload: null == filesToUpload
          ? _self._filesToUpload
          : filesToUpload // ignore: cast_nullable_to_non_nullable
              as Map<String, XFile>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
