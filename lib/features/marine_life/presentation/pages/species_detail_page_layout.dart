part of 'species_detail_page.dart';

/// The species page's layout (issue #5027), field-guide style: the hero and
/// its crop strip, the facts, the description, then where, how deep and when
/// it was seen, the sightings and the photos. Two columns on a wide window.
mixin _SpeciesDetailPageLayout
    on
        ConsumerState<SpeciesDetailPage>,
        RecordEditHost<SpeciesDetailPage, Species>,
        RecordOpenUnlocked<SpeciesDetailPage, Species>,
        _SpeciesDetailPageEditing,
        RecordCreating<SpeciesDetailPage, Species> {
  String get speciesId;

  Widget _buildTaxonomyBadge(BuildContext context, String taxonomyClass);

  Widget _buildDescription(
    BuildContext context,
    String description, {
    Widget? pencil,
  });

  /// The tallest the hero grows, however wide its column.
  static const _heroMaxHeight = 420.0;

  Widget _layout(Species species) {
    final l10n = context.l10n;
    final description = species.localizedDescription(l10n);
    final showDescription =
        (description != null && description.isNotEmpty) ||
        _showsWhileEmpty(SpeciesCardId.description);
    final header = _framed(
      SpeciesCardId.header,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heroFor(species),
          if (species.taxonomyClass != null) ...[
            const SizedBox(height: 8),
            _buildTaxonomyBadge(context, species.taxonomyClass!),
          ],
        ],
      ),
    );
    final descriptionCard = showDescription
        ? _framed(
            SpeciesCardId.description,
            _buildDescription(
              context,
              description ?? '',
              pencil: RecordCardPencil(
                cardTitle: SpeciesCardId.description.localizedDisplayName(l10n),
              ),
            ),
          )
        : null;
    // A species not yet created has none of the rest (plan 11, Question 9).
    if (isCreating) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, ?descriptionCard],
        ),
      );
    }
    final left = <Widget>[
      header,
      const SizedBox(height: 12),
      _calculated(_strip()),
      const SizedBox(height: 12),
      _calculated(_facts()),
      if (descriptionCard != null) ...[
        const SizedBox(height: 12),
        descriptionCard,
      ],
    ];
    final right = <Widget>[
      _calculated(SpeciesWhereSeenSection(speciesId: speciesId)),
      _calculated(_depthSeason()),
      _calculated(_timeline()),
      _calculated(SpeciesSightingsSection(speciesId: speciesId)),
      _photosInSitting(),
    ];
    final wide =
        MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.masterDetail;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: left,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: right,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...left, const SizedBox(height: 12), ...right],
            ),
    );
  }

  Widget _heroFor(Species species) {
    final l10n = context.l10n;
    final picture = isCreating
        ? const NoPicture()
        : ref.watch(speciesPicturesProvider).value?[speciesId] ??
              const NoPicture();
    final media =
        ref.watch(mediaForSpeciesProvider(speciesId)).value ??
        const <MediaItem>[];
    final cropMedia = picture is CropPicture
        ? media.where((m) => m.id == picture.crop.mediaId).firstOrNull
        : null;
    final canFind =
        !isCreating &&
        (ref.watch(speciesTagCandidatesProvider(speciesId)).value ?? const [])
            .isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _heroMaxHeight),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SpeciesHero(
                species: species,
                picture: picture,
                cropMedia: cropMedia,
                emptyAction: canFind
                    ? FilledButton.tonalIcon(
                        key: const ValueKey('species_find_photos'),
                        onPressed: () => _findPhotos(species),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.marineLife_speciesDetail_findPhotos),
                      )
                    : null,
              ),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: RecordCardPencil(
                    cardTitle: SpeciesCardId.header.localizedDisplayName(l10n),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Unlocks the page if it is locked, then opens the tag picker on the
  /// photos of the dives the species was logged on.
  Future<void> _findPhotos(Species shown) async {
    if (maybeEditController?.session == null) editController.unlock(shown);
    await WidgetsBinding.instance.endOfFrame;
    final session = maybeEditController?.session;
    if (session != null && mounted) await _tagInSitting(session);
  }

  Widget _strip() {
    final crops = ref.watch(speciesCropsProvider(speciesId)).value ?? const [];
    final media =
        ref.watch(mediaForSpeciesProvider(speciesId)).value ??
        const <MediaItem>[];
    final cropped = {for (final c in crops) c.mediaId};
    final cover = ref.watch(speciesCoversProvider).value?[speciesId];
    final diverId = ref.watch(currentDiverIdProvider);
    final covers = ref.read(speciesCoverRepositoryProvider);
    return SpeciesCropStrip(
      crops: crops,
      uncropped: [
        for (final m in media)
          if (!cropped.contains(m.id)) m,
      ],
      media: media,
      coverIdentificationId: cover?.identificationId,
      coverMediaId: cover?.mediaId,
      onSetCover: (mediaId, identificationId) {
        if (diverId == null) return;
        saveWithFeedback(
          context,
          () => covers.setCover(
            diverId: diverId,
            speciesId: speciesId,
            mediaId: mediaId,
            identificationId: identificationId,
          ),
        );
      },
      onClearCover: () {
        if (diverId == null) return;
        saveWithFeedback(
          context,
          () => covers.clearCover(diverId: diverId, speciesId: speciesId),
        );
      },
    );
  }

  Widget _facts() {
    final l10n = context.l10n;
    return ref
        .watch(speciesInsightsProvider(speciesId))
        .when(
          loading: () => const SizedBox(height: 56),
          // Says so rather than dropping the facts: a failed query is not a
          // species with nothing to show (issue #1930).
          error: (_, _) => Text(
            l10n.marineLife_speciesDetail_statsError,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          data: (insights) {
            final entry = (ref.watch(seenSpeciesProvider).value ?? const [])
                .where((e) => e.species.id == speciesId)
                .firstOrNull;
            final box = ref
                .watch(speciesPracticeStatesProvider)
                .value?[speciesId]
                ?.box;
            return SpeciesFactsRow(
              insights: insights,
              rarity: entry == null
                  ? null
                  : rarityFor(entry, now: DateTime.now(), practiceBox: box),
            );
          },
        );
  }

  Widget _depthSeason() {
    final months = ref.watch(speciesMonthCountsProvider(speciesId)).value;
    if (months == null) return const SizedBox.shrink();
    final insights = ref.watch(speciesInsightsProvider(speciesId)).value;
    return SpeciesDepthSeasonSection(
      photoDepths:
          ref.watch(speciesPhotoDepthsProvider(speciesId)).value ?? const [],
      minDiveDepth: insights?.minDepthMeters,
      maxDiveDepth: insights?.maxDepthMeters,
      monthCounts: months,
    );
  }

  Widget _timeline() => SpeciesSightingsTimeline(
    records: ref.watch(speciesSightingsProvider(speciesId)).value ?? const [],
  );
}
