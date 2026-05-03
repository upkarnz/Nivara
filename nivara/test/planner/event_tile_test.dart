import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/planner/domain/event.dart';
import 'package:nivara/features/planner/presentation/widgets/event_tile.dart';

Event _makeEvent({
  required EventSource source,
  String title = 'Test Event',
}) =>
    Event(
      id: 'id1',
      userId: 'uid1',
      title: title,
      startTime: DateTime(2026, 5, 4, 13, 0),
      endTime: DateTime(2026, 5, 4, 14, 0),
      source: source,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows event title', (tester) async {
    await tester
        .pumpWidget(_wrap(EventTile(event: _makeEvent(source: EventSource.local))));
    expect(find.text('Test Event'), findsOneWidget);
  });

  testWidgets('shows time string', (tester) async {
    await tester
        .pumpWidget(_wrap(EventTile(event: _makeEvent(source: EventSource.local))));
    expect(find.textContaining('1:00'), findsOneWidget);
  });

  testWidgets('local source shows purple left border color', (tester) async {
    await tester.pumpWidget(
      _wrap(EventTile(event: _makeEvent(source: EventSource.local))),
    );
    final container = tester.widget<Container>(
      find.byKey(const Key('event_tile_border')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, equals(const Color(0xFF7C6EF7)));
  });

  testWidgets('googleCalendar source shows blue left border', (tester) async {
    await tester.pumpWidget(
      _wrap(EventTile(event: _makeEvent(source: EventSource.googleCalendar))),
    );
    final container = tester.widget<Container>(
      find.byKey(const Key('event_tile_border')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, equals(const Color(0xFF4285F4)));
  });

  testWidgets('synced source shows green left border', (tester) async {
    await tester.pumpWidget(
      _wrap(EventTile(event: _makeEvent(source: EventSource.synced))),
    );
    final container = tester.widget<Container>(
      find.byKey(const Key('event_tile_border')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, equals(const Color(0xFF4CAF50)));
  });
}
