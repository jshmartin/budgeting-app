import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  
  static CollectionReference<Map<String, dynamic>> get _budgetRef =>
      _firestore.collection('users').doc(_uid).collection('budgets');

  static CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('users').doc(_uid).collection('transactions');

  static Future<void> saveTransactionToFirebase(TransactionModel tx) async {
    await _transactionsRef.add(tx.toFirestore());
  }
  static Future<List<TransactionModel>> fetchTransactionsFromFirebase() async {
    final qs = await _transactionsRef.orderBy('date', descending: true).get();
    return qs.docs.map((d) => TransactionModel.fromFirestore(d.data())).toList();
  }

  // Clear all transactions from Firestore
  static Future<void> deleteAllFirebaseTransactions() async {
    final snapshot = await _transactionsRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }


  static Future<void> saveBudgetToFirebase(BudgetModel b) async {
    await _budgetRef.add(b.toFirestore());
  }
  
  static Future<List<BudgetModel>> fetchBudgetsFromFirebase() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('budgets')
        .get();

    return snapshot.docs
        .map((doc) => BudgetModel.fromFirestore(doc.data()))
        .toList();
  } catch (e) {
    // On error, return an empty list instead of null
    return [];
  }
}


  // Clear all budgets from Firestore
  static Future<void> deleteAllFirebaseBudgets() async {
    final snapshot = await _budgetRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
