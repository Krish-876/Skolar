// Stub — call sites are wired now, real Supabase write lands in Phase 5

abstract class ActivityLogService {
  Future<void> logFocusComplete(String userId);
  Future<void> logTestComplete(String userId);
  Future<void> logPuzzleSolved(String userId);
  Future<void> logDoubtAnswered(String userId);
}

class ActivityLogServiceStub implements ActivityLogService {
  @override Future<void> logFocusComplete(String userId)  async {}
  @override Future<void> logTestComplete(String userId)   async {}
  @override Future<void> logPuzzleSolved(String userId)   async {}
  @override Future<void> logDoubtAnswered(String userId)  async {}
}