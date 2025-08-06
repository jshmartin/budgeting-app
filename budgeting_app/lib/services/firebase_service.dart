import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _transactionsRef = _firestore.collection('transactions');

  /// Save one transaction to Firestore
  static Future<void> saveTransactionToFirebase(TransactionModel tx) async {
    print("Saving transaction to Firebase: ${tx.toFirestore()}");
    await _transactionsRef.add(tx.toFirestore());
  }

  /// Fetch all transactions from Firestore
  static Future<List<TransactionModel>> fetchTransactionsFromFirebase() async {
    final snapshot = await _transactionsRef.orderBy('date', descending: true).get();

    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc.data()))
        .toList();
  }

  /// Optional: Clear all transactions from Firestore
  static Future<void> deleteAllFirebaseTransactions() async {
    final snapshot = await _transactionsRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
