import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/certifications/data/services/certification_edit_save_service.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The certification the page shows, as stored: PADI Open Water, with a
/// card number and no instructor, photos or notes.
final openWater = Certification(
  id: 'c1',
  diverId: 'd1',
  name: '',
  agency: 'padi',
  level: 'openWater',
  cardNumber: '123',
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

/// Records each save the page asks for, stores its result where the page
/// reads the certification from, and can fail.
class FakeCertificationSave implements CertificationEditSaveService {
  FakeCertificationSave(this.stored);

  final StateController<Certification?> stored;

  final calls = <({Certification after, Set<String> cards})>[];
  bool fail = false;

  /// Whether to run the held writes a save is given, as the real one does
  /// inside its transaction.
  bool runHeld = true;

  /// Holds the write until completed.
  Completer<void>? gate;

  @override
  Future<({Certification before, Certification after})?> save({
    required String certificationId,
    required Certification Function(Certification stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (fail) throw StateError('the save failed');
    await gate?.future;
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
  }

  /// Each new certification the page asked to create, failed ones included.
  final creates = <({Certification certification, Set<String> cards})>[];

  @override
  Future<Certification> create({
    required Certification certification,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    creates.add((certification: certification, cards: changedCardIds.toSet()));
    if (fail) throw StateError('the create failed');
    if (runHeld) await alsoWrite?.call();
    return certification;
  }
}

class CertificationPageHarness {
  CertificationPageHarness(this.save, this.stored);

  final FakeCertificationSave save;
  final StateController<Certification?> stored;
}

final _storedProvider = StateProvider<Certification?>((ref) => openWater);

/// Pumps the certification page, at phone width, or as the list's pane when
/// [embedded].
Future<CertificationPageHarness> pumpCertificationPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Certification? certification,
  bool openUnlocked = false,
  bool embedded = false,
  Size size = const Size(600, 1400),
  VoidCallback? onSittingEnded,
  List<Object> extraOverrides = const [],
}) async {
  final shown = certification ?? openWater;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  late CertificationPageHarness harness;
  final page = CertificationDetailPage(
    certificationId: shown.id,
    openUnlocked: openUnlocked,
    embedded: embedded,
    onSittingEnded: onSittingEnded,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => shown),
        certificationByIdProvider(
          shown.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        courseForCertificationProvider(
          shown.id,
        ).overrideWith((ref) async => null),
        certificationEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeCertificationSave(
            ref.watch(_storedProvider.notifier),
          );
          harness = CertificationPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
          );
          return save;
        }),
        ...extraOverrides,
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: embedded ? Scaffold(body: page) : page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CertificationDetailPage)),
  );
  container.read(certificationEditSaveServiceProvider);
  return harness;
}

/// What a test of a new certification's page pumped: the fake save, and
/// how the page ended.
class NewCertificationHarness {
  late FakeCertificationSave save;
  Object? popped;
  bool poppedAtAll = false;
  final createdIds = <String>[];
}

/// Pumps a new certification's page (issue #4527, phase 3, plan 11): a
/// full page pushed over a launcher, or the pane's ([embedded]). Needs the
/// test database: the cards read nothing for an id not stored.
Future<NewCertificationHarness> pumpNewCertificationPage(
  WidgetTester tester, {
  bool embedded = false,
  Brightness brightness = Brightness.light,
  Size size = const Size(600, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final harness = NewCertificationHarness();
  final page = CertificationDetailPage.newCertification(
    embedded: embedded,
    onCreated: harness.createdIds.add,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        certificationEditSaveServiceProvider.overrideWith(
          (ref) => harness.save = FakeCertificationSave(
            ref.watch(_storedProvider.notifier),
          ),
        ),
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: embedded
            ? Scaffold(body: page)
            : Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final result = await Navigator.of(
                        context,
                      ).push(MaterialPageRoute<Object?>(builder: (_) => page));
                      harness
                        ..poppedAtAll = true
                        ..popped = result;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
      ),
    ),
  );
  if (!embedded) await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(CertificationDetailPage)),
  ).read(certificationEditSaveServiceProvider);
  return harness;
}
