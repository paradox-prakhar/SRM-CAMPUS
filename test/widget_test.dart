import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_navigator/main.dart';

void main() {
  testWidgets('onboarding opens isolated simulation and indoor QR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: CampusApp()));
    await tester.pumpAndSettle();
    expect(find.text('Less searching.\nMore discovering.'), findsOneWidget);
    await tester.tap(find.text('Explore interactive demo'));
    await tester.pumpAndSettle();
    expect(find.text('SIMULATION'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Library');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central Library').first);
    await tester.pumpAndSettle();
    expect(find.text('Get directions'), findsOneWidget);
    await tester.tap(find.text('Get directions'));
    await tester.pumpAndSettle();
    expect(find.text('4 min • 240 m'), findsOneWidget);
    await tester.tap(find.text('Walk'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
  });
}
