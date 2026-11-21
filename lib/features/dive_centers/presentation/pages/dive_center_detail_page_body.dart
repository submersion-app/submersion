part of 'dive_center_detail_page.dart';

/// The dive centre page's body for [stored], the centre as stored (or a new
/// centre's seed): its cards, framed for editing in place, in the bar or the
/// list pane.
extension _DiveCenterDetailPageBody on _DiveCenterDetailPageState {
  Widget _centerPage(DiveCenter stored) {
    openUnlockedOnce(stored);
    final center = shownRecord(stored);
    final units = ref.watch(unitFormatterProvider);
    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (center.hasCoordinates || _showsWhileEmpty(DiveCenterCardId.map))
            _framed(
              DiveCenterCardId.map,
              center.hasCoordinates
                  ? Stack(
                      children: [
                        _MapSection(center: center),
                        Positioned(
                          top: 24,
                          left: 24,
                          child: Material(
                            shape: const StadiumBorder(),
                            child: _pencil(DiveCenterCardId.map),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(height: 16),
            ),
          _framed(
            DiveCenterCardId.header,
            _HeaderSection(
              center: center,
              pencil: _pencil(DiveCenterCardId.header),
            ),
          ),
          const Divider(height: 32),
          _framed(
            DiveCenterCardId.contact,
            _ContactSection(
              center: center,
              units: units,
              pencil: _pencil(DiveCenterCardId.contact),
              // Shown though empty while brought in from the strip, or,
              // unlocked, while it holds a value it cannot show (one
              // fill time), so it can be reached to fix it.
              showEmpty:
                  _showsWhileEmpty(DiveCenterCardId.contact) ||
                  (isSittingOpen &&
                      !diveCenterEditCards[DiveCenterCardId.contact]!.isEmpty(
                        center,
                      )),
            ),
          ),
          if (center.notes.isNotEmpty ||
              _showsWhileEmpty(DiveCenterCardId.notes)) ...[
            const Divider(height: 32),
            _framed(
              DiveCenterCardId.notes,
              _NotesSection(
                notes: center.notes,
                pencil: _pencil(DiveCenterCardId.notes),
              ),
            ),
          ],
          const Divider(height: 32),
          _framed(
            DiveCenterCardId.documents,
            DocumentsSection<DiveCenter>(
              owner: DocumentOwner(DocumentOwnerKind.diveCenter, stored.id),
            ),
          ),
          // A centre not yet created has no gear kept there and no dives.
          if (!isCreating) _calculated(GearHereSection(centerId: stored.id)),
          const Divider(height: 32),
          _framed(
            DiveCenterCardId.rentalGear,
            RentalGearSection(
              centerId: stored.id,
              shown: maybeEditController?.session,
            ),
          ),
          const Divider(height: 32),
          if (!isCreating) _calculated(_DivesSection(centerId: stored.id)),
          const SizedBox(height: 32),
        ],
      ),
    );

    if (widget.embedded) {
      final header = _buildEmbeddedHeader(context, center, stored: stored);
      return editPane(header: header, shown: center, content: body);
    }

    final bar = AppBar(
      title: Text(center.name),
      actions: [lockButton(center), _buildMoreMenu(context, center)],
    );
    return editScaffold(
      record: stored,
      shown: center,
      lockedBar: bar,
      unlockedActions: [_buildMoreMenu(context, center)],
      content: body,
    );
  }
}
