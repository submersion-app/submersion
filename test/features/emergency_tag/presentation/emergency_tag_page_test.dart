import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/emergency_tag/data/services/emergency_card_pdf_service.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/presentation/pages/emergency_tag_page.dart';
import 'package:submersion/features/emergency_tag/presentation/providers/emergency_tag_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  final diver = Diver(
    id: 'd1',
    name: 'Sam Diver',
    allergies: 'Penicillin',
    medicalNotes: 'Asthma as a child',
    emergencyContact: const EmergencyContact(
      name: 'Alex Diver',
      relation: 'Partner',
      phone: '+1 555 123 4567',
    ),
    insurance: const DiverInsurance(provider: 'DAN', emergencyPhone: '+1 919'),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  late List<EmergencyCardContent> printed;
  late List<EmergencyTagChoices> saved;

  Future<void> pump(WidgetTester tester) async {
    printed = [];
    saved = [];
    await tester.binding.setSurfaceSize(const Size(500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          // A desktop-like device: no NFC, so only printing is offered.
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
          currentDiverProvider.overrideWith((ref) async => diver),
          myEmergencyTagChoicesProvider.overrideWith(
            (ref) async => EmergencyTagChoices.defaults,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmergencyTagPage(
            export: (content, origin, localization) async =>
                printed.add(content),
            save: (ref, choices) async => saved.add(choices),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String preview(WidgetTester tester) => tester
      .widget<SelectableText>(find.byKey(const Key('emergencyTag_previewText')))
      .data!;

  testWidgets('previews the chosen details, most urgent first', (tester) async {
    await pump(tester);
    final text = preview(tester);
    expect(text, startsWith('EMERGENCY INFO\nName: Sam Diver\n'));
    expect(text, contains('Allergies: Penicillin'));
    expect(text, contains('Emergency contact: Alex Diver (Partner)'));
    expect(text, isNot(contains('Asthma')));
    expect(find.textContaining('bytes on the tag'), findsOneWidget);
  });

  testWidgets('a field with nothing recorded cannot be switched on', (
    tester,
  ) async {
    await pump(tester);
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('emergencyTag_field_bloodType')),
    );
    expect(tile.onChanged, isNull);
    expect(tile.value, isFalse);
  });

  testWidgets('switching a field on adds it to the preview', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('emergencyTag_field_medicalNotes')));
    await tester.pumpAndSettle();
    expect(preview(tester), contains('Medical notes: Asthma as a child'));
    expect(
      saved.single.fields.contains(EmergencyTagField.medicalNotes),
      isTrue,
    );
  });

  testWidgets('no NFC: no write button, and the card still prints', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('emergencyTag_write')), findsNothing);
    await tester.tap(find.byKey(const Key('emergencyTag_print')));
    await tester.pumpAndSettle();
    expect(printed, hasLength(1));
    expect(printed.single.lines.first, 'EMERGENCY INFO');
    expect(printed.single.qrData, startsWith('https://submersion.app/e#'));
  });

  testWidgets('a link tag can leave the text off; a call tag cannot', (
    tester,
  ) async {
    await pump(tester);
    final withText = find.textContaining('bytes on the tag');
    final before = tester.widget<Text>(withText).data!;
    await tester.tap(find.byKey(const Key('emergencyTag_includeText')));
    await tester.pumpAndSettle();
    expect(saved.last.includeText, isFalse);
    expect(tester.widget<Text>(withText).data, isNot(before));
    await tester.tap(find.byKey(const Key('emergencyTag_tapCall')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emergencyTag_includeText')), findsNothing);
  });

  testWidgets('a call tag prints the number it dials', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('emergencyTag_tapCall')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emergencyTag_callTarget')), findsOneWidget);
    await tester.tap(find.byKey(const Key('emergencyTag_print')));
    await tester.pumpAndSettle();
    expect(printed.single.qrData, 'tel:+15551234567');
  });
}
