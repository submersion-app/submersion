import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

const _relationOps = [
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.inList,
  QueryOp.isEmpty,
  QueryOp.isSet,
];

const _scalarOps = {
  QueryOp.eq,
  QueryOp.neq,
  QueryOp.lt,
  QueryOp.lte,
  QueryOp.gt,
  QueryOp.gte,
  QueryOp.contains,
};

/// The operators a row offers for [target], in [QueryOp] order: the
/// registry's per-type set minus what the builder does not edit (in-list on
/// a number or text, `!=` on a bool), and minus `:none` / `:any` on an enum
/// that stores a value named `none` (the validator refuses them, PR 1
/// deviations).
List<QueryOp> opsFor(PathResolution target) {
  final field = target.field;
  if (field == null) return _relationOps;
  final ops = <QueryOp>[];
  for (final op in QueryOp.values) {
    if (!field.ops.contains(op)) continue;
    if (op == QueryOp.inList &&
        field.type != FieldType.enumName &&
        field.type != FieldType.date) {
      continue;
    }
    if (field.type == FieldType.bool && op == QueryOp.neq) continue;
    if ((op == QueryOp.isEmpty || op == QueryOp.isSet) &&
        (field.enumValues?.contains('none') ?? false)) {
      continue;
    }
    ops.add(op);
  }
  return ops;
}

/// The value a fresh row holds for [op] on [target]; null when [op] takes
/// no value or the row cannot exist without a pick (a ref).
QueryValue? defaultValueFor(
  PathResolution target,
  QueryOp op,
  QueryEditorContext context,
) {
  if (!op.takesValue) return null;
  final field = target.field;
  if (field == null) return null;
  final now = context.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (field.type) {
    case FieldType.number:
      return op == QueryOp.between
          ? ListValue([const NumberValue(0, null), const NumberValue(0, null)])
          : const NumberValue(0, null);
    case FieldType.id:
    case FieldType.text:
      return const StringValue('');
    case FieldType.bool:
      return const BoolValue(true);
    case FieldType.enumName:
      final first = EnumValue(field.enumValues!.first);
      return op == QueryOp.inList ? ListValue([first]) : first;
    case FieldType.date:
      return switch (op) {
        QueryOp.inList => DateRangeValue(DateTime(today.year, 1, 1), today),
        QueryOp.between => ListValue([DateValue(today), DateValue(today)]),
        _ => DateValue(today),
      };
  }
}

/// Scalar comparisons share one value shape; between, in-list and the
/// presence ops each have their own.
bool sameValueShape(QueryOp a, QueryOp b) =>
    _scalarOps.contains(a) && _scalarOps.contains(b);

/// ISO day text, the form the text tab accepts, so both tabs read alike. A
/// query literal, not a displayed date, so the diver's date format does
/// not apply.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The per-type value editor of spec Unit 6: a unit-aware number field, a
/// text field, a yes/no toggle, an enum dropdown or chip set, date buttons,
/// a ref button opening the picker; nothing for `:none` and `:any`.
class QueryValueEditor extends StatelessWidget {
  const QueryValueEditor({
    super.key,
    required this.context,
    required this.target,
    required this.op,
    required this.value,
    required this.onChanged,
    required this.strings,
  });

  final QueryEditorContext context;
  final PathResolution target;
  final QueryOp op;
  final QueryValue? value;
  final ValueChanged<QueryValue> onChanged;
  final QueryBuilderStrings strings;

  @override
  Widget build(BuildContext buildContext) {
    if (!op.takesValue) return const SizedBox.shrink();
    final rel = target.terminalRelation;
    if (rel != null) return _ref(buildContext, rel);
    final field = target.field!;
    switch (field.type) {
      case FieldType.number:
        return op == QueryOp.between
            ? _betweenNumbers(field)
            : _number(field, value as NumberValue?, onChanged);
      case FieldType.id:
      case FieldType.text:
        return _TextValueField(
          initialText: (value as StringValue?)?.value ?? '',
          onChanged: (t) => onChanged(StringValue(t)),
        );
      case FieldType.bool:
        return _bool();
      case FieldType.enumName:
        return op == QueryOp.inList ? _enumChips(field) : _enumDropdown(field);
      case FieldType.date:
        return _date(buildContext);
    }
  }

  Widget _number(
    QueryField field,
    NumberValue? current,
    ValueChanged<QueryValue> onValue, {
    Key? key,
  }) {
    final unit = unitForDimension(field.dimension, context.prefs);
    final shown = current == null
        ? ''
        : formatQueryNumber(
            storageToDisplay(
              current.value,
              unit,
              field.dimension,
              context.prefs,
            ).$1,
          );
    return _NumberField(
      key: key,
      initialText: shown,
      suffix: field.dimension == FieldDimension.percent ? '%' : unit?.suffix,
      onChanged: (text) {
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed == null) return;
        onValue(
          NumberValue(
            groundToStorage(parsed, unit, field.dimension, context.prefs),
            null,
          ),
        );
      },
    );
  }

  Widget _betweenNumbers(QueryField field) {
    final items = (value as ListValue?)?.items ?? const <QueryValue>[];
    final lo = items.isNotEmpty
        ? items[0] as NumberValue
        : const NumberValue(0, null);
    final hi = items.length > 1 ? items[1] as NumberValue : lo;
    return Row(
      children: [
        Expanded(
          child: _number(
            field,
            lo,
            (v) => onChanged(ListValue([v, hi])),
            key: const ValueKey('between-lo'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(strings.betweenAnd),
        ),
        Expanded(
          child: _number(
            field,
            hi,
            (v) => onChanged(ListValue([lo, v])),
            key: const ValueKey('between-hi'),
          ),
        ),
      ],
    );
  }

  Widget _bool() {
    final on = (value as BoolValue?)?.value ?? true;
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: true, label: Text(strings.valueTrue)),
        ButtonSegment(value: false, label: Text(strings.valueFalse)),
      ],
      selected: {on},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(BoolValue(s.single)),
    );
  }

  Widget _enumDropdown(QueryField field) {
    final values = field.enumValues!;
    final current = (value as EnumValue?)?.name ?? values.first;
    return DropdownButton<String>(
      value: values.contains(current) ? current : values.first,
      isExpanded: true,
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text(context.labels.enumValue(field, v)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(EnumValue(v));
      },
    );
  }

  Widget _enumChips(QueryField field) {
    final selected = {
      for (final item in (value as ListValue?)?.items ?? const <QueryValue>[])
        if (item is EnumValue) item.name,
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final v in field.enumValues!)
          FilterChip(
            label: Text(context.labels.enumValue(field, v)),
            selected: selected.contains(v),
            onSelected: (on) {
              final next = [
                for (final e in field.enumValues!)
                  if (e == v ? on : selected.contains(e)) EnumValue(e),
              ];
              if (next.isNotEmpty) onChanged(ListValue(next));
            },
          ),
      ],
    );
  }

  Widget _date(BuildContext buildContext) {
    Future<DateTime?> pick(DateTime initial) => showAppDatePicker(
      context: buildContext,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(context.now().year + 1, 12, 31),
    );
    Widget dayButton(DateTime day, ValueChanged<DateTime> onPicked) =>
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          onPressed: () async {
            final d = await pick(day);
            if (d != null) onPicked(d);
          },
          label: Text(isoDay(day)),
        );
    Widget pair(
      DateTime lo,
      DateTime hi,
      void Function(DateTime lo, DateTime hi) onPicked,
    ) => Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        dayButton(lo, (d) => onPicked(d, hi.isBefore(d) ? d : hi)),
        Text(strings.betweenAnd),
        dayButton(hi, (d) => onPicked(lo.isAfter(d) ? d : lo, d)),
      ],
    );
    switch (value) {
      case DateRangeValue(:final start, :final end):
        return pair(start, end, (a, b) => onChanged(DateRangeValue(a, b)));
      case ListValue(:final items) when items.isNotEmpty:
        final lo = (items[0] as DateValue).day;
        final hi = items.length > 1 ? (items[1] as DateValue).day : lo;
        return pair(
          lo,
          hi,
          (a, b) => onChanged(ListValue([DateValue(a), DateValue(b)])),
        );
      case DateValue(:final day):
        return dayButton(day, (d) => onChanged(DateValue(d)));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _ref(BuildContext buildContext, QueryRelation rel) {
    final kind = rel.target;
    final label = context.labels.relation(rel);
    final title = strings.pickRef.replaceAll('{name}', label);
    Widget warn() => Tooltip(
      message: strings.unresolvedRef,
      child: const Icon(Icons.warning_amber, size: 16),
    );
    if (op == QueryOp.inList) {
      final refs = [
        for (final item in (value as ListValue?)?.items ?? const <QueryValue>[])
          if (item is RefValue) item,
      ];
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final r in refs)
            Chip(
              label: Text(r.label),
              avatar: _known(kind, r.id) ? null : warn(),
            ),
          ActionChip(
            avatar: const Icon(Icons.edit, size: 16),
            label: Text(title),
            onPressed: () async {
              final picked = await showQueryRefMultiPicker(
                buildContext,
                editor: context,
                kind: kind,
                title: title,
                searchHint: strings.pickRefSearch,
                doneLabel: strings.done,
                selected: refs,
              );
              if (picked != null && picked.isNotEmpty) {
                onChanged(ListValue(picked));
              }
            },
          ),
        ],
      );
    }
    final current = value as RefValue?;
    return OutlinedButton.icon(
      icon: current != null && !_known(kind, current.id)
          ? warn()
          : const Icon(Icons.link, size: 16),
      onPressed: () async {
        final picked = await showQueryRefPicker(
          buildContext,
          editor: context,
          kind: kind,
          title: title,
          searchHint: strings.pickRefSearch,
          selected: current,
        );
        if (picked != null) onChanged(picked);
      },
      label: Text(current?.label ?? title),
    );
  }

  /// True when the resolver lists [id] under [kind]; a resolver that cannot
  /// list its entries (the parser-only kind) never flags a ref.
  bool _known(QuerySubject kind, String id) {
    return switch (context.names) {
      final NameEntries entries =>
        entries.refEntries(kind).any((r) => r.id == id),
      _ => true,
    };
  }
}

/// A number field with its own controller, so a rebuild with the same
/// value does not move the caret.
class _NumberField extends StatefulWidget {
  const _NumberField({
    super.key,
    required this.initialText,
    required this.suffix,
    required this.onChanged,
  });

  final String initialText;
  final String? suffix;
  final ValueChanged<String> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: widget.initialText);

  /// Follows a value set from outside (a saved query applied, the field
  /// re-picked, the unit setting changed). The field's own echo (the
  /// number just typed coming back) is left alone, so `30.` keeps its dot.
  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    if (widget.initialText == old.initialText) return;
    final typed = double.tryParse(_controller.text.replaceAll(',', '.'));
    final incoming = double.tryParse(widget.initialText);
    if (typed != null && typed == incoming) return;
    _controller.text = widget.initialText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
    decoration: InputDecoration(suffixText: widget.suffix, isDense: true),
    onChanged: widget.onChanged,
  );
}

class _TextValueField extends StatefulWidget {
  const _TextValueField({required this.initialText, required this.onChanged});

  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_TextValueField> createState() => _TextValueFieldState();
}

class _TextValueFieldState extends State<_TextValueField> {
  late final _controller = TextEditingController(text: widget.initialText);

  /// Follows a value set from outside; its own echo is identical text.
  @override
  void didUpdateWidget(_TextValueField old) {
    super.didUpdateWidget(old);
    if (widget.initialText != old.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: const InputDecoration(isDense: true),
    onChanged: widget.onChanged,
  );
}
