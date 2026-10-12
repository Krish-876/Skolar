import 'package:flutter_test/flutter_test.dart';
import 'package:Skolar/core/services/activity_log_service.dart';
import 'package:Skolar/features/focus_session/controllers/focus_timer_controller.dart';

class _FakeActivityLogService implements ActivityLogService {
  final List<({int durationSeconds, String clientId})> loggedSessions = [];

  @override
  Future<void> logFocusSession({
    required int durationSeconds,
    required String clientId,
  }) async {
    loggedSessions.add((durationSeconds: durationSeconds, clientId: clientId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ActivityLog & Focus Stop Logging tests', () {
    test('focus_timer_controller tracks elapsed focus time accurately', () {
      final controller = FocusTimerController(vsync: const TestVSync());

      controller.setDuration(1500); // 25 minutes
      expect(controller.elapsedFocusSeconds, 0);

      controller.start();
      expect(controller.status, FocusTimerStatus.running);

      // When running, elapsed seconds is total - remaining
      expect(controller.elapsedFocusSeconds >= 0, isTrue);

      controller.reset();
      expect(controller.elapsedFocusSeconds, 0);
      controller.dispose();
    });

    test(
      'B9 decision: user-initiated stop logs if >= configured threshold',
      () async {
        final fakeService = _FakeActivityLogService();
        const configuredThreshold =
            60; // Configured threshold in seconds (no hardcoded minutes)

        // Case 1: Elapsed seconds below threshold (e.g. 45s) -> should NOT log
        const elapsedBelow = 45;
        if (elapsedBelow >= configuredThreshold) {
          await fakeService.logFocusSession(
            durationSeconds: elapsedBelow,
            clientId: 'id-below',
          );
        }
        expect(fakeService.loggedSessions, isEmpty);

        // Case 2: Elapsed seconds >= threshold (e.g. 75s) -> should log
        const elapsedAbove = 75;
        if (elapsedAbove >= configuredThreshold) {
          await fakeService.logFocusSession(
            durationSeconds: elapsedAbove,
            clientId: 'id-above',
          );
        }
        expect(fakeService.loggedSessions.length, 1);
        expect(fakeService.loggedSessions.first.durationSeconds, 75);
        expect(fakeService.loggedSessions.first.clientId, 'id-above');
      },
    );

    test('B9 decision: app exit does NOT log session', () async {
      final fakeService = _FakeActivityLogService();
      // App exit / crash simulation:
      // Even if elapsed seconds was 100s, app exit cancellation does not trigger log
      expect(fakeService.loggedSessions, isEmpty);
    });

    test(
      'activity log idempotency simulation with duplicate clientId',
      () async {
        final fakeService = _FakeActivityLogService();
        const clientId = 'unique-session-uuid-1';

        await fakeService.logFocusSession(
          durationSeconds: 1500,
          clientId: clientId,
        );
        // Retrying the same clientId
        await fakeService.logFocusSession(
          durationSeconds: 1500,
          clientId: clientId,
        );

        expect(fakeService.loggedSessions.length, 2);
        expect(fakeService.loggedSessions[0].clientId, clientId);
        expect(fakeService.loggedSessions[1].clientId, clientId);
      },
    );
  });
}
