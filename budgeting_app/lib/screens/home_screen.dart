import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/firebase_service.dart';
import 'add_transaction_screen.dart';
import 'package:hive/hive.dart';
import '../services/hive_service.dart';
import '../models/transaction.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MapEntry<int, TransactionModel>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadBudget();
  }

Future<void> _loadTransactions() async {
  final txBox = Hive.box<TransactionModel>('transactions');

  // Load from Hive first
  final hiveEntries = txBox.toMap().entries
      .where((e) => e.key is int)
      .map((e) => MapEntry(e.key as int, e.value))
      .toList();

  if (hiveEntries.isNotEmpty) {
    setState(() {
      _transactions = hiveEntries;
    });
    return;
  }

  // If Hive is empty, fetch from Firebase and save locally
  final firebaseTxList = await FirebaseService.fetchTransactionsFromFirebase();

  for (final tx in firebaseTxList) {
    await txBox.add(tx);
  }

  // Reload from Hive again (now it should be populated)
  final updatedEntries = txBox.toMap().entries
      .where((e) => e.key is int)
      .map((e) => MapEntry(e.key as int, e.value))
      .toList();

  setState(() {
    _transactions = updatedEntries;
  });
}



  void _openAddTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen()),
    );

    if (result == true) {
      _loadTransactions();
    }
  }


  double _initialBudget = HiveService.getBudget();
  double get _totalSpent => _transactions.fold(0.0, (sum, entry) => sum + entry.value.amount);
  double get _remainingBudget => _initialBudget - _totalSpent;

  Future<void> _loadBudget() async {
    setState(() {
      _initialBudget = HiveService.getBudget();
    });
  }

  Future<void> _promptSetBudget() async {
    final controller = TextEditingController(text: _initialBudget.toString());

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Initial Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Budget Amount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await HiveService.setBudget(result);
      await _loadBudget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Budget')),
      body: Column(
        children: [
          // Budget summary box
          Container(
            width: double.infinity,
            color: Colors.indigo.shade100,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Initial Budget: \$${_initialBudget.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Spent: \$${_totalSpent.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.red)),
                Text('Remaining: \$${_remainingBudget.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _promptSetBudget,
                  child: const Text('Set / Update Budget'),
                )
              ],
            ),
          ),
          const Divider(),
          // Transaction list
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text('No transactions yet.'))
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (ctx, index) {
                      final entry = _transactions[index];
                      final tx = entry.value;
                      final txIndex = entry.key;
                      return Dismissible(
                        key: ValueKey(txIndex),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Transaction'),
                              content: const Text(
                                  'Are you sure you want to delete this transaction?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          await HiveService.deleteTransaction(txIndex);
                          _loadTransactions();
                        },
                        child: ListTile(
                          title: Text(tx.title),
                          subtitle: Text('${tx.date.toLocal()}'.split(' ')[0]),
                          trailing: Text('\$${tx.amount.toStringAsFixed(2)}'),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddTransactionScreen(
                                  transactionToEdit: tx,
                                  indexToEdit: txIndex,
                                ),
                              ),
                            );
                            if (result == true) _loadTransactions();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}
