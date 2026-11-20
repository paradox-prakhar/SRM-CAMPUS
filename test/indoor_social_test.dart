import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_navigator/presentation/screens.dart';

void main() {
  testWidgets('manual floor and QR-confirmed floor have distinct sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: IndoorScreen(buildingId: 'library')),
      ),
    );
    await tester.tap(find.text('First floor'));
    await tester.pumpAndSettle();
    expect(find.text('Floor source: manual selection'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Simulate scanning this QR'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Simulate scanning this QR'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Floor confirmed by QR scan •'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Floor confirmed by QR scan •'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'sharing starts only after consent and stop removes demo marker',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SharingScreen())),
      );
      expect(find.text('Your location is yours.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Invite & start sharing'), 200);
      await tester.tap(find.text('Invite & start sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Stop Sharing'), findsOneWidget);
      await tester.tap(find.text('Stop Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Invite & start sharing'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
