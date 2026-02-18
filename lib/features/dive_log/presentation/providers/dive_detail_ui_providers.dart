import 'package:submersion/core/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Keys for dive detail page UI preferences stored in SharedPreferences
class DiveDetailUiKeys {
  static const String decoSectionExpanded = 'dive_detail_deco_expanded';
  static const String o2ToxicitySectionExpanded =
      'dive_detail_o2_toxicity_expanded';
  static const String sacSegmentsSectionExpanded =
      'dive_detail_sac_segments_expanded';
  static const String equipmentSectionExpanded =
      'dive_detail_equipment_expanded';
  static const String tideSectionExpanded = 'dive_detail_tide_expanded';
}

/// State class for collapsible section preferences
class CollapsibleSectionState {
  final bool decoExpanded;
  final bool o2ToxicityExpanded;
  final bool sacSegmentsExpanded;
  final bool equipmentExpanded;
  final bool tideExpanded;

  const CollapsibleSectionState({
    this.decoExpanded = false,
    this.o2ToxicityExpanded = false,
    this.sacSegmentsExpanded = true,
    this.equipmentExpanded = true,
    this.tideExpanded = true,
  });

  CollapsibleSectionState copyWith({
    bool? decoExpanded,
    bool? o2ToxicityExpanded,
    bool? sacSegmentsExpanded,
    bool? equipmentExpanded,
    bool? tideExpanded,
  }) {
    return CollapsibleSectionState(
      decoExpanded: decoExpanded ?? this.decoExpanded,
      o2ToxicityExpanded: o2ToxicityExpanded ?? this.o2ToxicityExpanded,
      sacSegmentsExpanded: sacSegmentsExpanded ?? this.sacSegmentsExpanded,
      equipmentExpanded: equipmentExpanded ?? this.equipmentExpanded,
      tideExpanded: tideExpanded ?? this.tideExpanded,
    );
  }
}

/// Notifier for managing collapsible section state with persistence
class CollapsibleSectionNotifier
    extends StateNotifier<CollapsibleSectionState> {
  final SharedPreferences _prefs;

  CollapsibleSectionNotifier(this._prefs)
    : super(const CollapsibleSectionState()) {
    _loadState();
  }

  void _loadState() {
    state = CollapsibleSectionState(
      decoExpanded:
          _prefs.getBool(DiveDetailUiKeys.decoSectionExpanded) ?? false,
      o2ToxicityExpanded:
          _prefs.getBool(DiveDetailUiKeys.o2ToxicitySectionExpanded) ?? false,
      sacSegmentsExpanded:
          _prefs.getBool(DiveDetailUiKeys.sacSegmentsSectionExpanded) ?? true,
      equipmentExpanded:
          _prefs.getBool(DiveDetailUiKeys.equipmentSectionExpanded) ?? true,
      tideExpanded:
          _prefs.getBool(DiveDetailUiKeys.tideSectionExpanded) ?? true,
    );
  }

  Future<void> setDecoExpanded(bool expanded) async {
    state = state.copyWith(decoExpanded: expanded);
    await _prefs.setBool(DiveDetailUiKeys.decoSectionExpanded, expanded);
  }

  Future<void> setO2ToxicityExpanded(bool expanded) async {
    state = state.copyWith(o2ToxicityExpanded: expanded);
    await _prefs.setBool(DiveDetailUiKeys.o2ToxicitySectionExpanded, expanded);
  }

  Future<void> setSacSegmentsExpanded(bool expanded) async {
    state = state.copyWith(sacSegmentsExpanded: expanded);
    await _prefs.setBool(DiveDetailUiKeys.sacSegmentsSectionExpanded, expanded);
  }

  Future<void> setEquipmentExpanded(bool expanded) async {
    state = state.copyWith(equipmentExpanded: expanded);
    await _prefs.setBool(DiveDetailUiKeys.equipmentSectionExpanded, expanded);
  }

  Future<void> setTideExpanded(bool expanded) async {
    state = state.copyWith(tideExpanded: expanded);
    await _prefs.setBool(DiveDetailUiKeys.tideSectionExpanded, expanded);
  }
}

/// Provider for collapsible section state
final collapsibleSectionProvider =
    StateNotifierProvider<CollapsibleSectionNotifier, CollapsibleSectionState>((
      ref,
    ) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return CollapsibleSectionNotifier(prefs);
    });

/// Convenience providers for individual section states
final decoSectionExpandedProvider = Provider<bool>((ref) {
  return ref.watch(collapsibleSectionProvider.select((s) => s.decoExpanded));
});

final o2ToxicitySectionExpandedProvider = Provider<bool>((ref) {
  return ref.watch(
    collapsibleSectionProvider.select((s) => s.o2ToxicityExpanded),
  );
});

final sacSegmentsSectionExpandedProvider = Provider<bool>((ref) {
  return ref.watch(
    collapsibleSectionProvider.select((s) => s.sacSegmentsExpanded),
  );
});

final equipmentSectionExpandedProvider = Provider<bool>((ref) {
  return ref.watch(
    collapsibleSectionProvider.select((s) => s.equipmentExpanded),
  );
});

final tideSectionExpandedProvider = Provider<bool>((ref) {
  return ref.watch(collapsibleSectionProvider.select((s) => s.tideExpanded));
});
