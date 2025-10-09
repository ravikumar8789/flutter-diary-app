import 'package:flutter_riverpod/flutter_riverpod.dart';

// Notifier class for managing the currently selected entry date across screens
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void updateDate(DateTime newDate) {
    state = newDate;
  }
}

// Provider for managing the currently selected entry date across screens
final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  () => SelectedDateNotifier(),
);
