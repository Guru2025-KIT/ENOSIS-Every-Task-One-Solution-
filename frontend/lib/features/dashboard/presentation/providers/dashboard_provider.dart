import 'package:flutter/foundation.dart';
import '../../data/models/dashboard_summary_model.dart';
import '../../data/services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;

  DashboardProvider({DashboardService? service})
      : _service = service ?? DashboardService();

  DashboardSummaryModel? _summary;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  DashboardSummaryModel? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;

  Future<void> loadDashboard({DateTime? targetDate}) async {
    _isLoading = true;
    _errorMessage = null;
    if (targetDate != null) {
      _selectedDate = targetDate;
    }
    notifyListeners();

    try {
      _summary = await _service.getDashboardSummary(targetDate: _selectedDate);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    loadDashboard(targetDate: date);
  }

  void refresh() {
    loadDashboard(targetDate: _selectedDate);
  }
}
