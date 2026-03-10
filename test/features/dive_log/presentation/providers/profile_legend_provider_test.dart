import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';

void main() {
  group('ProfileLegendState', () {
    group('sectionExpanded', () {
      test('defaults to expected initial values', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['overlays'], true);
        expect(state.sectionExpanded['decompression'], true);
        expect(state.sectionExpanded['markers'], false);
        expect(state.sectionExpanded['gasAnalysis'], false);
        expect(state.sectionExpanded['other'], false);
        expect(state.sectionExpanded['tankPressures'], true);
      });

      test('copyWith preserves sectionExpanded', () {
        const state = ProfileLegendState();
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'markers': true},
        );
        expect(updated.sectionExpanded['markers'], true);
        expect(updated.sectionExpanded['overlays'], true);
      });

      test('equality includes sectionExpanded', () {
        const state1 = ProfileLegendState();
        final state2 = state1.copyWith(
          sectionExpanded: {...state1.sectionExpanded, 'markers': true},
        );
        expect(state1, isNot(equals(state2)));
      });
    });
  });

  group('ProfileLegend notifier methods (via state)', () {
    group('explicit source set methods', () {
      test('setCeilingSource sets to computer', () {
        const state = ProfileLegendState();
        expect(state.ceilingSource, MetricDataSource.calculated);
        final updated = state.copyWith(
          ceilingSource: MetricDataSource.computer,
        );
        expect(updated.ceilingSource, MetricDataSource.computer);
      });

      test('setNdlSource sets to computer', () {
        const state = ProfileLegendState();
        expect(state.ndlSource, MetricDataSource.calculated);
        final updated = state.copyWith(ndlSource: MetricDataSource.computer);
        expect(updated.ndlSource, MetricDataSource.computer);
      });
    });

    group('toggleSection', () {
      test('toggles a collapsed section to expanded', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['markers'], false);
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'markers': true},
        );
        expect(updated.sectionExpanded['markers'], true);
      });

      test('toggles an expanded section to collapsed', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['overlays'], true);
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'overlays': false},
        );
        expect(updated.sectionExpanded['overlays'], false);
      });
    });
  });
}
