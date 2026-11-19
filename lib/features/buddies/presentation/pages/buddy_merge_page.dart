import 'package:flutter/material.dart';

import 'package:submersion/core/geography/country_code_save.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_country_columns.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_merge.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_merge_form_controller.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_country_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_profile_link_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_country_field.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

part 'buddy_merge_page_fields.dart';
part 'buddy_merge_page_save.dart';

/// Merges two or more buddies into one (issue #4527, phase 3): loads them,
/// then shows [BuddyMergeForm]. Ids that fail to load leave too few to
/// merge, which the page says.
class BuddyMergePage extends ConsumerStatefulWidget {
  final List<String> buddyIds;

  const BuddyMergePage({super.key, required this.buddyIds});

  @override
  ConsumerState<BuddyMergePage> createState() => _BuddyMergePageState();
}

class _BuddyMergePageState extends ConsumerState<BuddyMergePage> {
  late final Future<List<Buddy>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadMergeBuddies();
  }

  Future<List<Buddy>> _loadMergeBuddies() async {
    final repository = ref.read(buddyRepositoryProvider);
    final fetched = await Future.wait(
      widget.buddyIds.map((id) => repository.getBuddyById(id)),
    );
    final buddiesById = <String, Buddy>{
      for (final buddy in fetched.nonNulls) buddy.id: buddy,
    };
    return widget.buddyIds
        .map((id) => buddiesById[id])
        .whereType<Buddy>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Buddy>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.buddies_edit_merge_title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.buddies_edit_merge_loadingErrorTitle),
            ),
            body: Center(
              child: Text(
                context.l10n.buddies_edit_merge_loadingErrorBody(
                  '${snapshot.error}',
                ),
              ),
            ),
          );
        }

        final buddies = snapshot.data;
        if (buddies == null || buddies.length < 2) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.buddies_edit_merge_notEnoughTitle),
            ),
            body: Center(
              child: Text(context.l10n.buddies_edit_merge_notEnoughBody),
            ),
          );
        }

        return BuddyMergeForm(buddies: buddies);
      },
    );
  }
}

/// The merge of [buddies], two or more, loaded: each text value cycles
/// through the distinct values the buddies hold, the rankings exclusion
/// starts on only when every buddy has it, and Merge asks before it merges
/// them into the first. It pops a [BuddyMergeResult].
///
/// It holds only what a merge uses: the survivor's profile link, its
/// certifications and its photo are settled from the buddies, not edited
/// here.
class BuddyMergeForm extends ConsumerStatefulWidget {
  final List<Buddy> buddies;

  const BuddyMergeForm({super.key, required this.buddies})
    : assert(buddies.length > 1, 'a merge needs two or more buddies');

  @override
  ConsumerState<BuddyMergeForm> createState() => _BuddyMergeFormState();
}

class _BuddyMergeFormState extends ConsumerState<BuddyMergeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _socialController = TextEditingController();
  final _countryController = TextEditingController();
  final _notesController = TextEditingController();
  final _merge = BuddyMergeFormController();

  /// The merged buddy whose card figures survive (issue #3728).
  late final Buddy? _cardSource;

  /// The rankings exclusion (issue #3624), as chosen here.
  bool _excludedFromRankings = false;
  bool _isSaving = false;

  /// Whether anything was changed here, so leaving asks first.
  bool _hasChanges = false;

  /// The buddy the others merge into.
  Buddy get _survivor => widget.buddies.first;

  /// Redraws after [change], and notes a change of the merge.
  void _update(VoidCallback change) => setState(() {
    change();
    _hasChanges = true;
  });

  /// Redraws with [saving], which is not a change of the merge.
  void _setSaving(bool saving) => setState(() => _isSaving = saving);

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void initState() {
    super.initState();
    // The merge controller fills the other fields; the social handle and
    // the buddy card figures come from whichever buddy has them, not only
    // the first.
    _socialController.text = mergedSocialHandle(widget.buddies) ?? '';
    _cardSource = mergedBuddyCardSource(widget.buddies);
    _merge.initialize(
      buddies: widget.buddies,
      nameController: _nameController,
      emailController: _emailController,
      phoneController: _phoneController,
      countryController: _countryController,
      notesController: _notesController,
    );
    _excludedFromRankings = _merge.mergedExcludedFromRankings;
    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _socialController,
      _countryController,
      _notesController,
    ]) {
      controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _socialController.dispose();
    _countryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      // Not while the merge is being saved; once merged, the form pops
      // itself with Navigator.pop, which asks no PopScope.
      canPop: !_hasChanges && !_isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isSaving) return;
        final navigator = Navigator.of(context);
        if (await _discardChanges() && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.buddies_edit_merge_title),
          actions: [
            AppBarTextAction(
              label: l10n.common_action_save,
              onPressed: _isSaving ? null : _save,
              busy: _isSaving,
            ),
          ],
        ),
        body: _formBody(context),
      ),
    );
  }
}
