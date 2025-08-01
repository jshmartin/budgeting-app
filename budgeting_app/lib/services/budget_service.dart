import 'package:shared_preferences/shared_preferences.dart';

class BudgetService {
  static const _budgetKey = 'initial_budget';

  static Future<void> setBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, value);
  }

  static Future<double> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? 0.0;
  }
}
