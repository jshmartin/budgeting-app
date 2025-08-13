import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Sign up: if user is anonymous, link to keep the same UID.
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    final user = _auth.currentUser;

    // Create the email credential
    final cred = EmailAuthProvider.credential(email: email, password: password);

    if (user != null && user.isAnonymous) {
      // Preferred path: link -> keeps same UID, no data migration needed
      await user.linkWithCredential(cred);
      return;
    }

    // No anonymous session; just create a new account and sign in
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  /// Sign in existing user (no linking)
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Fallback when email is already in use during "sign up":
  /// 1) capture old anon UID
  /// 2) sign in to the existing account
  /// 3) migrate data from old anon UID -> new UID
  Future<void> handleEmailAlreadyInUseAndMigrate(
    String email,
    String password,
  ) async {
    final oldAnonUid = _auth.currentUser?.uid;

    // Sign in to the existing account
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final newUid = _auth.currentUser!.uid;

    if (oldAnonUid != null && oldAnonUid != newUid) {
      await _migrateUserData(oldAnonUid: oldAnonUid, newUid: newUid);
      // (Optional) delete old anon user docs afterward
      await _deleteUserRoot(oldAnonUid);
    }
  }

  /// Copy budgets and transactions subcollections from old -> new UID.
  Future<void> _migrateUserData({
    required String oldAnonUid,
    required String newUid,
  }) async {
    final oldRoot = _fs.collection('users').doc(oldAnonUid);
    final newRoot = _fs.collection('users').doc(newUid);

    // --- Budgets ---
    final oldBudgets = await oldRoot.collection('budgets').get();
    for (final doc in oldBudgets.docs) {
      await newRoot.collection('budgets').add(doc.data());
    }

    // --- Transactions ---
    final oldTx = await oldRoot.collection('transactions').get();
    for (final doc in oldTx.docs) {
      await newRoot.collection('transactions').add(doc.data());
    }
  }

  Future<void> _deleteUserRoot(String uid) async {
    final root = _fs.collection('users').doc(uid);

    // delete budgets
    final budgets = await root.collection('budgets').get();
    for (final d in budgets.docs) {
      await d.reference.delete();
    }
    // delete transactions
    final txs = await root.collection('transactions').get();
    for (final d in txs.docs) {
      await d.reference.delete();
    }
    // delete the user doc if you create a profile doc later
    // await root.delete();  // only if you have a doc at users/{uid}
  }
}
