import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_usage_summary.dart';
import '../../domain/models/usage_item.dart';

final usageBubbleViewModelProvider =
    StateNotifierProvider.autoDispose<UsageBubbleViewModel, UsageBubbleState>(
      (ref) => UsageBubbleViewModel(),
    );

class UsageBubbleState {
  const UsageBubbleState({this.selectedItemId});

  final String? selectedItemId;

  UsageBubbleState copyWith({
    String? selectedItemId,
    bool clearSelection = false,
  }) {
    return UsageBubbleState(
      selectedItemId: clearSelection
          ? null
          : selectedItemId ?? this.selectedItemId,
    );
  }
}

class UsageBubbleViewModel extends StateNotifier<UsageBubbleState> {
  UsageBubbleViewModel() : super(const UsageBubbleState());

  List<UsageItem> itemsFor(List<AppUsageSummary> summaries) {
    final items = summaries.map(UsageItem.fromSummary).toList()
      ..sort(
        (first, second) =>
            second.totalDurationSeconds.compareTo(first.totalDurationSeconds),
      );
    return items;
  }

  UsageItem? selectedItemFor(List<UsageItem> items, String? selectedItemId) {
    if (selectedItemId == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == selectedItemId) {
        return item;
      }
    }
    return null;
  }

  void selectItem(UsageItem item) {
    state = state.copyWith(selectedItemId: item.id);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }
}
