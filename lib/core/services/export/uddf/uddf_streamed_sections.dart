import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/shared/export_text_spool.dart';
import 'package:submersion/core/services/export/uddf/uddf_computer_tissue.dart';

/// The parts of a full UDDF backup that grow with the dives' recordings,
/// each written a dive at a time into its own spool (issue #4249).
///
/// The rest of the document is small, so it is still built as one XML tree,
/// with an empty slot where each of these sections goes. The tree is then
/// written out with each slot replaced by its spool, so no section holds
/// every dive's data at once.
///
/// The text in a spool is exactly what the pretty printer would have written
/// for those elements inside the full tree: every element is written by the
/// same printer at the depth it sits at in the document, and the slot itself
/// stands where the first of them would start.
class UddfStreamedSections {
  UddfStreamedSections(ExportSpoolStore store)
    : _spools = {for (final name in _depths.keys) name: store.create()};

  static const profileData = 'profiledata';
  static const dataSources = 'datasources';
  static const tankSources = 'tanksources';
  static const tankPressureSeries = 'tankpressureseries';
  static const sourceProfiles = 'sourceprofiles';
  static const diveComputerControl = 'divecomputercontrol';
  static const computerTissue = UddfComputerTissue.sectionName;

  /// Each section's element name, and the depth its children sit at below
  /// `<uddf>`.
  static const _depths = {
    // <profiledata><repetitiongroup>
    profileData: 2,
    // <applicationdata><submersion><computertissue><dive>
    computerTissue: 4,
    dataSources: 4,
    tankSources: 4,
    tankPressureSeries: 4,
    sourceProfiles: 4,
    // <divecomputercontrol><divecomputerdump>
    diveComputerControl: 2,
  };

  static const _indent = '  ';
  static const _slotPrefix = 'uddf-stream:';
  static final _slot = RegExp('<!--$_slotPrefix([a-z]+)-->');

  final Map<String, ExportTextSpool> _spools;

  /// Whether a section inside `<applicationdata>` has anything, which on its
  /// own is reason enough to write that block.
  bool get hasApplicationData => [
    computerTissue,
    dataSources,
    tankSources,
    tankPressureSeries,
    sourceProfiles,
  ].any((name) => !_spools[name]!.isEmpty);

  /// Writes the [name] section's element into [builder], holding only the
  /// slot its spool is written into later. An empty section is left out, as
  /// the one-document builder wrote none, unless [evenIfEmpty] asks for the
  /// bare element.
  void writeSlot(XmlBuilder builder, String name, {bool evenIfEmpty = false}) {
    if (_spools[name]!.isEmpty) {
      if (evenIfEmpty) builder.element(name);
      return;
    }
    builder.element(name, nest: () => builder.comment('$_slotPrefix$name'));
  }

  /// Adds [element] to the [section], at [depth] below `<uddf>` (the
  /// section's own child depth when null).
  void addElement(String section, XmlElement element, {int? depth}) {
    final level = depth ?? _depths[section]!;
    final text = StringBuffer();
    XmlPrettyWriter(text, level: level, indent: _indent).visit(element);
    _add(section, text.toString(), level);
  }

  /// Adds one line of markup, an opening or closing tag the caller writes
  /// itself, to the [section] at [depth].
  void addTag(String section, String tag, {required int depth}) =>
      _add(section, tag, depth);

  /// Adds the children of each section element in [fragment] to the
  /// section of that name: the output of a writer that wraps what it
  /// writes in its section element, run for one dive.
  void addSectionContents(XmlDocumentFragment fragment) {
    for (final section in fragment.children.whereType<XmlElement>()) {
      final name = section.name.local;
      if (!_depths.containsKey(name)) {
        throw StateError('no streamed section named <$name>');
      }
      for (final child in section.children.whereType<XmlElement>()) {
        addElement(name, child);
      }
    }
  }

  // The slot line already starts at the section's depth, so the first item
  // goes straight after it; every later one starts a line of its own, as the
  // printer separates siblings.
  void _add(String section, String text, int depth) {
    final spool = _spools[section]!;
    if (!spool.isEmpty) spool.write('\n${_indent * depth}');
    spool.write(text);
  }

  /// Hands what each spool holds to its file.
  Future<void> flush() async {
    for (final spool in _spools.values) {
      await spool.flush();
    }
  }

  /// Writes [skeleton], the printed document with its slots, into [out],
  /// each slot replaced by its section's spool.
  Future<void> writeDocument(String skeleton, ExportTextSink out) async {
    var start = 0;
    for (final match in _slot.allMatches(skeleton)) {
      out.write(skeleton.substring(start, match.start));
      await _spools[match.group(1)]!.copyTo(out);
      start = match.end;
    }
    out.write(skeleton.substring(start));
    await out.flush();
  }
}
