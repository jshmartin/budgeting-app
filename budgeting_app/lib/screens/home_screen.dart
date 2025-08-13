import 'package:flutter/material.dart';
import '../models/budget.dart';
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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _changeBudgetRange() async {
    if (_budgetModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active budget to update.')),
      );
      return;
    }

    final initialRange = DateTimeRange(
      start: _budgetModel!.startDate,
      end: _budgetModel!.endDate,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDateRange: initialRange,
    );

    if (picked == null) return;

    final updated = BudgetModel(
      title: _budgetModel!.title,
      amount: _budgetModel!.amount,
      startDate: picked.start,
      endDate: picked.end,
    );

    await HiveService.saveBudget(updated); // local cache
    await FirebaseService.saveBudgetToFirebase(updated); // cloud copy
    setState(() {
      _budgetModel = updated;
      _initialBudget = updated.amount;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Budget dates updated: ${_fmt(updated.startDate)} → ${_fmt(updated.endDate)}')),
    );
  }

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
        await FirebaseService.fetchTransactionsFromFirebase();

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

    // print all budgets title and amount
    print(
        'Loaded budgets: ${firebaseBudgets.map((b) => '${b.title}: ${b.amount}').join(', ')}');
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
                // If budget is set, show details; otherwise prompt to set budget
                if (_budgetModel != null)
                  Text(
                    '${_budgetModel!.title} : \$${_budgetModel!.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  )
                else
                  const Text(
                    'No budget set. Please set a budget.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                Text('Spent: \$${_totalSpent.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.red)),
                Text('Remaining: \$${_remainingBudget.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green)),
                const SizedBox(height: 8),
                // display date range in dd/mm/yyyy if budget is set
                if (_budgetModel != null)
                  Row(
                    children: [
                      Chip(
                        label: Text(
                            '${_fmt(_budgetModel!.startDate)} → ${_fmt(_budgetModel!.endDate)}'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _changeBudgetRange,
                        icon: const Icon(Icons.date_range),
                        label: const Text('Change Date Range'),
                      ),
                    ],
                  ),
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
