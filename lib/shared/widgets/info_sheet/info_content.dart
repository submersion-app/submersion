import 'package:flutter/widgets.dart';

/// One term a card shows, with a short plain definition.
@immutable
class InfoEntry {
  const InfoEntry({required this.term, required this.body});

  /// The name as the card prints it, for example "NDL (no-decompression
  /// limit)".
  final String term;

  /// At most two sentences saying what the number means.
  final String body;

  @override
  bool operator ==(Object other) =>
      other is InfoEntry && other.term == term && other.body == body;

  @override
  int get hashCode => Object.hash(term, body);
}

/// What an info sheet shows for one card, in display order.
///
/// Every section but [title] is optional, and an empty one is left out of
/// the sheet rather than drawn as an empty heading.
@immutable
class InfoContent {
  const InfoContent({
    required this.title,
    this.summary,
    this.terms = const [],
    this.background,
    this.howToUse,
  });

  final String title;

  /// At most two sentences on what the card shows.
  final String? summary;

  /// Only the terms the card shows right now.
  final List<InfoEntry> terms;

  /// At most three sentences of technical background, with references.
  final String? background;

  /// At most four short sentences on the card's inputs, for cards that have
  /// them.
  final String? howToUse;

  InfoContent copyWith({
    String? title,
    String? summary,
    List<InfoEntry>? terms,
    String? background,
    String? howToUse,
  }) {
    return InfoContent(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      terms: terms ?? this.terms,
      background: background ?? this.background,
      howToUse: howToUse ?? this.howToUse,
    );
  }
}

/// Builds a card's [InfoContent] at the moment its info icon is tapped, so
/// the sheet follows what the card shows then.
typedef InfoContentBuilder = InfoContent Function(BuildContext context);
