import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/firebase_service.dart';
import '../widgets/budget_summary_card.dart';
import 'add_transaction_screen.dart';
import 'package:hive/hive.dart';
import '../services/hive_service.dart';
import 'auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/transaction_card.dart';

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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadTransactions() async {
    final txBox = Hive.box<TransactionModel>('transactions');

    // Load from Hive first
    final hiveEntries = txBox
        .toMap()
        .entries
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
    final firebaseTxList =
        await FirebaseService.fetchTransactionsFromFirebase() ?? [];
    for (final tx in firebaseTxList) {
      await txBox.add(tx);
    }

    // Reload from Hive again (now it should be populated)
    final updatedEntries = txBox
        .toMap()
        .entries
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

  double _initialBudget = 0.0;
  BudgetModel? _budgetModel;

  Future<void> _loadBudget() async {
    final localBudget = HiveService.loadBudget();

    if (localBudget != null) {
      setState(() {
        _budgetModel = localBudget;
        _initialBudget = localBudget.amount;
      });
      return;
    }

    // If not found locally, pull from Firebase and save to Hive
    final firebaseBudgets = await FirebaseService.fetchBudgetsFromFirebase();

    if (firebaseBudgets.isNotEmpty) {
      final latest = firebaseBudgets.first;
      await HiveService.saveBudget(latest);

      setState(() {
        _budgetModel = latest;
        _initialBudget = latest.amount;
      });
    }

    // Safe print (won’t crash on empty)
    if (firebaseBudgets.isNotEmpty) {
      print(
          'Loaded budgets: ${firebaseBudgets.map((b) => '${b.title}: ${b.amount}').join(', ')}');
    } else {
      print('Loaded budgets: (none)');
    }
  }

  void _promptChangeDateRange() {
    // Show date range picker and update budget model
    showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _budgetModel?.startDate ?? DateTime.now(),
        end: _budgetModel?.endDate ??
            DateTime.now().add(const Duration(days: 30)),
      ),
    ).then((range) {
      if (range != null) {
        setState(() {
          _budgetModel?.startDate = range.start;
          _budgetModel?.endDate = range.end;
        });
      }
    });
  }

  double get _totalSpent {
    return _transactions.fold(0.0, (sum, entry) => sum + entry.value.amount);
  }

  double get _remainingBudget {
    return _initialBudget - _totalSpent;
  }

  Future<void> _promptSetBudget() async {
    final nameController =
        TextEditingController(text: _budgetModel?.title ?? '');
    final amountController = TextEditingController(
      text: _budgetModel?.amount.toString() ??
          (_initialBudget == 0 ? '' : _initialBudget.toString()),
    );

    DateTimeRange? pickedRange = (_budgetModel != null)
        ? DateTimeRange(
            start: _budgetModel!.startDate, end: _budgetModel!.endDate)
        : null;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Budget'),
        content: StatefulBuilder(
          builder: (ctx, setInnerState) {
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Budget Name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                      validator: (v) {
                        final d = double.tryParse(v?.trim() ?? '');
                        if (d == null || d <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date Range'),
                      subtitle: Text(
                        (pickedRange == null)
                            ? 'Choose start and end dates'
                            : '${pickedRange!.start.toLocal().toString().split(' ')[0]}  →  ${pickedRange!.end.toLocal().toString().split(' ')[0]}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final nextMonth =
                              DateTime(now.year, now.month + 1, now.day);
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 5),
                            lastDate: DateTime(now.year + 5),
                            initialDateRange: pickedRange ??
                                DateTimeRange(start: now, end: nextMonth),
                          );
                          if (range != null) {
                            setInnerState(() => pickedRange = range);
                          }
                        },
                        child: const Text('Pick'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    if (!formKey.currentState!.validate() || pickedRange == null) {
      // If the dialog closed but validation not run, re-open with a hint.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please complete all fields, including date range.')),
      );
      return;
    }

    final newBudget = BudgetModel(
      title: nameController.text.trim(),
      amount: double.parse(amountController.text.trim()),
      startDate: pickedRange!.start,
      endDate: pickedRange!.end,
    );

    await HiveService.saveBudget(newBudget);
    await FirebaseService.saveBudgetToFirebase(newBudget);
    await _loadBudget();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(),
      appBar: AppBar(
        title: const Icon(Icons.account_balance_wallet_outlined),
        actions: [
          // Live auth status
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              // Label for the chip
              final label = (user == null || user.isAnonymous)
                  ? 'Guest'
                  : (user.email ?? 'Signed in');

              // Whether the sign-in option should be disabled
              final isSignedIn = (user != null && !user.isAnonymous);

              return Row(
                children: [
                  // Status chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(label: Text(label)),
                  ),

                  // Menu with conditional enable/disable
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'account') {
                        // Only allow if not signed in
                        if (!isSignedIn) {
                          final ok = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AuthScreen()),
                          );
                          if (ok == true) {
                            await _loadBudget(); // refresh scoped data
                            await _loadTransactions(); // refresh scoped data
                          }
                        }
                      } else if (value == 'signout') {
                        await FirebaseAuth.instance.signOut();
                        // After sign out, re‑anon sign in automatically on next start.
                        await FirebaseAuth.instance.signInAnonymously();
                        await _loadBudget();
                        await _loadTransactions();
                      }
                    },
                    itemBuilder: (ctx) => [
                      // Sign in / Create account (disabled when already signed in)
                      PopupMenuItem(
                        value: 'account',
                        enabled: !isSignedIn,
                        child: Text(
                          'Sign in / Create account',
                          style: TextStyle(
                            color: !isSignedIn
                                ? null
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                      ),
                      // Optional: Sign out (only when signed in)
                      if (isSignedIn)
                        const PopupMenuItem(
                          value: 'signout',
                          child: Text('Sign out'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Budget summary box
          Container(
            width: double.infinity,
            color: Colors.indigo.shade100,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_budgetModel == null)
                  Column(
                    children: [
                      const Text(
                        'No active budget',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _promptSetBudget,
                        child: const Text('Create budget'),
                      ),
                    ],
                  )
                else
                  BudgetSummaryCard(
                    budget: _budgetModel!, // now safe
                    spent: _totalSpent,
                    onChangeRange: _promptChangeDateRange,
                    onSetBudget: _promptSetBudget,
                    title: _budgetModel!.title,
                  ),
              ],
            ),
          ),

          const Divider(),
          // Transaction list
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text('No transactions yet.'))
                : Center(
                    child: SizedBox(
                      width: 520, // tidy centered column
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final entry = _transactions[index];
                          final tx = entry.value;
                          final txIndex = entry.key;

                          return TransactionCard(
                            tx: tx,
                            onTap: () async {
                              // tap anywhere on the card to edit (optional)
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
                            onEdit: () async {
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
                            onDelete: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Transaction'),
                                  content: const Text(
                                      'Are you sure you want to delete this transaction?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await HiveService.deleteTransaction(txIndex);
                                _loadTransactions();
                              }
                            },
                          );
                        },
                      ),
                    ),
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
