import 'package:hive/hive.dart';
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

  // Budget
  static double getBudget() {
    return _budgetBox.get('initial', defaultValue: 0.0)!;
  }

  static Future<void> setBudget(double value) async {
    await _budgetBox.put('initial', value);
  }
}
