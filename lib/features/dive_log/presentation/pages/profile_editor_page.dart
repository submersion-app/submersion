import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/editor_context_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/editor_toolbar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_editor_chart.dart';

/// Page for editing a dive profile's depth data.
///
/// Provides tools for smoothing, outlier removal, range manipulation,
/// and manual drawing via waypoints.
class ProfileEditorPage extends ConsumerStatefulWidget {
  final String diveId;
  final EditorMode? initialMode;

  const ProfileEditorPage({super.key, required this.diveId, this.initialMode});

  @override
  ConsumerState<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends ConsumerState<ProfileEditorPage> {
  late final StateNotifierProvider<ProfileEditorNotifier, ProfileEditorState>
  _editorProvider;
  bool _providerInitialized = false;

  void _initializeProvider(List<DiveProfilePoint> profile) {
    if (_providerInitialized) return;
    _editorProvider =
        StateNotifierProvider.autoDispose<
          ProfileEditorNotifier,
          ProfileEditorState
        >((ref) {
          final notifier = ProfileEditorNotifier(
            originalProfile: profile,
            editingService: ProfileEditingService(),
          );
          if (widget.initialMode != null) {
            notifier.setMode(widget.initialMode!);
          }
          return notifier;
        });
    _providerInitialized = true;
  }

  Future<bool> _onWillPop() async {
    if (!_providerInitialized) return true;

    final state = ref.read(_editorProvider);
    if (!state.hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes to this dive profile. '
          'Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  Future<void> _handleSave() async {
    final state = ref.read(_editorProvider);
    if (!state.hasChanges) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save profile?'),
        content: const Text(
          'This will save the edited profile as the primary profile '
          'for this dive. The original profile will be preserved '
          'and can be restored later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repository = ref.read(diveRepositoryProvider);
      await repository.saveEditedProfile(widget.diveId, state.editedProfile);
      ref.invalidate(diveProvider(widget.diveId));
      ref.invalidate(diveProfileProvider(widget.diveId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
      return;
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final diveAsync = ref.watch(diveProvider(widget.diveId));

    return diveAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: Center(child: Text('Error loading dive: $error')),
      ),
      data: (dive) {
        if (dive == null || dive.profile.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Profile')),
            body: const Center(child: Text('No profile data available')),
          );
        }

        _initializeProvider(dive.profile);

        return _buildEditor();
      },
    );
  }

  Widget _buildEditor() {
    final state = ref.watch(_editorProvider);
    final notifier = ref.read(_editorProvider.notifier);

    return PopScope(
      canPop: !state.hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: state.undoStack.isNotEmpty
                  ? () => notifier.undo()
                  : null,
              tooltip: 'Undo',
            ),
            FilledButton.icon(
              onPressed: state.hasChanges ? _handleSave : null,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ProfileEditorChart(
                originalProfile: state.originalProfile,
                editedProfile: state.editedProfile,
                outliers: state.detectedOutliers,
                waypoints: state.waypoints,
                selectedRange: state.selectedRange,
                mode: state.mode,
                onTap: (timestamp, depth) {
                  if (state.mode == EditorMode.draw) {
                    notifier.addWaypoint(
                      ProfileWaypoint(timestamp: timestamp, depth: depth),
                    );
                  }
                },
                onRangeChanged: (start, end) =>
                    notifier.setSelectedRange(start: start, end: end),
              ),
            ),
            EditorToolbar(
              mode: state.mode,
              onModeChanged: (mode) => notifier.setMode(mode),
            ),
            EditorContextPanel(
              mode: state.mode,
              notifier: notifier,
              outlierCount: state.detectedOutliers?.length,
              selectedRange: state.selectedRange,
              hasWaypoints: state.waypoints?.isNotEmpty ?? false,
            ),
          ],
        ),
      ),
    );
  }
}
