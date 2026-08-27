import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';

/// Data loaded for a buddy merge operation.
class MergeLoadData {
  final List<Buddy> buddies;
  const MergeLoadData({required this.buddies});
}

/// A candidate value from a specific buddy for merge field cycling.
class MergeFieldCandidate<T> {
  final String buddyId;
  final String buddyName;
  final T value;
  const MergeFieldCandidate({
    required this.buddyId,
    required this.buddyName,
    required this.value,
  });
}

/// Manages merge candidate state and field cycling for the buddy merge form.
///
/// Extracted from BuddyEditPage to keep file sizes under the 800-line limit.
/// Holds candidate lists and indices but does not own widget state directly;
/// mutation methods return new values for the caller to apply via setState.
class BuddyMergeFormController {
  final Map<String, List<MergeFieldCandidate<String>>> textCandidates = {};
  final Map<String, int> fieldIndices = {};
  List<MergeFieldCandidate<String?>> photoCandidates = [];
  String? mergedPhotoPath;
  bool isInitialized = false;

  /// Initialize merge candidate state from loaded buddies. Sets the text
  /// controller values and the merged photo path. Certifications are NOT
  /// cycled here (issue #553): the survivor inherits the union of certs at the
  /// repository level, so the buddy edit form hides its cert section in merge
  /// mode.
  void initialize({
    required List<Buddy> buddies,
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController phoneController,
    required TextEditingController notesController,
  }) {
    if (isInitialized) return;
    isInitialized = true;

    _initializeTextField(
      key: 'name',
      controller: nameController,
      buddies: buddies,
      getValue: (buddy) => buddy.name,
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeTextField(
      key: 'email',
      controller: emailController,
      buddies: buddies,
      getValue: (buddy) => buddy.email ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeTextField(
      key: 'phone',
      controller: phoneController,
      buddies: buddies,
      getValue: (buddy) => buddy.phone ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeTextField(
      key: 'notes',
      controller: notesController,
      buddies: buddies,
      getValue: (buddy) => buddy.notes,
      isMeaningful: (value) => value.trim().isNotEmpty,
    );

    photoCandidates = _buildDistinctCandidates<String?>(
      buddies,
      (buddy) => buddy.photoPath,
      equals: (a, b) => a == b,
    );
    fieldIndices['photo'] = _firstMeaningfulIndex(
      photoCandidates,
      (value) => value != null && value.isNotEmpty,
    );
    mergedPhotoPath = photoCandidates[fieldIndices['photo'] ?? 0].value;
  }

  void _initializeTextField({
    required String key,
    required TextEditingController controller,
    required List<Buddy> buddies,
    required String Function(Buddy buddy) getValue,
    required bool Function(String value) isMeaningful,
  }) {
    final candidates = _buildDistinctCandidates<String>(
      buddies,
      getValue,
      equals: (a, b) => a == b,
    );
    textCandidates[key] = candidates;
    fieldIndices[key] = _firstMeaningfulIndex(candidates, isMeaningful);
    controller.text = candidates[fieldIndices[key] ?? 0].value;
  }

  List<MergeFieldCandidate<T>> _buildDistinctCandidates<T>(
    List<Buddy> buddies,
    T Function(Buddy buddy) getValue, {
    required bool Function(T a, T b) equals,
  }) {
    final candidates = <MergeFieldCandidate<T>>[];
    for (final buddy in buddies) {
      final value = getValue(buddy);
      final alreadyIncluded = candidates.any(
        (candidate) => equals(candidate.value, value),
      );
      if (!alreadyIncluded) {
        candidates.add(
          MergeFieldCandidate(
            buddyId: buddy.id,
            buddyName: buddy.name,
            value: value,
          ),
        );
      }
    }
    return candidates;
  }

  int _firstMeaningfulIndex<T>(
    List<MergeFieldCandidate<T>> candidates,
    bool Function(T value) isMeaningful,
  ) {
    final index = candidates.indexWhere(
      (candidate) => isMeaningful(candidate.value),
    );
    return index >= 0 ? index : 0;
  }

  /// Select a specific text field candidate by index.
  void selectTextFieldCandidate(
    String key,
    int index, {
    required TextEditingController controller,
  }) {
    final candidates = textCandidates[key];
    if (candidates == null || index < 0 || index >= candidates.length) return;
    fieldIndices[key] = index;
    controller.text = candidates[index].value;
  }

  /// Cycle to the next text field candidate.
  void cycleTextField(String key, {required TextEditingController controller}) {
    final candidates = textCandidates[key];
    if (candidates == null || candidates.length < 2) return;
    final nextIndex = ((fieldIndices[key] ?? 0) + 1) % candidates.length;
    selectTextFieldCandidate(key, nextIndex, controller: controller);
  }
}
