import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final int? indexToEdit;

  const AddTransactionScreen({
    super.key,
    this.transactionToEdit,
    this.indexToEdit,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  Future<void> _saveTransaction() async {
  final title = _titleController.text.trim();
  final amount = double.tryParse(_amountController.text.trim());

  if (title.isEmpty || amount == null || amount <= 0) return;

  final tx = TransactionModel(
    title: title,
    amount: amount,
    date: widget.transactionToEdit?.date ?? DateTime.now(),
  );

  if (widget.indexToEdit != null) {
    // Update existing
    await HiveService.updateTransaction(widget.indexToEdit!, tx);
  } else {
    // Add new
    await HiveService.addTransaction(tx);
  }

  Navigator.pop(context, true);
}


  @override
  void initState() {
    super.initState();

if (widget.transactionToEdit != null) {
  _titleController.text = widget.transactionToEdit!.title;
  _amountController.text = widget.transactionToEdit!.amount.toString();
}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveTransaction,
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }
}
