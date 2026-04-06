import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';

/// Configuration for a single column in the table view.
class TableColumnConfig extends Equatable {
  final DiveField field;
  final double width;
  final bool isPinned;

  TableColumnConfig({required this.field, double? width, this.isPinned = false})
    : width = width ?? field.defaultWidth;

  TableColumnConfig copyWith({
    DiveField? field,
    double? width,
    bool? isPinned,
  }) {
    return TableColumnConfig(
      field: field ?? this.field,
      width: width ?? this.width,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return {'field': field.name, 'width': width, 'isPinned': isPinned};
  }

  factory TableColumnConfig.fromJson(Map<String, dynamic> json) {
    return TableColumnConfig(
      field: DiveField.values.firstWhere(
        (e) => e.name == json['field'] as String,
        orElse: () => DiveField.diveNumber,
      ),
      width: (json['width'] as num).toDouble(),
      isPinned: json['isPinned'] as bool,
    );
  }

  @override
  List<Object?> get props => [field, width, isPinned];
}

/// Configuration for the table view, including column order, widths, and sort.
class TableViewConfig extends Equatable {
  final List<TableColumnConfig> columns;
  final DiveField? sortField;
  final bool sortAscending;

  const TableViewConfig({
    required this.columns,
    this.sortField,
    this.sortAscending = true,
  });

  /// Default table configuration with 6 standard columns.
  factory TableViewConfig.defaultConfig() {
    return TableViewConfig(
      columns: [
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: DiveField.siteName, isPinned: true),
        TableColumnConfig(field: DiveField.dateTime),
        TableColumnConfig(field: DiveField.maxDepth),
        TableColumnConfig(field: DiveField.bottomTime),
        TableColumnConfig(field: DiveField.waterTemp),
      ],
    );
  }

  TableViewConfig copyWith({
    List<TableColumnConfig>? columns,
    DiveField? sortField,
    bool? sortAscending,
    bool clearSortField = false,
  }) {
    return TableViewConfig(
      columns: columns ?? this.columns,
      sortField: clearSortField ? null : (sortField ?? this.sortField),
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'columns': columns.map((c) => c.toJson()).toList(),
      'sortField': sortField?.name,
      'sortAscending': sortAscending,
    };
  }

  factory TableViewConfig.fromJson(Map<String, dynamic> json) {
    final sortFieldName = json['sortField'] as String?;
    DiveField? sortField;
    if (sortFieldName != null) {
      sortField = DiveField.values
          .where((e) => e.name == sortFieldName)
          .firstOrNull;
    }
    return TableViewConfig(
      columns: (json['columns'] as List<dynamic>)
          .map((c) => TableColumnConfig.fromJson(c as Map<String, dynamic>))
          .toList(),
      sortField: sortField,
      sortAscending: json['sortAscending'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [columns, sortField, sortAscending];
}

/// Configuration for a single named slot in a card view.
class CardSlotConfig extends Equatable {
  final String slotId;
  final DiveField field;

  const CardSlotConfig({required this.slotId, required this.field});

  CardSlotConfig copyWith({String? slotId, DiveField? field}) {
    return CardSlotConfig(
      slotId: slotId ?? this.slotId,
      field: field ?? this.field,
    );
  }

  Map<String, dynamic> toJson() {
    return {'slotId': slotId, 'field': field.name};
  }

  factory CardSlotConfig.fromJson(Map<String, dynamic> json) {
    return CardSlotConfig(
      slotId: json['slotId'] as String,
      field: DiveField.values.firstWhere(
        (e) => e.name == json['field'] as String,
        orElse: () => DiveField.diveNumber,
      ),
    );
  }

  @override
  List<Object?> get props => [slotId, field];
}

/// Configuration for a card-based list view (compact, dense, or detailed).
class CardViewConfig extends Equatable {
  final ListViewMode mode;
  final List<CardSlotConfig> slots;
  final List<DiveField> extraFields;

  const CardViewConfig({
    required this.mode,
    required this.slots,
    this.extraFields = const [],
  });

  /// Default configuration for the compact card view with 4 named slots.
  factory CardViewConfig.defaultCompact() {
    return const CardViewConfig(
      mode: ListViewMode.compact,
      slots: [
        CardSlotConfig(slotId: 'title', field: DiveField.siteName),
        CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
        CardSlotConfig(slotId: 'stat1', field: DiveField.maxDepth),
        CardSlotConfig(slotId: 'stat2', field: DiveField.bottomTime),
      ],
    );
  }

  /// Default configuration for the dense card view with 4 named slots.
  factory CardViewConfig.defaultDense() {
    return const CardViewConfig(
      mode: ListViewMode.dense,
      slots: [
        CardSlotConfig(slotId: 'slot1', field: DiveField.siteName),
        CardSlotConfig(slotId: 'slot2', field: DiveField.dateTime),
        CardSlotConfig(slotId: 'slot3', field: DiveField.maxDepth),
        CardSlotConfig(slotId: 'slot4', field: DiveField.bottomTime),
      ],
    );
  }

  /// Default configuration for the detailed card view with no extra fields.
  factory CardViewConfig.defaultDetailed() {
    return const CardViewConfig(
      mode: ListViewMode.detailed,
      slots: [
        CardSlotConfig(slotId: 'title', field: DiveField.siteName),
        CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
        CardSlotConfig(slotId: 'stat1', field: DiveField.maxDepth),
        CardSlotConfig(slotId: 'stat2', field: DiveField.bottomTime),
      ],
      extraFields: [],
    );
  }

  CardViewConfig copyWith({
    ListViewMode? mode,
    List<CardSlotConfig>? slots,
    List<DiveField>? extraFields,
  }) {
    return CardViewConfig(
      mode: mode ?? this.mode,
      slots: slots ?? this.slots,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'slots': slots.map((s) => s.toJson()).toList(),
      'extraFields': extraFields.map((f) => f.name).toList(),
    };
  }

  factory CardViewConfig.fromJson(Map<String, dynamic> json) {
    return CardViewConfig(
      mode: ListViewMode.fromName(json['mode'] as String),
      slots: (json['slots'] as List<dynamic>)
          .map((s) => CardSlotConfig.fromJson(s as Map<String, dynamic>))
          .toList(),
      extraFields:
          (json['extraFields'] as List<dynamic>?)
              ?.map(
                (f) => DiveField.values
                    .where((e) => e.name == f as String)
                    .firstOrNull,
              )
              .whereType<DiveField>()
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [mode, slots, extraFields];
}

/// A named preset for field configuration, either built-in or user-created.
class FieldPreset extends Equatable {
  final String id;
  final String name;
  final ListViewMode viewMode;
  final Map<String, dynamic> configJson;
  final bool isBuiltIn;

  const FieldPreset({
    required this.id,
    required this.name,
    required this.viewMode,
    required this.configJson,
    this.isBuiltIn = false,
  });

  /// Returns the three built-in table presets: Standard, Technical, Planning.
  static List<FieldPreset> builtInTablePresets() {
    final standard = TableViewConfig(
      columns: [
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: DiveField.siteName, isPinned: true),
        TableColumnConfig(field: DiveField.dateTime),
        TableColumnConfig(field: DiveField.maxDepth),
        TableColumnConfig(field: DiveField.bottomTime),
        TableColumnConfig(field: DiveField.waterTemp),
      ],
    );

    final technical = TableViewConfig(
      columns: [
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: DiveField.dateTime),
        TableColumnConfig(field: DiveField.maxDepth),
        TableColumnConfig(field: DiveField.avgDepth),
        TableColumnConfig(field: DiveField.bottomTime),
        TableColumnConfig(field: DiveField.primaryGas),
        TableColumnConfig(field: DiveField.startPressure),
        TableColumnConfig(field: DiveField.endPressure),
        TableColumnConfig(field: DiveField.sacRate),
      ],
    );

    final planning = TableViewConfig(
      columns: [
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: DiveField.siteName, isPinned: true),
        TableColumnConfig(field: DiveField.dateTime),
        TableColumnConfig(field: DiveField.maxDepth),
        TableColumnConfig(field: DiveField.bottomTime),
        TableColumnConfig(field: DiveField.buddy),
        TableColumnConfig(field: DiveField.notes),
      ],
    );

    return [
      FieldPreset(
        id: 'builtin_standard',
        name: 'Standard',
        viewMode: ListViewMode.table,
        configJson: standard.toJson(),
        isBuiltIn: true,
      ),
      FieldPreset(
        id: 'builtin_technical',
        name: 'Technical',
        viewMode: ListViewMode.table,
        configJson: technical.toJson(),
        isBuiltIn: true,
      ),
      FieldPreset(
        id: 'builtin_planning',
        name: 'Planning',
        viewMode: ListViewMode.table,
        configJson: planning.toJson(),
        isBuiltIn: true,
      ),
    ];
  }

  FieldPreset copyWith({
    String? id,
    String? name,
    ListViewMode? viewMode,
    Map<String, dynamic>? configJson,
    bool? isBuiltIn,
  }) {
    return FieldPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      viewMode: viewMode ?? this.viewMode,
      configJson: configJson ?? this.configJson,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [id, name, viewMode, configJson, isBuiltIn];
}
