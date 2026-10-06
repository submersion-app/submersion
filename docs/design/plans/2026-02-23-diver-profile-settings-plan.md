# Diver Profile Settings Redesign - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the unintuitive Settings > Diver Profile navigation (which ejects to /divers) with a self-contained, iOS Settings-style profile hub within settings, using sectioned sub-pages for editing.

**Architecture:** New pages live in `lib/features/settings/presentation/pages/`. The hub page (`DiverProfileHubPage`) shows the active diver card and section tiles. Each section tile navigates to a focused edit page. All pages use the existing `currentDiverProvider` and `diverListNotifierProvider` for state management. Saves use `diver.copyWith()` for partial updates.

**Tech Stack:** Flutter, Riverpod, go_router, Drift ORM, Material 3

**Design Doc:** `docs/plans/2026-02-23-diver-profile-settings-design.md`

---

## Task 1: Add l10n Keys for New Profile Hub

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`

**Step 1: Add new localization strings**

Add these keys after the existing `settings_profile_*` block (around line 5213):

```json
  "settings_profileHub_personalInfo": "Personal Info",
  "settings_profileHub_personalInfo_notSet": "Not set",
  "settings_profileHub_emergencyContacts": "Emergency Contacts",
  "settings_profileHub_emergencyContacts_count": "{count, plural, =0{Not set} =1{1 contact set} other{{count} contacts set}}",
  "settings_profileHub_medicalInfo": "Medical Information",
  "settings_profileHub_medicalInfo_notSet": "Not set",
  "settings_profileHub_insurance": "Insurance",
  "settings_profileHub_insurance_notSet": "Not set",
  "settings_profileHub_insurance_expired": "Expired",
  "settings_profileHub_notes": "Notes",
  "settings_profileHub_notes_notSet": "Not set",
  "settings_profileHub_switchDiver": "Switch Diver",
  "settings_profileHub_addNewDiver": "Add New Diver",
  "settings_profileHub_deleteDiver": "Delete Diver",
  "settings_profileHub_deleteConfirmTitle": "Delete Diver?",
  "settings_profileHub_deleteConfirmContent": "Are you sure you want to delete {name}? All associated dive logs will be unassigned.",
  "settings_profileHub_deleted": "Diver deleted",
  "settings_profileHub_cannotDeleteOnly": "Cannot delete the only diver profile",
  "settings_profileHub_saved": "Changes saved",
  "settings_profileHub_createDiverTitle": "Create Diver",
  "@settings_profileHub_emergencyContacts_count": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "@settings_profileHub_deleteConfirmContent": {
    "placeholders": {
      "name": { "type": "String" }
    }
  }
```text
**Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: BUILD SUCCEEDED, l10n classes regenerated

**Step 3: Verify keys compile**

Run: `flutter analyze lib/l10n/`
Expected: No analysis issues

**Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add l10n keys for diver profile hub settings"
```text
---

## Task 2: Create DiverProfileHubPage

This is the main hub page at `/settings/diver-profile`. It shows the active diver card and section tiles.

**Files:**

- Create: `lib/features/settings/presentation/pages/diver_profile_hub_page.dart`

**Step 1: Write the hub page**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DiverProfileHubPage extends ConsumerWidget {
  const DiverProfileHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDiverAsync = ref.watch(currentDiverProvider);
    final allDiversAsync = ref.watch(diverListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_diverProfile_title),
        actions: [
          // Overflow menu with delete option (only if >1 diver)
          allDiversAsync.whenOrNull(
                data: (divers) => divers.length > 1
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _showDeleteConfirmation(
                              context,
                              ref,
                              currentDiverAsync.valueOrNull,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              title: Text(
                                context.l10n.settings_profileHub_deleteDiver,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: currentDiverAsync.when(
        data: (diver) => diver == null
            ? _buildNoDiverState(context)
            : _buildHubContent(context, ref, diver, allDiversAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(context.l10n.settings_profile_error_loadingDiver),
        ),
      ),
    );
  }

  Widget _buildNoDiverState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.settings_profile_noDiverProfile,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.settings_profile_noDiverProfile_subtitle),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/settings/diver-profile/new'),
            icon: const Icon(Icons.person_add),
            label: Text(context.l10n.settings_profileHub_addNewDiver),
          ),
        ],
      ),
    );
  }

  Widget _buildHubContent(
    BuildContext context,
    WidgetRef ref,
    Diver diver,
    AsyncValue<List<Diver>> allDiversAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Active diver card
        _buildActiveDiverCard(context, diver),
        const SizedBox(height: 24),

        // Section tiles
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildSectionTile(
                context,
                icon: Icons.person,
                title: context.l10n.settings_profileHub_personalInfo,
                subtitle: _personalInfoSubtitle(diver),
                onTap: () =>
                    context.push('/settings/diver-profile/personal'),
              ),
              const Divider(height: 1),
              _buildSectionTile(
                context,
                icon: Icons.emergency,
                title: context.l10n.settings_profileHub_emergencyContacts,
                subtitle: _emergencyContactsSubtitle(context, diver),
                onTap: () =>
                    context.push('/settings/diver-profile/emergency'),
              ),
              const Divider(height: 1),
              _buildSectionTile(
                context,
                icon: Icons.medical_information,
                title: context.l10n.settings_profileHub_medicalInfo,
                subtitle: _medicalInfoSubtitle(context, diver),
                onTap: () =>
                    context.push('/settings/diver-profile/medical'),
              ),
              const Divider(height: 1),
              _buildSectionTile(
                context,
                icon: Icons.health_and_safety,
                title: context.l10n.settings_profileHub_insurance,
                subtitle: _insuranceSubtitle(context, diver),
                subtitleColor: diver.insurance.isExpired
                    ? colorScheme.error
                    : null,
                onTap: () =>
                    context.push('/settings/diver-profile/insurance'),
              ),
              const Divider(height: 1),
              _buildSectionTile(
                context,
                icon: Icons.note,
                title: context.l10n.settings_profileHub_notes,
                subtitle: _notesSubtitle(context, diver),
                onTap: () =>
                    context.push('/settings/diver-profile/notes'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Diver management tiles
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(context.l10n.settings_profileHub_switchDiver),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showDiverSwitcher(
                  context,
                  ref,
                  allDiversAsync,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: Text(context.l10n.settings_profileHub_addNewDiver),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/settings/diver-profile/new'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDiverCard(BuildContext context, Diver diver) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage:
              diver.photoPath != null ? AssetImage(diver.photoPath!) : null,
          child: diver.photoPath == null
              ? Text(
                  diver.initials,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          diver.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            context.l10n.divers_detail_activeDiver,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: subtitleColor != null
            ? TextStyle(color: subtitleColor, fontWeight: FontWeight.w500)
            : null,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // --- Subtitle helpers ---

  String _personalInfoSubtitle(Diver diver) {
    if (diver.email != null && diver.email!.isNotEmpty) return diver.email!;
    if (diver.phone != null && diver.phone!.isNotEmpty) return diver.phone!;
    return diver.name;
  }

  String _emergencyContactsSubtitle(BuildContext context, Diver diver) {
    int count = 0;
    if (diver.emergencyContact.isComplete) count++;
    if (diver.emergencyContact2.isComplete) count++;
    return context.l10n.settings_profileHub_emergencyContacts_count(count);
  }

  String _medicalInfoSubtitle(BuildContext context, Diver diver) {
    if (diver.bloodType != null && diver.bloodType!.isNotEmpty) {
      return diver.bloodType!;
    }
    if (diver.hasMedicalInfo) {
      return context.l10n.settings_profileHub_medicalInfo;
    }
    return context.l10n.settings_profileHub_medicalInfo_notSet;
  }

  String _insuranceSubtitle(BuildContext context, Diver diver) {
    if (diver.insurance.provider != null &&
        diver.insurance.provider!.isNotEmpty) {
      final provider = diver.insurance.provider!;
      if (diver.insurance.isExpired) {
        return '$provider - ${context.l10n.settings_profileHub_insurance_expired}';
      }
      if (diver.insurance.expiryDate != null) {
        final formatted =
            DateFormat.yMMMd().format(diver.insurance.expiryDate!);
        return '$provider - $formatted';
      }
      return provider;
    }
    return context.l10n.settings_profileHub_insurance_notSet;
  }

  String _notesSubtitle(BuildContext context, Diver diver) {
    if (diver.notes.isNotEmpty) {
      return diver.notes.split('\n').first;
    }
    return context.l10n.settings_profileHub_notes_notSet;
  }

  // --- Diver switcher bottom sheet ---

  void _showDiverSwitcher(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Diver>> allDiversAsync,
  ) {
    final currentDiverId = ref.read(currentDiverIdProvider);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.settings_profile_switchDiver_title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            allDiversAsync.when(
              data: (divers) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: divers.length,
                  itemBuilder: (context, index) {
                    final diver = divers[index];
                    final isCurrentDiver = diver.id == currentDiverId;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          diver.initials,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(diver.name),
                      trailing: isCurrentDiver
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () async {
                        if (!isCurrentDiver) {
                          await ref
                              .read(currentDiverIdProvider.notifier)
                              .setCurrentDiver(diver.id);
                        }
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (context.mounted && !isCurrentDiver) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.settings_profile_switchedTo(
                                  diver.name,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $error'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- Delete confirmation ---

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Diver? diver,
  ) {
    if (diver == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_profileHub_deleteConfirmTitle),
        content: Text(
          context.l10n.settings_profileHub_deleteConfirmContent(diver.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.divers_detail_cancelButton),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(diverListNotifierProvider.notifier)
                  .deleteDiver(diver.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(context.l10n.settings_profileHub_deleted),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.divers_detail_deleteButton),
          ),
        ],
      ),
    );
  }
}
```text
**Step 2: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/pages/diver_profile_hub_page.dart`
Expected: No analysis issues (may fail until l10n keys exist -- do Task 1 first)

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/diver_profile_hub_page.dart
git commit -m "feat: add DiverProfileHubPage for settings-integrated profile management"
```text
---

## Task 3: Create PersonalInfoEditPage

Focused edit page for name, email, phone. Also handles "create new diver" mode.

**Files:**

- Create: `lib/features/settings/presentation/pages/personal_info_edit_page.dart`

**Step 1: Write the page**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edit page for personal info (name, email, phone).
/// When [isNewDiver] is true, creates a new diver instead of updating.
class PersonalInfoEditPage extends ConsumerStatefulWidget {
  final bool isNewDiver;

  const PersonalInfoEditPage({super.key, this.isNewDiver = false});

  @override
  ConsumerState<PersonalInfoEditPage> createState() =>
      _PersonalInfoEditPageState();
}

class _PersonalInfoEditPageState extends ConsumerState<PersonalInfoEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onChanged);
    _emailController.addListener(_onChanged);
    _phoneController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  void _populateFields(Diver diver) {
    _nameController.text = diver.name;
    _emailController.text = diver.email ?? '';
    _phoneController.text = diver.phone ?? '';
    // Reset changes flag after populating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasChanges = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // For editing: watch current diver, populate fields once
    if (!widget.isNewDiver) {
      final diverAsync = ref.watch(currentDiverProvider);
      return diverAsync.when(
        data: (diver) {
          if (diver != null && !_hasChanges && _nameController.text.isEmpty) {
            _populateFields(diver);
          }
          return _buildScaffold(context, diver);
        },
        loading: () =>
            Scaffold(body: const Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      );
    }

    return _buildScaffold(context, null);
  }

  Widget _buildScaffold(BuildContext context, Diver? existingDiver) {
    final isCreating = widget.isNewDiver;
    final title = isCreating
        ? context.l10n.settings_profileHub_createDiverTitle
        : context.l10n.settings_profileHub_personalInfo;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _hasChanges) {
          final shouldDiscard = await _showDiscardDialog();
          if (shouldDiscard == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => _save(existingDiver),
                child: Text(context.l10n.divers_edit_saveButton),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_nameLabel,
                        prefixIcon: const Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.divers_edit_nameError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_emailLabel,
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.contains('@') || !value.contains('.')) {
                            return context.l10n.divers_edit_emailError;
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_phoneLabel,
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(Diver? existingDiver) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      if (widget.isNewDiver) {
        // Create new diver
        final newDiver = Diver(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        final created = await ref
            .read(diverListNotifierProvider.notifier)
            .addDiver(newDiver);
        // Set as active diver
        await ref
            .read(currentDiverIdProvider.notifier)
            .setCurrentDiver(created.id);
      } else if (existingDiver != null) {
        // Update existing diver
        final updated = existingDiver.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          updatedAt: now,
        );
        await ref
            .read(diverListNotifierProvider.notifier)
            .updateDiver(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settings_profileHub_saved),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.divers_edit_errorSaving('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.divers_edit_discardDialogTitle),
        content: Text(context.l10n.divers_edit_discardDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.divers_edit_keepEditingButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.divers_edit_discardButton),
          ),
        ],
      ),
    );
  }
}
```text
**Step 2: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/pages/personal_info_edit_page.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/personal_info_edit_page.dart
git commit -m "feat: add PersonalInfoEditPage for profile section editing"
```text
---

## Task 4: Create EmergencyContactsEditPage

**Files:**

- Create: `lib/features/settings/presentation/pages/emergency_contacts_edit_page.dart`

**Step 1: Write the page**

This page edits the primary and secondary emergency contacts. Uses the same pattern as PersonalInfoEditPage: load current diver, populate fields, save with `copyWith()`.

Key fields per contact:

- Contact Name (`TextEditingController`)
- Contact Phone (`TextEditingController`)
- Relationship (`TextEditingController`)

Save logic: `existingDiver.copyWith(emergencyContact: EmergencyContact(...), emergencyContact2: EmergencyContact(...))`

Follow the exact same structure as `PersonalInfoEditPage`:

- `ConsumerStatefulWidget`
- 6 controllers (3 per contact)
- `_populateFields` reads from `diver.emergencyContact` and `diver.emergencyContact2`
- Form has two Card sections, one per contact with title headers ("Primary Contact", "Secondary Contact")
- Uses existing l10n keys: `divers_edit_contactNameLabel`, `divers_edit_contactPhoneLabel`, `divers_edit_relationshipLabel`, `divers_edit_relationshipHint`, `divers_edit_primaryContactTitle`, `divers_edit_secondaryContactTitle`
- Title in AppBar: `context.l10n.settings_profileHub_emergencyContacts`

**Step 2: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/pages/emergency_contacts_edit_page.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/emergency_contacts_edit_page.dart
git commit -m "feat: add EmergencyContactsEditPage for profile section editing"
```text
---

## Task 5: Create MedicalInfoEditPage

**Files:**

- Create: `lib/features/settings/presentation/pages/medical_info_edit_page.dart`

**Step 1: Write the page**

Fields:

- Blood Type (`TextEditingController`)
- Allergies (`TextEditingController`)
- Medications (`TextEditingController`)
- Medical Clearance Expiry (`DateTime?` with date picker -- reuse the `_buildMedicalClearanceField` pattern from `diver_edit_page.dart:587-690`)
- Medical Notes (`TextEditingController`, maxLines: 3)

Save logic: `existingDiver.copyWith(bloodType: ..., allergies: ..., medications: ..., medicalNotes: ..., medicalClearanceExpiryDate: ...)`

Uses existing l10n keys: `divers_edit_bloodTypeLabel`, `divers_edit_bloodTypeHint`, `divers_edit_allergiesLabel`, `divers_edit_allergiesHint`, `divers_edit_medicationsLabel`, `divers_edit_medicationsHint`, `divers_edit_medicalClearanceTitle`, `divers_edit_medicalNotesLabel`, `divers_edit_medicalClearanceExpired`, `divers_edit_medicalClearanceExpiringSoon`, `divers_edit_medicalClearanceNotSet`, `divers_edit_clearMedicalClearanceTooltip`, `divers_edit_selectMedicalClearanceTooltip`

Title: `context.l10n.settings_profileHub_medicalInfo`

**Step 2: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/pages/medical_info_edit_page.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/medical_info_edit_page.dart
git commit -m "feat: add MedicalInfoEditPage for profile section editing"
```dart
---

## Task 6: Create InsuranceEditPage

**Files:**

- Create: `lib/features/settings/presentation/pages/insurance_edit_page.dart`

**Step 1: Write the page**

Fields:

- Insurance Provider (`TextEditingController`)
- Policy Number (`TextEditingController`)
- Expiry Date (`DateTime?` with date picker -- reuse insurance expiry pattern from `diver_edit_page.dart:710-770`)

Save logic: `existingDiver.copyWith(insurance: DiverInsurance(provider: ..., policyNumber: ..., expiryDate: ...))`

Uses existing l10n keys: `divers_edit_insuranceProviderLabel`, `divers_edit_insuranceProviderHint`, `divers_edit_policyNumberLabel`, `divers_edit_expiryDateTitle`, `divers_edit_expiryDateNotSet`, `divers_edit_clearInsuranceExpiryTooltip`, `divers_edit_selectInsuranceExpiryTooltip`

Title: `context.l10n.settings_profileHub_insurance`

**Step 2: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/pages/insurance_edit_page.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/insurance_edit_page.dart
git commit -m "feat: add InsuranceEditPage for profile section editing"
```text
---

## Task 7: Create NotesEditPage

**Files:**

- Create: `lib/features/settings/presentation/pages/notes_edit_page.dart`

**Step 1: Write the page**

Simplest sub-page. Single field:

- Notes (`TextEditingController`, maxLines: 10)

Save logic: `existingDiver.copyWith(notes: _notesController.text.trim())`

Uses existing l10n key: `divers_edit_notesLabel`

Title: `context.l10n.settings_profileHub_notes`

**Step 2: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/pages/notes_edit_page.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/notes_edit_page.dart
git commit -m "feat: add NotesEditPage for profile section editing"
```text
---

## Task 8: Add Routes to app_router.dart

**Files:**

- Modify: `lib/core/router/app_router.dart`

**Step 1: Add imports at top of file (after line 63)**

```dart
import 'package:submersion/features/settings/presentation/pages/diver_profile_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/personal_info_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/emergency_contacts_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/medical_info_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/insurance_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/notes_edit_page.dart';
```text
**Step 2: Add new routes inside the `/settings` route block (after line 731, before the closing `]` of settings routes)**

```dart
              GoRoute(
                path: 'diver-profile',
                name: 'diverProfile',
                builder: (context, state) => const DiverProfileHubPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: 'newDiverProfile',
                    builder: (context, state) =>
                        const PersonalInfoEditPage(isNewDiver: true),
                  ),
                  GoRoute(
                    path: 'personal',
                    name: 'editPersonalInfo',
                    builder: (context, state) => const PersonalInfoEditPage(),
                  ),
                  GoRoute(
                    path: 'emergency',
                    name: 'editEmergencyContacts',
                    builder: (context, state) =>
                        const EmergencyContactsEditPage(),
                  ),
                  GoRoute(
                    path: 'medical',
                    name: 'editMedicalInfo',
                    builder: (context, state) => const MedicalInfoEditPage(),
                  ),
                  GoRoute(
                    path: 'insurance',
                    name: 'editInsurance',
                    builder: (context, state) => const InsuranceEditPage(),
                  ),
                  GoRoute(
                    path: 'notes',
                    name: 'editNotes',
                    builder: (context, state) => const NotesEditPage(),
                  ),
                ],
              ),
```text
**Step 3: Verify compilation**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat: add go_router routes for diver profile settings sub-pages"
```text
---

## Task 9: Wire Up Settings Navigation

Update the mobile settings tile to navigate to the new hub instead of /divers, and update the desktop detail builder to show the hub.

**Files:**

- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (lines 220-221, 82, 157)

**Step 1: Update mobile navigation (settings_page.dart:220-221)**

Change:

```dart
      case 'profile':
        context.push('/divers');
        break;
```text
To:

```dart
      case 'profile':
        context.push('/settings/diver-profile');
        break;
```text
**Step 2: Update desktop detail builder (settings_page.dart:82)**

Change:

```dart
      case 'profile':
        return _ProfileSectionContent(ref: ref);
```text
To:

```dart
      case 'profile':
        return const DiverProfileHubPage();
```text
And also update the same switch in `_buildContent` (settings_page.dart:157):

```dart
      case 'profile':
        return const DiverProfileHubPage();
```typescript
**Step 3: Add import at top of settings_page.dart**

```dart
import 'package:submersion/features/settings/presentation/pages/diver_profile_hub_page.dart';
```text
**Step 4: Verify compilation**

Run: `flutter analyze lib/features/settings/presentation/pages/settings_page.dart`
Expected: No issues (the old `_ProfileSectionContent` class will become unused -- that's fine, we'll clean it up in Task 10)

**Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat: wire settings diver profile navigation to new hub page"
```text
---

## Task 10: Clean Up Unused Code

**Files:**

- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

**Step 1: Remove the old `_ProfileSectionContent` class**

Delete the entire `_ProfileSectionContent` class (approximately lines 241-463 of settings_page.dart), including its `_buildDiverCard`, `_buildSectionHeader` in that context, and `_showDiverSwitcher` methods.

**Step 2: Verify no references remain**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "refactor: remove old _ProfileSectionContent (replaced by DiverProfileHubPage)"
```text
---

## Task 11: Manual Integration Test

**Step 1: Run the app**

Run: `flutter run -d macos`

**Step 2: Test the full flow**

- Navigate to Settings tab
- Tap "Diver Profile" -- should open the hub page (NOT /divers)
- Verify active diver card shows correctly
- Tap "Personal Info" -- should open edit page with pre-filled fields
- Change email, tap Save -- should return to hub with updated subtitle
- Tap "Emergency Contacts" -- verify both contact forms work
- Tap "Medical Information" -- verify all fields and date picker
- Tap "Insurance" -- verify fields and date picker
- Tap "Notes" -- verify text area
- Tap "Switch Diver" -- verify bottom sheet, switching works
- Tap "Add New Diver" -- verify create flow with just name/email/phone
- Test overflow menu > Delete Diver (only when >1 diver)
- Test dirty-check: edit a field, press back without saving -- should show discard dialog

**Step 3: Run all tests**

Run: `flutter test`
Expected: All existing tests pass

**Step 4: Format code**

Run: `dart format lib/features/settings/presentation/pages/ lib/core/router/app_router.dart`

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: formatting pass on diver profile settings redesign"
```
