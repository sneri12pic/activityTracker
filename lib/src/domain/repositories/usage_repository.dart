import '../models/app_usage_summary.dart';
import '../models/usage_session.dart';

abstract class UsageRepository {
  Future<bool> hasUsageAccess();

  Future<void> openUsageAccessSettings();

  Future<List<AppUsageSummary>> getTodaySummaries();

  /// The longest recorded sessions for [appKey] on [date], longest first.
  /// Returns an empty list on platforms without local session storage.
  Future<List<UsageSession>> topSessionsForApp(
    String appKey,
    DateTime date, {
    int limit = 3,
  });

  Future<void> insertSession(UsageSession session);

  Future<void> clearAllData();
}
