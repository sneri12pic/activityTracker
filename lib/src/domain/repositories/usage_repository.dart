import '../models/app_usage_summary.dart';
import '../models/usage_session.dart';

abstract class UsageRepository {
  Future<bool> hasUsageAccess();

  Future<void> openUsageAccessSettings();

  Future<List<AppUsageSummary>> getTodaySummaries();

  Future<void> insertSession(UsageSession session);

  Future<void> clearAllData();
}
