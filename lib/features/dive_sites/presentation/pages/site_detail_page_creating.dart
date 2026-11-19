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
  SiteDuplicateSource? _duplicate;

  /// The site to duplicate could not be read, or is gone.
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = widget.page.newSite!;
    final read = ref.read;
    final seed = await newSiteSeed(read, id: _id);
    final duplicateOfId = request.duplicateOfId;
    SiteDuplicateSource? duplicate;
    if (duplicateOfId != null) {
      final source = siteDuplicateSourceProvider(duplicateOfId);
      try {
        duplicate = await read(source.future);
      } catch (error, stackTrace) {
        _editLog.error(
          'Reading site $duplicateOfId to duplicate failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      // Read once: the next duplicate of it reads the site as it is then.
      if (mounted) ref.invalidate(source);
    }
    if (!mounted) return;
    setState(() {
      _seed = seed;
      _duplicate = duplicate;
      _gone = duplicateOfId != null && duplicate == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final request = page.newSite!;
    final l10n = context.l10n;
    if (_gone) {
      final body = Center(child: Text(l10n.diveSites_detail_siteNotFound_body));
      if (page.embedded) return body;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.diveSites_detail_siteNotFound_title)),
        body: body,
      );
    }
    final seed = _seed;
    if (seed == null) {
      return _newSiteLoading(
        context,
        embedded: page.embedded,
        duplicate: request.duplicateOfId != null,
      );
    }
    return _SiteDetailContent(
      site: seed,
      siteId: seed.id,
      embedded: page.embedded,
      unlockEditing: true,
      newSite: _NewSite(
        seed: request.seed,
        duplicate: _duplicate,
        onCreated: page.onCreated,
        onCreateCancelled: page.onCreateCancelled,
      ),
    );
  }
}

/// The new-site page's title: today's form's, for a new site or a
/// duplicate.
String _newSiteTitle(BuildContext context, {required bool duplicate}) =>
    duplicate
    ? context.l10n.diveSites_edit_appBar_duplicateSite
    : context.l10n.diveSites_edit_appBar_newSite;

/// Waiting on a new site: the seed being made, or the created site being
/// handed on.
Widget _newSiteLoading(
  BuildContext context, {
  required bool embedded,
  required bool duplicate,
}) {
  const spinner = Center(child: CircularProgressIndicator());
  if (embedded) return spinner;
  return Scaffold(
    appBar: AppBar(title: Text(_newSiteTitle(context, duplicate: duplicate))),
    body: spinner,
  );
}

/// What only a new site's page does: open its sitting on the seed, create
/// the site at Save, and leave.
mixin _SiteDetailPageCreating
    on ConsumerState<_SiteDetailContent>, _SiteDetailPageEditing {
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
    if (_opened && _created == null && !_leaving) return null;
    return _newSiteLoading(
      context,
      embedded: widget.embedded,
      duplicate: widget.newSite?.duplicate != null,
    );
  }

  @override
  String editingTitle(DiveSite site) {
    final request = widget.newSite;
    if (request == null) return super.editingTitle(site);
    return _newSiteTitle(context, duplicate: request.duplicate != null);
  }

  /// A sitting that ends without a create while the page is in view
  /// leaves, as Cancel does (plan 6, call 9).
  @override
  void onEditChanged() {
    super.onEditChanged();
    if (!isCreating || !_opened || _created != null || _leaving) return;
    if (maybeEditController?.isUnlocked ?? false) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving || _created != null) return;
      if (maybeEditController?.isUnlocked ?? false) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
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
    final changedCardIds = session.changedCardIds;
    final diverId = activeDiver == null ? null : await activeDiver;
    var site = session.applyTo(session.stored);
    if (site.diverId == null && diverId != null) {
      site = site.copyWith(diverId: diverId);
    }
    final created = await undoMediaOnFailure(
      session,
      () => service.create(
        site: site,
        changedCardIds: changedCardIds,
        // Everything held points at the site: all of it runs after the row.
        alsoWrite: session.hasHeldWrites
            ? () async {
                await session.runHeldWrites(beforeRecord: true);
                await session.runHeldWrites();
              }
            : null,
      ),
    );
    if (mounted) setState(() => _created = created);
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
    await rulesAfterCreate(subject: RuleSubject.sites, ids: [created.id]);
    if (!mounted) return;
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
