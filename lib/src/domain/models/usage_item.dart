import 'app_usage_summary.dart';

class UsageItem {
  const UsageItem({
    required this.id,
    required this.name,
    required this.totalDurationSeconds,
    required this.percentageOfTotal,
    required this.category,
    required this.initials,
    this.sourceName,
  });

  factory UsageItem.fromSummary(AppUsageSummary summary) {
    return UsageItem(
      id: summary.appKey,
      name: summary.appName,
      sourceName: summary.processName ?? summary.packageName,
      totalDurationSeconds: summary.totalDurationSeconds,
      percentageOfTotal: summary.percentageOfTotal,
      category: _categoryFor(summary.appName),
      initials: _initialsFor(summary.appName),
    );
  }

  final String id;
  final String name;
  final String? sourceName;
  final int totalDurationSeconds;
  final double percentageOfTotal;
  final String category;
  final String initials;

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    final first = parts.first;
    return first
        .substring(0, first.length < 2 ? first.length : 2)
        .toUpperCase();
  }
  return parts.take(2).map((part) => part[0]).join().toUpperCase();
}

String _categoryFor(String name) {
  final normalized = name.toLowerCase();
  if (_containsAny(normalized, const [
    'youtube',
    'tiktok',
    'instagram',
    'spotify',
    'netflix',
  ])) {
    return 'Entertainment';
  }
  if (_containsAny(normalized, const [
    'code',
    'studio',
    'terminal',
    'editor',
  ])) {
    return 'Productivity';
  }
  if (_containsAny(normalized, const [
    'chrome',
    'edge',
    'firefox',
    'safari',
    'browser',
  ])) {
    return 'Web';
  }
  if (_containsAny(normalized, const [
    'whatsapp',
    'discord',
    'gmail',
    'mail',
    'slack',
    'teams',
  ])) {
    return 'Communication';
  }
  if (_containsAny(normalized, const ['settings', 'system'])) {
    return 'System';
  }
  return 'Activity';
}

bool _containsAny(String value, List<String> terms) {
  return terms.any(value.contains);
}
