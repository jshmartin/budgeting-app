import 'package:hive/hive.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

class HiveService {
  static final _txBox = Hive.box<TransactionModel>('transactions');
  static final _budgetBox = Hive.box<double>('budget');

  // Transactions
  static List<TransactionModel> getAllTransactions() {
    return _txBox.values.toList();
  }

  static Future<void> addTransaction(TransactionModel tx) async {
    await _txBox.add(tx);
  }

  static Future<void> updateTransaction(int index, TransactionModel tx) async {
  final box = Hive.box<TransactionModel>('transactions');
  await box.put(index, tx);
}


  static Future<void> deleteTransaction(int index) async {
    await _txBox.deleteAt(index);
  }

  static Future<void> saveBudget(BudgetModel budget) async {
    final box = Hive.box<BudgetModel>('budgets');
    await box.clear(); // Optional: store one active budget - this means we only keep the latest budget
    await box.add(budget);
  }

  static BudgetModel? loadBudget() {
    final box = Hive.box<BudgetModel>('budgets');
    return box.values.isEmpty ? null : box.values.first;
  }
}
