import 'package:home_widget/home_widget.dart';

class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  Future<void> updateAuthStatus(bool isLoggedIn) async {
    await HomeWidget.saveWidgetData<bool>('is_logged_in', isLoggedIn);
    await _refreshWidgets();
  }

  Future<void> updateStreak(int streak) async {
    await HomeWidget.saveWidgetData<int>('streak', streak);
    await _refreshWidgets();
  }

  Future<void> updateSessionStatus({
    required bool isActive,
    String? sessionName,
    String? startTime,
    String? endTime,
    String? remainingTime,
    int? progress,
    int? colorValue,
  }) async {
    await HomeWidget.saveWidgetData<bool>('is_active', isActive);
    
    if (isActive) {
      await HomeWidget.saveWidgetData<String>('session_name', sessionName ?? "Focus");
      await HomeWidget.saveWidgetData<String>('session_start_time', startTime ?? "");
      await HomeWidget.saveWidgetData<String>('session_end_time', endTime ?? "");
      await HomeWidget.saveWidgetData<String>('session_remaining', remainingTime ?? "");
      await HomeWidget.saveWidgetData<int>('session_progress', progress ?? 0);
      await HomeWidget.saveWidgetData<int>('session_color', colorValue ?? 0xFF448AFF);
    }
    
    await _refreshWidgets();
  }
  
  Future<void> updateStats({
    required int focusScore,
    required String screenTimeStr,
    required List<String> culprits,
  }) async {
    await HomeWidget.saveWidgetData<int>('focus_score', focusScore);
    await HomeWidget.saveWidgetData<String>('screen_time_str', screenTimeStr);
    
    await HomeWidget.saveWidgetData<String>('culprit_1', culprits.isNotEmpty ? culprits[0] : "--");
    await HomeWidget.saveWidgetData<String>('culprit_2', culprits.length > 1 ? culprits[1] : "--");
    await HomeWidget.saveWidgetData<String>('culprit_3', culprits.length > 2 ? culprits[2] : "--");

    await _refreshWidgets();
  }

  Future<void> _refreshWidgets() async {
    await HomeWidget.updateWidget(
      name: 'PulseWidget',
      androidName: 'PulseWidget',
    );
    await HomeWidget.updateWidget(
      name: 'HudWidget',
      androidName: 'HudWidget',
    );
    await HomeWidget.updateWidget(
      name: 'ChecklistWidget',
      androidName: 'ChecklistWidget',
    );
  }

  Future<void> updateChecklist() async {
    await HomeWidget.updateWidget(
      name: 'ChecklistWidget',
      androidName: 'ChecklistWidget',
    );
  }

  Future<void> refreshAll() async {
    await _refreshWidgets();
  }
}
