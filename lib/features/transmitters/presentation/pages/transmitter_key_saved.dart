/// What a committed save of the transmitter key editor hands back to the
/// page that pushed it, the item page's Transmitter card (issue #4527,
/// phase 4): whether to offer "Apply to existing dives" with its "Saved"
/// message. A first setup, a downloaded key confirmed, or a takeover offers
/// it; an edit of a key already set up does not.
class TransmitterKeySaved {
  const TransmitterKeySaved({required this.offerApply});

  final bool offerApply;
}
