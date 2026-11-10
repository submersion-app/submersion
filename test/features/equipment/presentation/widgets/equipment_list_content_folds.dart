part of 'equipment_list_content_test.dart';

/// The Equipment list's foldable groups (issue #4184): folding and saving,
/// the reveal of an item opened from outside the list, filters, the
/// keyboard and the overflow menu.
void _foldableGroupTests() {
  group('foldable groups (#4184)', () {
    EquipmentLocation place(String id, String name) => EquipmentLocation(
      id: id,
      name: name,
      kind: EquipmentLocationKind.storage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final garage = place('garage', 'Garage');
    final locker = place('locker', 'Locker');

    final gear = [
      _makeEquipment(id: 'bcd0', name: 'BCD A', type: EquipmentType.bcd),
      _makeEquipment(id: 'bcd1', name: 'BCD B', type: EquipmentType.bcd),
      _makeEquipment(id: 'reg0', name: 'Reg A', type: EquipmentType.regulator),
      _makeEquipment(id: 'reg1', name: 'Reg B', type: EquipmentType.regulator),
    ];
    final places = {
      'bcd0': garage,
      'reg0': garage,
      'bcd1': locker,
      'reg1': locker,
    };

    late MockSettingsNotifier settings;

    Future<void> pumpList(
      WidgetTester tester, {
      bool groupByLocation = true,
      String? saved,
      String? selectedId,
      String? highlightedId,
      SelectionController? selection,
      EquipmentFilterState? filter,
      List<EquipmentItem>? items,
      EquipmentArrangement? arrangement,
      Map<String, ServiceClockStatus>? urgency,
      Size size = const Size(800, 1600),
      bool showAppBar = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      settings = MockSettingsNotifier(
        AppSettings(
          listArrangements: ListArrangements(equipmentCollapsedGroups: saved),
        ),
      );
      final overrides = await _buildPhoneOverrides(
        items: items ?? gear,
        highlightedEquipmentId: highlightedId,
        arrangement: arrangement,
        filter: filter,
        settings: settings,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            equipmentGroupByLocationProvider.overrideWith(
              (ref) async => groupByLocation,
            ),
            currentEquipmentLocationsProvider.overrideWith(
              (ref) async => places,
            ),
            if (urgency != null)
              equipmentServiceUrgencyProvider.overrideWith(
                (ref) async => urgency,
              ),
          ],
          child: EquipmentListContent(
            showAppBar: showAppBar,
            selectedId: selectedId,
            selectionController: selection,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(EquipmentListContent)),
        );

    List<String> rowNames(WidgetTester tester) => tester
        .widgetList<EquipmentListTile>(find.byType(EquipmentListTile))
        .map((t) => t.item.name)
        .toList();

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
    }

    String? stored() =>
        settings.state.listArrangements.equipmentCollapsedGroups;

    Finder placeHeader(String id) =>
        find.byKey(ValueKey('equipment-location-header-$id'));

    Finder typeHeader(String foldKey) =>
        find.byKey(ValueKey('equipment-type-fold-$foldKey'));

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

    testWidgets('tapping a location header folds it and saves', (tester) async {
      await pumpList(tester);
      expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B', 'Reg B']);

      await tester.tap(placeHeader('garage'));
      await tester.pumpAndSettle();

      expect(rowNames(tester), ['BCD B', 'Reg B']);
      expect(stored(), '["loc:garage"]');
      expect(find.text('BCD 1 · Regulator 1'), findsOneWidget);
    });

    testWidgets('saved folds apply on open', (tester) async {
      await pumpList(tester, saved: '["loc:garage"]');
      expect(rowNames(tester), ['BCD B', 'Reg B']);
    });

    testWidgets('nested type header folds alone', (tester) async {
      await pumpList(tester);
      await tester.tap(typeHeader('loc:locker/type:bcd'));
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['BCD A', 'Reg A', 'Reg B']);
      expect(stored(), '["loc:locker/type:bcd"]');
    });

    testWidgets('location headers are bold', (tester) async {
      await pumpList(tester);
      final title = tester.widget<Text>(find.text('Garage'));
      expect(title.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('an active filter opens every group and saves nothing', (
      tester,
    ) async {
      await pumpList(
        tester,
        saved: '["loc:garage"]',
        filter: const EquipmentFilterState(status: EquipmentStatus.active),
      );
      expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B', 'Reg B']);

      await tester.tap(placeHeader('locker'));
      await tester.pumpAndSettle();

      expect(rowNames(tester), ['BCD A', 'Reg A']);
      expect(stored(), '["loc:garage"]');
    });

    testWidgets('switching group by location keeps the saved keys', (
      tester,
    ) async {
      await pumpList(tester, saved: '["loc:garage","type:bcd"]');
      expect(rowNames(tester), ['BCD B', 'Reg B']);

      // A fresh scope, so the new grouping override takes effect.
      await tester.pumpWidget(const SizedBox());
      await pumpList(
        tester,
        saved: '["loc:garage","type:bcd"]',
        groupByLocation: false,
      );
      expect(rowNames(tester), ['Reg A', 'Reg B']);
    });

    testWidgets('a deep link reveals a folded item without writing settings', (
      tester,
    ) async {
      await pumpList(tester, saved: '["loc:garage"]', selectedId: 'reg0');
      expect(rowNames(tester), contains('Reg A'));
      expect(stored(), '["loc:garage"]');
    });

    testWidgets("folding the selected item's group sticks", (tester) async {
      await pumpList(tester, saved: '["loc:garage"]', selectedId: 'reg0');
      expect(rowNames(tester), contains('Reg A'));

      await tester.tap(placeHeader('garage'));
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['BCD B', 'Reg B']);
      // Folding a revealed group writes nothing: it was already folded.
      expect(stored(), '["loc:garage"]');

      containerOf(tester).read(highlightedEquipmentIdProvider.notifier).state =
          'reg1';
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['BCD B', 'Reg B']);
    });

    /// Master-detail: a row tap selects it, and the page hands the
    /// selection back as selectedId.
    Future<ValueNotifier<String?>> pumpDesktop(
      WidgetTester tester, {
      String? saved,
      String? initial,
      EquipmentFilterState? filter,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      settings = MockSettingsNotifier(
        AppSettings(
          listArrangements: ListArrangements(equipmentCollapsedGroups: saved),
        ),
      );
      final selected = ValueNotifier<String?>(initial);
      addTearDown(selected.dispose);
      final overrides = await _buildPhoneOverrides(
        items: gear,
        settings: settings,
        filter: filter,
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            equipmentGroupByLocationProvider.overrideWith((ref) async => true),
            currentEquipmentLocationsProvider.overrideWith(
              (ref) async => places,
            ),
          ],
          child: ValueListenableBuilder<String?>(
            valueListenable: selected,
            builder: (context, id, _) => EquipmentListContent(
              showAppBar: false,
              selectedId: id,
              onItemSelected: (next) => selected.value = next,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return selected;
    }

    testWidgets('a tap in the list keeps an earlier reveal open', (
      tester,
    ) async {
      await pumpDesktop(tester, saved: '["loc:garage"]', initial: 'reg0');
      expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B', 'Reg B']);

      await tester.tap(find.text('Reg B'));
      await tester.pumpAndSettle();

      // The garage stays open, so no row moves under the pointer.
      expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B', 'Reg B']);
    });

    testWidgets('folds that land after the reveal still leave the item shown', (
      tester,
    ) async {
      await pumpList(tester, groupByLocation: false, selectedId: 'reg0');
      expect(rowNames(tester), contains('Reg A'));

      settings.state = settings.state.copyWith(
        listArrangements: const ListArrangements(
          equipmentCollapsedGroups: '["type:regulator"]',
        ),
      );
      await tester.pumpAndSettle();

      expect(rowNames(tester), contains('Reg A'));
      // Opened for this visit only: the fold stays saved.
      expect(stored(), '["type:regulator"]');
    });

    testWidgets('clearing a filter keeps a fold the diver made before it', (
      tester,
    ) async {
      await pumpDesktop(tester);
      await tester.tap(find.text('Reg A'));
      await tester.pumpAndSettle();
      await tester.tap(placeHeader('garage'));
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['BCD B', 'Reg B']);

      final filter = containerOf(tester).read(equipmentFilterProvider.notifier);
      filter.state = const EquipmentFilterState(status: EquipmentStatus.active);
      await tester.pumpAndSettle();
      filter.state = const EquipmentFilterState();
      await tester.pumpAndSettle();

      expect(rowNames(tester), ['BCD B', 'Reg B']);
    });

    testWidgets('clearing a filter reveals the item opened during it', (
      tester,
    ) async {
      await pumpDesktop(
        tester,
        saved: '["loc:garage"]',
        filter: const EquipmentFilterState(status: EquipmentStatus.active),
      );
      await tester.tap(find.text('Reg A'));
      await tester.pumpAndSettle();

      containerOf(tester).read(equipmentFilterProvider.notifier).state =
          const EquipmentFilterState();
      await tester.pumpAndSettle();

      expect(rowNames(tester), contains('Reg A'));
      expect(stored(), '["loc:garage"]');
    });

    testWidgets('keyboard: Left on an item folds its group, Right opens it', (
      tester,
    ) async {
      await pumpList(tester, highlightedId: 'reg1');
      await focusList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B']);
      expect(stored(), '["loc:locker/type:regulator"]');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B', 'Reg B']);
    });

    testWidgets('keyboard: Enter on a header toggles it', (tester) async {
      await pumpList(tester, highlightedId: 'reg1');
      await focusList(tester);
      // Left from the item lands on its header and folds it; Enter opens it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B', 'Reg B']);
    });

    testWidgets('a shift-click range across a folded group skips its items', (
      tester,
    ) async {
      final selection = SelectionController();
      addTearDown(selection.dispose);
      // Canonical order: regulator, BCD (folded), mask, fins.
      await pumpList(
        tester,
        groupByLocation: false,
        saved: '["type:bcd"]',
        selection: selection,
        items: [
          _makeEquipment(id: 'r', name: 'Apeks', type: EquipmentType.regulator),
          _makeEquipment(id: 'b', name: 'Wing', type: EquipmentType.bcd),
          _makeEquipment(id: 'm', name: 'Cressi', type: EquipmentType.mask),
          _makeEquipment(id: 'f', name: 'Jets', type: EquipmentType.fins),
        ],
      );
      selection.enterExplicit();
      selection.toggle('r');
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Jets'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // The range takes the visible mask between them, not the folded BCD.
      expect(selection.value.checkedIds, {'r', 'm', 'f'});
    });

    testWidgets('folded header shows N of M selected in selection mode', (
      tester,
    ) async {
      final selection = SelectionController();
      addTearDown(selection.dispose);
      await pumpList(tester, saved: '["loc:garage"]', selection: selection);

      selection.enterExplicit();
      selection.selectAll(['bcd0', 'bcd1']);
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 selected'), findsOneWidget);
    });

    testWidgets('type header shows service due when folded', (tester) async {
      final t0 = DateTime(2026);
      final due = ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-bcd0',
          equipmentId: 'bcd0',
          serviceKindId: 'annual',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'annual',
          name: 'Annual service',
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        severity: ServiceClockSeverity.dueSoon,
        now: DateTime.now(),
      );
      await pumpList(
        tester,
        groupByLocation: false,
        saved: '["type:bcd"]',
        urgency: {'bcd0': due},
      );
      expect(find.text('1 service due'), findsOneWidget);
    });

    testWidgets('type grouping off leaves place folds working', (tester) async {
      await pumpList(
        tester,
        saved: '["loc:locker"]',
        arrangement: EquipmentArrangement.defaults.copyWith(groupByType: false),
      );
      expect(find.byType(EquipmentTypeFoldHeader), findsNothing);
      expect(rowNames(tester), ['BCD A', 'Reg A']);
    });

    for (final showAppBar in [false, true]) {
      final where = showAppBar ? 'app bar' : 'pane header';

      testWidgets('the $where menu offers expand and collapse all', (
        tester,
      ) async {
        await pumpList(tester, showAppBar: showAppBar);
        await openMenu(tester);
        expect(find.text('Expand all'), findsOneWidget);
        expect(find.text('Collapse all'), findsOneWidget);
      });

      testWidgets('collapse all from the $where folds every place', (
        tester,
      ) async {
        await pumpList(tester, showAppBar: showAppBar);
        await openMenu(tester);
        await tester.tap(find.text('Collapse all'));
        await tester.pumpAndSettle();

        expect(rowNames(tester), isEmpty);
        expect(find.text('BCD 1 · Regulator 1'), findsNWidgets(2));
        expect(stored(), '["loc:garage","loc:locker"]');
      });

      testWidgets('expand all from the $where opens everything', (
        tester,
      ) async {
        await pumpList(
          tester,
          showAppBar: showAppBar,
          saved: '["loc:garage","loc:locker/type:bcd"]',
        );
        await openMenu(tester);
        await tester.tap(find.text('Expand all'));
        await tester.pumpAndSettle();

        expect(rowNames(tester), ['BCD A', 'Reg A', 'BCD B', 'Reg B']);
        expect(stored(), '[]');
      });
    }

    // A diver switch can leave the page with no gear while it stays open, or
    // land on a freshly built list (a layout swap); either way the menu must
    // not offer to fold the previous list's places.
    for (final fresh in [false, true]) {
      testWidgets(
        fresh
            ? 'no fold entries in a fresh list that has no gear'
            : 'no fold entries once the list empties',
        (tester) async {
          final instance = ValueNotifier<int>(0);
          addTearDown(instance.dispose);
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          settings = MockSettingsNotifier();
          await tester.pumpWidget(
            testApp(
              locale: const Locale('en'),
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                settingsProvider.overrideWith((ref) => settings),
                currentDiverIdProvider.overrideWith(
                  (ref) => MockCurrentDiverIdNotifier(),
                ),
                _visibleEquipmentProvider.overrideWith((ref) => gear),
                equipmentByStatusProvider.overrideWith(
                  (ref, status) => ref.watch(_visibleEquipmentProvider),
                ),
                activeEquipmentProvider.overrideWith(
                  (ref) async => ref.watch(_visibleEquipmentProvider),
                ),
                allEquipmentProvider.overrideWith(
                  (ref) async => ref.watch(_visibleEquipmentProvider),
                ),
                fakeEquipmentQueryIds(),
                equipmentListViewModeProvider.overrideWith(
                  (ref) => ListViewMode.detailed,
                ),
                equipmentGroupByLocationProvider.overrideWith(
                  (ref) async => true,
                ),
                currentEquipmentLocationsProvider.overrideWith(
                  (ref) async => places,
                ),
              ],
              child: ValueListenableBuilder<int>(
                valueListenable: instance,
                builder: (context, n, _) =>
                    EquipmentListContent(key: ValueKey(n), showAppBar: false),
              ),
            ),
          );
          await tester.pumpAndSettle();
          containerOf(tester).read(_visibleEquipmentProvider.notifier).state =
              const [];
          if (fresh) instance.value++;
          await tester.pumpAndSettle();

          await openMenu(tester);
          expect(find.text('Collapse all'), findsNothing);
        },
      );
    }

    testWidgets('no fold entries when the page shows no headings', (
      tester,
    ) async {
      await pumpList(
        tester,
        groupByLocation: false,
        arrangement: EquipmentArrangement.defaults.copyWith(groupByType: false),
      );
      await openMenu(tester);
      expect(find.text('Expand all'), findsNothing);
      expect(find.text('Collapse all'), findsNothing);
    });

    testWidgets(
      'scrolling to a row lands it fully in view below the headings',
      (tester) async {
        const types = [
          EquipmentType.bcd,
          EquipmentType.fins,
          EquipmentType.mask,
          EquipmentType.regulator,
          EquipmentType.wetsuit,
        ];
        await pumpList(
          tester,
          groupByLocation: false,
          size: const Size(800, 600),
          arrangement: const EquipmentArrangement(
            typeOrder: EquipmentTypeOrder.alphabetical,
            groupByType: true,
            itemSortField: EquipmentItemSortField.name,
            itemSortDirection: SortDirection.ascending,
          ),
          items: [
            for (final type in types)
              for (var i = 0; i < 5; i++)
                _makeEquipment(
                  id: '${type.name}$i',
                  name: '${type.name} $i',
                  type: type,
                ),
          ],
          selectedId: 'regulator0',
        );

        // The estimate lands near the row; once built it is settled fully in
        // view, whatever the real heights of the rows and headings above it.
        final list = tester.getRect(find.byType(Scrollable).first);
        final row = tester.getRect(find.text('regulator 0'));
        expect(row.top, greaterThanOrEqualTo(list.top));
        expect(row.bottom, lessThanOrEqualTo(list.bottom));
      },
    );

    testWidgets('a drag during the scroll to a selection is not undone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);
      final overrides = await _buildPhoneOverrides(
        items: [
          for (var i = 0; i < 120; i++)
            _makeEquipment(
              id: 'g$i',
              name: 'Gear ${i.toString().padLeft(3, '0')}',
            ),
        ],
        arrangement: EquipmentArrangement.defaults.copyWith(
          typeOrder: EquipmentTypeOrder.none,
        ),
      );
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: ValueListenableBuilder<String?>(
            valueListenable: selected,
            builder: (context, id, _) => EquipmentListContent(
              showAppBar: false,
              selectedId: id,
              onItemSelected: (next) => selected.value = next,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Opened from elsewhere, so the list animates towards the row; the
      // diver grabs the list early in the animation and drags it back.
      selected.value = 'g110';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Scrollable).first),
      );
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 100));
      await gesture.up();

      await tester.pumpAndSettle();

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(
        position.pixels,
        lessThan(3000),
        reason: 'the interrupted scroll must not pull the list back',
      );
      expect(find.text('Gear 110'), findsNothing);
    });
  });
}
