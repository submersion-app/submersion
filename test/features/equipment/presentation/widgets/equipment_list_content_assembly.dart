part of 'equipment_list_content_test.dart';

/// The Equipment list's assembly view (issue #5071): parts fold under their
/// assembly, folded by default, remembered when opened.
void _assemblyViewTests() {
  group('assembly view (#5071)', () {
    EquipmentItem item(
      String id,
      String name,
      EquipmentType type, {
      String? host,
    }) =>
        EquipmentItem(id: id, name: name, type: type, parentEquipmentId: host);

    final sf2 = item('sf2', 'SF2', EquipmentType.rebreather);
    final cells = [
      for (var i = 1; i <= 3; i++)
        item('c$i', 'Cell $i', EquipmentType.o2Cell, host: 'sf2'),
    ];
    final fins = item('fins', 'Fins', EquipmentType.fins);
    final rig = [sf2, ...cells, fins];

    late MockSettingsNotifier settings;

    Future<void> pumpList(
      WidgetTester tester, {
      List<EquipmentItem>? items,
      List<EquipmentComponent> edges = const [],
      String? saved,
      String? selectedId,
      String? highlightedId,
      EquipmentFilterState? filter,
      EquipmentArrangement? arrangement,
      ListViewMode viewMode = ListViewMode.detailed,
      ValueNotifier<String?>? selected,
      EquipmentArrangement? storedArrangement,
      Future<ComponentsIndex>? index,
      List<Override> extra = const [],
      SelectionController? selection,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      settings = MockSettingsNotifier(
        AppSettings(
          listArrangements: ListArrangements(
            equipmentCollapsedGroups: saved,
            equipmentArrangement: storedArrangement == null
                ? null
                : encodeEquipmentArrangement(storedArrangement),
          ),
        ),
      );
      final overrides = await _buildPhoneOverrides(
        items: items ?? rig,
        highlightedEquipmentId: highlightedId,
        arrangement: arrangement,
        filter: filter,
        settings: settings,
        viewMode: viewMode,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            equipmentGroupByLocationProvider.overrideWith((ref) async => false),
            currentEquipmentLocationsProvider.overrideWith(
              (ref) async => const <String, EquipmentLocation>{},
            ),
            equipmentComponentsIndexProvider.overrideWith(
              (ref) => index ?? Future.value(ComponentsIndex.fromRows(edges)),
            ),
            ...extra,
          ],
          child: EquipmentListContent(
            showAppBar: false,
            selectedId: selectedId,
            selectionController: selection,
            onItemSelected: selected == null
                ? null
                : (next) => selected.value = next,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<String> rowNames(WidgetTester tester) => tester
        .widgetList<EquipmentListTile>(find.byType(EquipmentListTile))
        .map((t) => t.item.name)
        .toList();

    String? stored() =>
        settings.state.listArrangements.equipmentCollapsedGroups;

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(EquipmentListContent)),
        );

    Future<void> focusList(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        if (FocusManager.instance.primaryFocus?.debugLabel ==
            KeyboardListNavigator.focusDebugLabel) {
          return;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
    }

    EquipmentComponent edge(String parent, String part) => EquipmentComponent(
      id: '$parent-$part',
      parentEquipmentId: parent,
      componentEquipmentId: part,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    testWidgets('assemblies start folded and their parts leave their type', (
      tester,
    ) async {
      await pumpList(tester);
      expect(rowNames(tester), ['Fins', 'SF2']);
      expect(find.byTooltip('Show parts'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('equipment-type-fold-type:o2Cell')),
        findsNothing,
      );
    });

    testWidgets('the chevron opens an assembly and remembers it', (
      tester,
    ) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      await pumpList(tester, selected: selected);

      await tester.tap(find.byTooltip('Show parts'));
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2', 'Cell 1', 'Cell 2', 'Cell 3']);
      expect(stored(), '["asm:sf2"]');
      expect(find.byTooltip('Hide parts'), findsOneWidget);
      expect(selected.value, isNull);

      await tester.tap(find.text('SF2'));
      await tester.pumpAndSettle();
      expect(selected.value, 'sf2');
    });

    testWidgets('with the switch off the list is flat', (tester) async {
      await pumpList(
        tester,
        arrangement: EquipmentArrangement.defaults.copyWith(nestParts: false),
      );
      expect(rowNames(tester), ['Fins', 'Cell 1', 'Cell 2', 'Cell 3', 'SF2']);
      expect(find.byTooltip('Show parts'), findsNothing);
    });

    testWidgets('table mode never nests', (tester) async {
      await pumpList(tester, viewMode: ListViewMode.table);
      expect(find.text('Cell 1'), findsOneWidget);
      expect(find.byTooltip('Show parts'), findsNothing);
    });

    testWidgets('an inventory with no parts shows no chevrons', (tester) async {
      final plain = [fins, item('mask', 'Mask', EquipmentType.mask)];
      await pumpList(tester, items: plain);
      expect(rowNames(tester), ['Fins', 'Mask']);
      expect(find.byTooltip('Show parts'), findsNothing);
      expect(find.byType(AssemblyRowFrame), findsNothing);
    });

    testWidgets('a filter opens every assembly and saves nothing', (
      tester,
    ) async {
      await pumpList(
        tester,
        filter: const EquipmentFilterState(status: EquipmentStatus.active),
      );
      expect(rowNames(tester), ['Fins', 'SF2', 'Cell 1', 'Cell 2', 'Cell 3']);

      await tester.tap(find.byTooltip('Hide parts'));
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2']);
      expect(stored(), isNull);

      containerOf(tester).read(equipmentFilterProvider.notifier).state =
          const EquipmentFilterState();
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2']);
    });

    testWidgets('expand and collapse all reach assemblies with no headings', (
      tester,
    ) async {
      await pumpList(
        tester,
        arrangement: EquipmentArrangement.defaults.copyWith(groupByType: false),
      );
      expect(rowNames(tester), ['Fins', 'SF2']);

      await openMenu(tester);
      await tester.tap(find.text('Expand all'));
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2', 'Cell 1', 'Cell 2', 'Cell 3']);
      expect(stored(), '["asm:sf2"]');

      await openMenu(tester);
      await tester.tap(find.text('Collapse all'));
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2']);
      expect(stored(), '[]');
    });

    testWidgets('opening a part from outside opens its assembly unsaved', (
      tester,
    ) async {
      await pumpList(tester, selectedId: 'c2');
      expect(rowNames(tester), ['Fins', 'SF2', 'Cell 1', 'Cell 2', 'Cell 3']);
      expect(stored(), isNull);
    });

    testWidgets('keyboard: Right opens, Left folds, Left on a part climbs', (
      tester,
    ) async {
      await pumpList(tester, highlightedId: 'sf2');
      await focusList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2', 'Cell 1', 'Cell 2', 'Cell 3']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(containerOf(tester).read(highlightedEquipmentIdProvider), 'c1');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['Fins', 'SF2']);
      expect(stored(), '[]');
    });

    testWidgets('a shared part is reached twice and marked twice', (
      tester,
    ) async {
      final regA = item('regA', 'Reg A', EquipmentType.regulator);
      final regB = item('regB', 'Reg B', EquipmentType.regulator);
      final stage = item('s', 'Stage', EquipmentType.secondStage);
      await pumpList(
        tester,
        items: [regA, regB, stage],
        edges: [edge('regA', 's'), edge('regB', 's')],
        saved: '["asm:regA","asm:regB"]',
        highlightedId: 'regA',
      );
      expect(rowNames(tester), ['Reg A', 'Stage', 'Reg B', 'Stage']);
      await focusList(tester);

      final visited = <String?>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        visited.add(containerOf(tester).read(highlightedEquipmentIdProvider));
      }
      expect(visited, ['s', 'regB', 's']);

      final marked = tester
          .widgetList<EquipmentListTile>(find.byType(EquipmentListTile))
          .where((t) => t.isSelected)
          .map((t) => t.item.id);
      expect(marked, ['s', 's']);
    });

    group('review fixes', () {
      testWidgets('a folded heading counts a due part under an assembly', (
        tester,
      ) async {
        final t0 = DateTime(2026);
        final due = ServiceClockStatus(
          schedule: ServiceSchedule(
            id: 's-c1',
            equipmentId: 'c1',
            serviceKindId: 'cell',
            createdAt: t0,
            updatedAt: t0,
          ),
          kind: ServiceKind(
            id: 'cell',
            name: 'Cell replacement',
            createdAt: t0,
            updatedAt: t0,
          ),
          anchor: t0,
          dueDate: DateTime.now().subtract(const Duration(days: 5)),
          severity: ServiceClockSeverity.overdue,
          now: DateTime.now(),
        );
        await pumpList(
          tester,
          saved: '["type:rebreather"]',
          extra: [
            equipmentAssemblyRollupClockProvider.overrideWith(
              (ref) async => {
                'sf2': (ownerId: 'c1', ownerName: 'Cell 1', status: due),
              },
            ),
          ],
        );
        expect(rowNames(tester), ['Fins']);
        expect(find.text('1 service due'), findsOneWidget);
      });

      testWidgets('turning the view on keeps the open part in sight', (
        tester,
      ) async {
        await pumpList(
          tester,
          selectedId: 'c2',
          storedArrangement: EquipmentArrangement.defaults.copyWith(
            nestParts: false,
          ),
        );
        expect(rowNames(tester), contains('Cell 2'));

        settings.state = settings.state.copyWith(
          listArrangements: settings.state.listArrangements.copyWith(
            equipmentArrangement: encodeEquipmentArrangement(
              EquipmentArrangement.defaults,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Hide parts'), findsOneWidget);
        expect(rowNames(tester), contains('Cell 2'));
        expect(stored(), isNull);
      });

      testWidgets('the open part stays in sight when the index arrives', (
        tester,
      ) async {
        final travel = item('travel', 'Travel reg', EquipmentType.regulator);
        final first = item('fs', 'First stage', EquipmentType.firstStage);
        final index = Completer<ComponentsIndex>();
        await pumpList(
          tester,
          items: [travel, first],
          selectedId: 'fs',
          index: index.future,
        );
        expect(rowNames(tester), contains('First stage'));

        index.complete(ComponentsIndex.fromRows([edge('travel', 'fs')]));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Hide parts'), findsOneWidget);
        expect(rowNames(tester), ['Travel reg', 'First stage']);
      });

      testWidgets('the list scrolls back to the open part when it moves', (
        tester,
      ) async {
        final rigItem = item('rig', 'Rig', EquipmentType.backplate);
        final part = item('part', 'Part', EquipmentType.wing);
        final filler = [
          for (var i = 0; i < 40; i++)
            item(
              'f$i',
              'Fin ${i.toString().padLeft(2, '0')}',
              EquipmentType.fins,
            ),
        ];
        final index = Completer<ComponentsIndex>();
        await pumpList(
          tester,
          items: [rigItem, ...filler, part],
          selectedId: 'part',
          index: index.future,
        );
        expect(find.text('Part').hitTestable(), findsOneWidget);

        index.complete(ComponentsIndex.fromRows([edge('rig', 'part')]));
        await tester.pumpAndSettle();
        expect(find.text('Part').hitTestable(), findsOneWidget);
      });

      testWidgets('a folded heading counts a ticked part nested in it', (
        tester,
      ) async {
        final selection = SelectionController();
        addTearDown(selection.dispose);
        await pumpList(tester, saved: '["asm:sf2"]', selection: selection);
        selection.selectAll(['c1']);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('equipment-type-fold-type:rebreather')),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 of 4 selected'), findsOneWidget);
      });

      testWidgets('an assembly with no parts on the list keeps its count', (
        tester,
      ) async {
        final travel = item('travel', 'Travel reg', EquipmentType.regulator);
        await pumpList(
          tester,
          items: [travel],
          edges: [edge('travel', 'fs'), edge('travel', 'ss')],
        );
        expect(find.text('2 components'), findsOneWidget);
      });
    });
  });
}
