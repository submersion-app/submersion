part of 'site_detail_page.dart';

/// A new site on the site page (issue #4527, phase 2, plan 6).
///
/// There is no form: the page opens unlocked on a seed, a site that exists
/// only in memory under the id it will be created with, holding the
/// defaults every new site gets ([newSiteSeed]). The header block and the
/// starter cards are laid out open, a seed's name or point and a
/// duplicate's copy go on through the cards' own functions as changes
/// ([applyNewSitePrefill]), and every other card waits in the Add strip.
/// Save creates the site in one transaction ([SiteEditSaveService.create]),
/// runs the rules a site created by hand is owed, and leaves with its id.
/// Cancel leaves, asking first once something was entered.

/// A new site's request as the page holds it once read.
class _NewSite {
  const _NewSite({
    this.seed,
    this.duplicate,
    this.onCreated,
    this.onCreateCancelled,
  });

  final NewSiteSeed? seed;
  final SiteDuplicateSource? duplicate;
  final void Function(String siteId)? onCreated;
  final VoidCallback? onCreateCancelled;
}

/// The page while a new site is made: loading while the seed and a
/// duplicate's source are read, then the site page on the seed.
class _NewSiteLoader extends ConsumerStatefulWidget {
  const _NewSiteLoader({required this.page});

  final SiteDetailPage page;

  @override
  ConsumerState<_NewSiteLoader> createState() => _NewSiteLoaderState();
}

class _NewSiteLoaderState extends ConsumerState<_NewSiteLoader> {
  /// The id the site will be created with, made once for the page.
  final _id = const Uuid().v4();

  DiveSite? _seed;

  /// The read error last logged: the page is built many times over one.
  Object? _loggedError;

  @override
  void initState() {
    super.initState();
    _makeSeed();
  }

  Future<void> _makeSeed() async {
    final seed = await newSiteSeed(ref.read, id: _id);
    if (mounted) setState(() => _seed = seed);
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final request = page.newSite!;
    final duplicateOfId = request.duplicateOfId;
    // Watched, so the source lives as long as the page and no longer.
    final source = duplicateOfId == null
        ? null
        : ref.watch(siteDuplicateSourceProvider(duplicateOfId));
    final l10n = context.l10n;
    // A read that failed says what failed, as the stored site's page does;
    // only a site that is gone reads as not found. It keeps saying so while
    // Riverpod tries the read again (an Exception is retried), which marks
    // the source loading once more.
    if (source != null && source.hasError) {
      if (!identical(source.error, _loggedError)) {
        _loggedError = source.error;
        _editLog.error(
          'Reading site $duplicateOfId to duplicate failed',
          error: source.error,
          stackTrace: source.stackTrace,
        );
      }
      return _newSiteMessage(
        page,
        title: l10n.diveSites_detail_error_title,
        body: l10n.diveSites_detail_error_body('${source.error}'),
      );
    }
    if (source != null && !source.isLoading && source.value == null) {
      return _newSiteMessage(
        page,
        title: l10n.diveSites_detail_siteNotFound_title,
        body: l10n.diveSites_detail_siteNotFound_body,
      );
    }
    final seed = _seed;
    if (seed == null || (source != null && source.isLoading)) {
      return _newSiteLoading(
        context,
        embedded: page.embedded,
        duplicate: duplicateOfId != null,
      );
    }
    return _SiteDetailContent(
      site: seed,
      siteId: seed.id,
      embedded: page.embedded,
      newSite: _NewSite(
        seed: request.seed,
        duplicate: source?.value,
        onCreated: page.onCreated,
        onCreateCancelled: page.onCreateCancelled,
      ),
    );
  }
}

/// The page in place of a new site that cannot open: [body] alone in a
/// pane, under [title] on a full page.
Widget _newSiteMessage(
  SiteDetailPage page, {
  required String title,
  required String body,
}) {
  final message = Center(child: Text(body));
  if (page.embedded) return message;
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: message,
  );
}

/// The new-site page's title: today's form's, for a new site or a
/// duplicate.
String _newSiteTitle(BuildContext context, {required bool duplicate}) =>
    duplicate
    ? context.l10n.diveSites_edit_appBar_duplicateSite
    : context.l10n.diveSites_edit_appBar_newSite;

/// Waiting on a new site: the seed being made, or the created site being
/// handed on. While handing on ([holdBack]) Back waits: the site exists,
/// and leaving then would leave its opener without it.
Widget _newSiteLoading(
  BuildContext context, {
  required bool embedded,
  required bool duplicate,
  bool holdBack = false,
}) {
  const spinner = Center(child: CircularProgressIndicator());
  final page = embedded
      ? spinner
      : Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !holdBack,
            title: Text(_newSiteTitle(context, duplicate: duplicate)),
          ),
          body: spinner,
        );
  return holdBack ? PopScope(canPop: false, child: page) : page;
}

/// What only a new site's page does: open its sitting on the seed, create
/// the site at Save, and leave.
mixin _SiteDetailPageCreating
    on
        ConsumerState<_SiteDetailContent>,
        _SiteDetailPageEditing,
        RecordOpenUnlocked<_SiteDetailContent, DiveSite> {
  /// The site as Save created it, while the page hands it on.
  DiveSite? _created;

  /// The sitting has been opened on the seed.
  bool _opened = false;

  /// The page is leaving: nothing opens or leaves again.
  bool _leaving = false;

  /// A new site's page, for its whole life: once created, it only leaves.
  @override
  bool get isCreating => widget.newSite != null;

  @override
  void initState() {
    super.initState();
    if (!isCreating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNewSite());
  }

  /// Opens the sitting on the seed with the starter cards and every card
  /// a seed or a duplicate fills laid out, then puts them on it.
  void _openNewSite() {
    final request = widget.newSite;
    if (!mounted || request == null || _opened) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final duplicate = request.duplicate;
    final duplicateName = duplicate == null
        ? null
        : context.l10n.diveSites_edit_duplicateName(duplicate.site.name);
    final controller = editController
      ..unlock(
        widget.site,
        laidOut: newSiteLaidOutCards(
          base: widget.site,
          seed: request.seed,
          duplicate: duplicate,
        ),
      );
    final session = controller.session;
    if (session == null) return;
    setState(() => _opened = true);
    applyNewSitePrefill(
      session,
      seed: request.seed,
      duplicate: duplicate,
      duplicateName: duplicateName,
      lookUpPlace: (point) => container
          .read(locationServiceProvider)
          .reverseGeocode(
            point.latitude,
            point.longitude,
            languageCode: container.read(placeNameLanguageProvider),
          ),
      fetchElevation: (point) => container
          .read(elevationServiceProvider)
          .fetchElevation(latitude: point.latitude, longitude: point.longitude),
    ).ignore();
  }

  /// The page in place of the site while a new site has no sitting yet,
  /// once it is created, or while it leaves; null otherwise.
  Widget? _newSiteWaiting(BuildContext context) {
    if (!isCreating) return null;
    _leaveIfEnded(context);
    if (_opened && _created == null && !_leaving) return null;
    return _newSiteLoading(
      context,
      embedded: widget.embedded,
      duplicate: widget.newSite?.duplicate != null,
      holdBack: _created != null,
    );
  }

  @override
  String editingTitle(DiveSite site) {
    final request = widget.newSite;
    if (request == null) return super.editingTitle(site);
    return _newSiteTitle(context, duplicate: request.duplicate != null);
  }

  /// The app's own leave check ended the sitting: its navigation leaves.
  bool _endedByLeave = false;

  @override
  void noteOpenedSittingEnded() {
    // Read first: this is where the mark is cleared once the sitting ends.
    if (!isSittingOpen && sittingEndedByLeave) _endedByLeave = true;
    super.noteOpenedSittingEnded();
  }

  /// A sitting that ended without a create leaves, as Cancel does (plan 6,
  /// call 9), once the page is in view: asked from `build`, which reads
  /// whether the page is current, so it is asked again on coming back.
  void _leaveIfEnded(BuildContext context) {
    if (!isCreating || !_opened || _created != null || _leaving) return;
    if (_endedByLeave || isSittingOpen) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving || _created != null || isSittingOpen) return;
      if (!(ModalRoute.of(this.context)?.isCurrent ?? true)) return;
      _leaveNewSite();
    });
  }

  /// The creating sitting's write: the site, then everything the sitting
  /// held, in one transaction, then the site lists read again.
  @override
  Future<void> saveSitting(EditSession<DiveSite> session) async {
    if (!isCreating) return super.saveSitting(session);
    // Read now: the write may finish after the page has gone.
    final service = ref.read(siteEditSaveServiceProvider);
    final sites = ref.read(siteListNotifierProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    // The diver active now, for a seed whose diver could not be read when
    // the page opened: the site is theirs.
    final activeDiver = session.stored.diverId == null
        ? ref.read(validatedCurrentDiverIdProvider.future)
        : null;
    final diverId = activeDiver == null ? null : await activeDiver;
    final created = await createSiteSitting(
      session,
      service,
      activeDiverId: diverId,
    );
    // Kept even once the page has gone: the rules it is owed still run.
    if (mounted) {
      setState(() => _created = created);
    } else {
      _created = created;
    }
    // The site exists from here on: nothing that follows may read as a
    // failed save, which would hand the diver the sitting to create again.
    await _refreshSiteList(sites, created.id);
    container
      ..invalidate(sitesProvider)
      ..invalidate(sitesWithCountsProvider);
  }

  /// Save: creates the site, runs the rules a site created by hand is
  /// owed, then leaves with its id. A save that is refused or fails says
  /// so, and the page stays with everything entered.
  @override
  Future<void> saveNewRecord() async {
    if (_created != null || _leaving) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = editController;
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);
    final saved = await controller.save();
    if (!saved) {
      if (!mounted) return;
      final error = controller.saveError;
      if (controller.refusedForInvalidInput) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.recordEdit_fixInvalid)),
        );
      } else if (error != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              error is RecordSittingRefusal
                  ? error.message(l10n)
                  : l10n.recordEdit_saveFailed,
            ),
          ),
        );
      }
      return;
    }
    final created = _created;
    if (created == null) return;
    // Run whether or not the page is still there: the site exists.
    await rulesAfterCreate(subject: RuleSubject.sites, ids: [created.id]);
    // Gone meanwhile (the app moved elsewhere): its pop would take the
    // page under it.
    if (!mounted || !(ModalRoute.of(context)?.isActive ?? true)) return;
    _leaving = true;
    if (widget.embedded) {
      widget.newSite?.onCreated?.call(created.id);
    } else {
      _popNewSite(created.id);
    }
  }

  /// Cancel, from the bar or Escape: asks when something was entered,
  /// then leaves without creating anything.
  @override
  Future<void> cancelNewRecord() async {
    if (_created != null || _leaving) return;
    if (!await cancelSitting(context, editController)) return;
    if (!mounted) return;
    _leaveNewSite();
  }

  void _leaveNewSite() {
    if (_leaving) return;
    setState(() => _leaving = true);
    if (widget.embedded) {
      widget.newSite?.onCreateCancelled?.call();
    } else {
      _popNewSite(null);
    }
  }

  /// Leaves the full page with [result], the new id or nothing, as the
  /// form did: its openers take the id (plan 6, Question 1).
  void _popNewSite(String? result) {
    final router = GoRouter.maybeOf(context);
    // A plain pop, as a save leaves: the leave check still holds the frame
    // drawn before the sitting ended, and would ask again.
    if (router == null) {
      Navigator.of(context).pop(result);
    } else if (router.canPop()) {
      context.pop(result);
    } else {
      context.go('/sites');
    }
  }
}
