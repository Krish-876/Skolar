import 'package:Skolar/features/focus_session/controllers/focus_timer_controller.dart';
import 'package:Skolar/features/focus_session/widgets/present_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresetChip Tests', () {
    testWidgets('renders label and handles tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresetChip(
              label: 'Pomodoro',
              isActive: true,
              icon: Icons.timer,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      // Verify label is rendered
      expect(find.text('Pomodoro'), findsOneWidget);

      // Verify icon is rendered
      expect(find.byIcon(Icons.timer), findsOneWidget);

      // Perform tap
      await tester.tap(find.text('Pomodoro'));
      await tester.pump();

      // Verify tap callback was triggered
      expect(tapped, isTrue);
    });

    testWidgets('renders correctly when inactive and without icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresetChip(
              label: 'Short Break',
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Short Break'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('FocusTimerController Tests', () {
    late FocusTimerController controller;

    setUp(() {
      controller = FocusTimerController(vsync: const TestVSync());
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state', () {
      expect(controller.status, FocusTimerStatus.idle);
      expect(controller.totalSeconds, 3600);
      expect(controller.secondsLeft, 3600);
      expect(controller.formattedTime, '1:00:00');
    });

    test('setDuration updates seconds and formatted time', () {
      controller.setDuration(1500); // 25 minutes
      expect(controller.totalSeconds, 1500);
      expect(controller.secondsLeft, 1500);
      expect(controller.formattedTime, '25:00');
    });

    test('start changes status and runs timer', () async {
      controller.setDuration(10);
      controller.start();
      expect(controller.status, FocusTimerStatus.running);

      // Wait 1 second to verify ticker decreases secondsLeft
      await Future.delayed(const Duration(seconds: 1));
      expect(controller.secondsLeft, lessThan(10));
    });

    test('reset goes back to idle', () {
      controller.setDuration(1500);
      controller.start();
      controller.reset();

      expect(controller.status, FocusTimerStatus.idle);
      expect(controller.secondsLeft, 1500);
    });
  });
}
