import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskhub/map_page.dart';
import 'package:taskhub/university_map_data.dart';

void main() {
  test('every searchable room is backed by an original plan shape', () {
    final catalog = MapCatalog.fromJson(
      File('assets/map/aitu_rooms.json').readAsStringSync(),
    );
    expect(catalog.floors, hasLength(12));
    expect(catalog.blocksFor('C1'), [0, 1, 2, 3]);
    expect(catalog.floorsFor('C1', 2), [1, 2, 3]);
    for (final plan in catalog.floors) {
      expect(
        File(
          'assets/map/svg/C1_${plan.block == 0 ? 'all' : plan.block}_${plan.floor}.svg',
        ).existsSync(),
        isTrue,
      );
      for (final room in plan.rooms) {
        expect(room.outline.length, greaterThanOrEqualTo(3));
        if (plan.block != 0) {
          expect(room.block, plan.block);
          expect(room.floor, plan.floor);
        }
      }
    }
    final room = catalog.exact('  с1. 2. 346 ');
    expect(room, isNotNull);
    expect(room!.number, 'C1.2.346');
    expect(catalog.plan('C1', 2, 3).rooms, contains(room));
    expect(
      catalog.search('346').map((room) => room.number),
      contains('C1.2.346'),
    );
    expect(catalog.exact('C1.2.345'), isNull);
  });

  testWidgets('search changes plan and keeps the selected room visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = MapCatalog.fromJson(
      File('assets/map/aitu_rooms.json').readAsStringSync(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MapPage(catalog: catalog)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'с1.2.346');
    await tester.pumpAndSettle();
    expect(find.text('C1.2.346'), findsOneWidget);
    await tester.tap(find.text('C1.2.346'));
    await tester.pumpAndSettle();
    expect(find.text('Здание C1 · корпус 2 · этаж 3'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('C1.2.346')),
      findsOneWidget,
    );
    final room = catalog.exact('C1.2.346')!;
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final point = MatrixUtils.transformPoint(
      viewer.transformationController!.value,
      room.bounds.center,
    );
    expect(point.dx, closeTo(195, 1));
    expect(point.dy, closeTo(422, 1));

    await tester.enterText(find.byType(TextField), 'C1.2.345');
    await tester.pumpAndSettle();
    expect(find.text('Кабинет не найден'), findsOneWidget);
  });
}
