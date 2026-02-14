import 'package:equatable/equatable.dart';

/// A user-defined key:value field attached to a dive log entry.
class DiveCustomField extends Equatable {
  final String id;
  final String key;
  final String value;
  final int sortOrder;

  const DiveCustomField({
    required this.id,
    required this.key,
    this.value = '',
    this.sortOrder = 0,
  });

  DiveCustomField copyWith({
    String? id,
    String? key,
    String? value,
    int? sortOrder,
  }) {
    return DiveCustomField(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [id, key, value, sortOrder];
}
