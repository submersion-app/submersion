/// What the wizard's step indicator shows: its labels, and which one is the
/// current step (issue #1893).
///
/// Acquisition steps that do not apply to this import ([hidden]) are left
/// out, so a UDDF file never shows Map Fields and a one-diver logbook never
/// shows Divers. The page list itself is unchanged; this only maps the
/// wizard's page index onto the dots that remain. The current page is always
/// shown, even while its step would otherwise be hidden.
({List<String> labels, int current}) stepIndicatorView({
  required List<String> acquisitionLabels,
  required List<bool> hidden,
  required List<String> trailingLabels,
  required int currentPage,
}) {
  final shown = [
    for (var i = 0; i < acquisitionLabels.length; i++)
      if (!hidden[i] || i == currentPage) i,
  ];
  final current = currentPage < acquisitionLabels.length
      ? shown.indexOf(currentPage)
      : shown.length + (currentPage - acquisitionLabels.length);
  return (
    labels: [for (final i in shown) acquisitionLabels[i], ...trailingLabels],
    current: current,
  );
}
