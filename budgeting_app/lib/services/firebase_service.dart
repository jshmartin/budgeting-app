import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _transactionsRef = _firestore.collection('transactions');

  static Future<void> saveTransactionToFirebase(TransactionModel tx) async {
    print("Saving transaction to Firebase: ${tx.toFirestore()}");
    await _transactionsRef.add(tx.toFirestore());
  }

  // Fetch all transactions from Firestore
  static Future<List<TransactionModel>> fetchTransactionsFromFirebase() async {
    final snapshot =
        await _transactionsRef.orderBy('date', descending: true).get();

    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc.data()))
        .toList();
  }

  // Clear all transactions from Firestore
  static Future<void> deleteAllFirebaseTransactions() async {
    final snapshot = await _transactionsRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  static final _budgetRef = _firestore.collection('budgets');

  static Future<void> saveBudgetToFirebase(BudgetModel budget) async {
    await _budgetRef.add(budget.toFirestore());
  }

  // Fetch all budgets from Firestore
  static Future<List<BudgetModel>> fetchBudgetsFromFirebase() async {
    final snapshot = await _budgetRef.orderBy('startDate', descending: true).get();

    return snapshot.docs
        .map((doc) => BudgetModel.fromFirestore(doc.data()))
        .toList();
  }

  // Clear all budgets from Firestore
  static Future<void> deleteAllFirebaseBudgets() async {
    final snapshot = await _budgetRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
