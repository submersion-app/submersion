import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One line naming what [card] carries: the name, contact details, the
/// headline certification and the dive count (issue #3728).
String buddyCardSummary(BuddyCard card, AppLocalizations l10n) => [
  card.name,
  ?card.phone,
  ?card.email,
  if (card.certs.isNotEmpty) card.certs.first.name,
  if (card.dives != null) l10n.buddySwap_dives(card.dives!),
].join(', ');
