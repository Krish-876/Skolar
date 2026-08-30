import 'package:Skolar/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:Skolar/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _settle(WidgetTester tester, {int ticks = 20}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('DashboardPage renders and the expand gesture works', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardPage())),
    );
    await _settle(tester);

    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.text('day streak'), findsWidgets);
    expect(find.text('All-Round Development'), findsOneWidget);

    // Drag the progress card fully open, then fully closed, exercising the
    // whole 0..1 expansion range (ring resize, bar chart at full width, etc).
    final cardDrag = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onVerticalDragUpdate != null,
    );
    expect(cardDrag, findsOneWidget);

    // The collapsed/expanded content trees both stay permanently mounted
    // (`Visibility(maintainState: true)`, see expandable_progress_card.dart)
    // so the floating ring/badges always have both anchors to measure —
    // `find.text('Weekly Progress')` (the bar chart, only ever built inside
    // the expanded layout) alone can't tell collapsed from expanded, since
    // it's in the tree either way. The `Visibility` wrapping it is what
    // actually toggles, so check that instead.
    Visibility expandedVisibility() => tester.widget<Visibility>(
      find
          .ancestor(
            of: find.text('Weekly Progress'),
            matching: find.byType(Visibility),
          )
          .first,
    );

    await tester.drag(cardDrag, const Offset(0, -600));
    await _settle(tester, ticks: 10);
    expect(find.text('Weekly Progress'), findsOneWidget);
    expect(expandedVisibility().visible, isTrue);

    // Once fully expanded, the card's own GestureDetector intentionally
    // stops handling vertical drags (so they reach the expanded view's own
    // scroll view instead) — collapsing from there is only wired through
    // the system back gesture/button (PopScope), not a second drag.
    await tester.binding.handlePopRoute();
    await _settle(tester, ticks: 10);
    expect(expandedVisibility().visible, isFalse);
  });

  testWidgets('every debug task-section state renders without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardPage())),
    );
    await _settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );

    // Fully expand once so the task section is actually built/visible.
    final cardDrag = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onVerticalDragUpdate != null,
    );
    await tester.drag(cardDrag, const Offset(0, -600));
    await _settle(tester, ticks: 10);

    for (final state in DebugTaskSectionState.values) {
      container.read(debugTaskSectionStateProvider.notifier).state = state;
      await _settle(tester, ticks: 5);
      expect(tester.takeException(), isNull, reason: 'state: $state');
    }
  });
}
