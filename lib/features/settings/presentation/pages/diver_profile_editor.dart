import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// A page that edits the active diver's own profile (issue #4527, phase 4):
/// personal info, medical info, emergency contacts, notes, prior
/// experience. It is the editor host, pinned to the diver the page was
/// filled from.
///
/// The pin is what keeps one diver's details off another: the sitting's
/// record is the diver the page showed, never whoever is active at Save,
/// and the host closes the page back to the hub when another diver becomes
/// active (decision 7). Save reads the diver as stored and applies only the
/// fields this page changed ([applyEditorDraft]), so a sync, the hub's
/// avatar or another profile page is never overwritten.
///
/// The page supplies [fillFromDiver] and [applyEditorDraft] with the host's
/// own members ([editorTitle], [readEditorDraft], [validateEditor]), calls
/// [openProfileEditor] at the end of `initState`, and builds with
/// [profileScaffold].
mixin DiverProfileEditor<W extends ConsumerStatefulWidget, D>
    on ConsumerState<W>, RecordEditorHost<W, D> {
  // What the page supplies.

  /// Fills the form from [diver]: its controllers and choices.
  void fillFromDiver(Diver diver);

  /// [stored] with the fields whose draft value differs between [start]
  /// and [draft] set from [draft], every other field as stored.
  Diver applyEditorDraft(Diver stored, D start, D draft);

  // What the mixin provides.

  /// The diver the page edits: the first one it was filled from. Null
  /// until the active diver has loaded.
  String? _profileDiverId;

  /// The active diver could not be loaded before the page opened.
  Object? _loadError;

  @override
  String get editorTable => 'divers';

  @override
  String? get editorStoredId => _profileDiverId;

  /// Always an edit: the diver is stored, even before it has loaded.
  @override
  bool get editorCreating => false;

  @override
  String? get editorLeaveLocation => '/settings/diver-profile';

  /// Fills the form from the active diver once it is known, and opens the
  /// sitting on it. Later changes of the active diver are the host's to act
  /// on, by closing the page. Call at the end of `initState`.
  void openProfileEditor() {
    ref.listenManual<AsyncValue<Diver?>>(
      currentDiverProvider,
      (_, _) => _openOnSettledDiver(),
      fireImmediately: true,
    );
    // The host tracks the active diver by this id: the page opens on a
    // diver only once the id agrees, so the diver it shows is the diver
    // the host closes it for.
    ref.listenManual<AsyncValue<String?>>(
      validatedCurrentDiverIdProvider,
      (_, _) => _openOnSettledDiver(),
    );
  }

  /// Pins the diver and opens the sitting once the active diver has
  /// settled: loaded (a diver being worked out again still carries the one
  /// it replaces, as does a reload that failed), and the same diver the
  /// active diver id names. Until then the page shows a spinner, or why the
  /// diver could not be loaded.
  void _openOnSettledDiver() {
    if (_profileDiverId != null || !mounted) return;
    final current = ref.read(currentDiverProvider);
    if (current.isLoading) return;
    if (current.hasError) {
      setState(() => _loadError = current.error);
      return;
    }
    final diver = current.value;
    if (diver == null) return;
    final active = ref.read(validatedCurrentDiverIdProvider);
    if (active.isLoading) return;
    // Mid-switch the two can name different divers: wait for the other.
    // An id that could not be worked out does not hold the page; Save then
    // says it failed.
    if (active.hasValue && !active.hasError && active.value != diver.id) {
      return;
    }
    _profileDiverId = diver.id;
    fillFromDiver(diver);
    openEditor();
    setState(() {});
  }

  /// Writes the page's changes onto the diver as stored now, inside the
  /// sitting. A diver gone meanwhile is refused, and nothing is written.
  /// Changes that come to what is already stored (a value typed with a
  /// trailing space, or one synced in meanwhile) write nothing either: the
  /// sitting then ends with no History entry.
  @override
  Future<void> writeEditor(String recordId) async {
    final repository = ref.read(diverRepositoryProvider);
    final stored = await repository.getDiverById(recordId);
    if (stored == null) {
      throw RecordSittingRefusal((l10n) => l10n.divers_edit_notFound);
    }
    final updated = applyEditorDraft(
      stored,
      editorStartDraft as D,
      readEditorDraft(),
    );
    if (updated == stored) return;
    await repository.updateDiver(updated);
  }

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    final diverId = _profileDiverId;
    unawaited(ref.read(diverListNotifierProvider.notifier).refresh());
    if (diverId != null) ref.invalidate(diverByIdProvider(diverId));
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.settings_profileHub_saved)),
    );
  }

  /// The page: while the diver loads, a spinner (or why it could not be
  /// loaded); then [form] on the shared Cancel and Save bar.
  Widget profileScaffold(BuildContext context, {required WidgetBuilder form}) {
    final Widget body;
    if (_profileDiverId != null) {
      body = form(context);
    } else if (_loadError != null) {
      body = Center(child: Text('$_loadError'));
    } else {
      body = const Center(child: CircularProgressIndicator());
    }
    return editorScaffold(context, body: body);
  }
}
