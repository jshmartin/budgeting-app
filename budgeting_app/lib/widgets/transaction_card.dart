import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback? onTap;        // open detail/edit (tap on the card)
  final VoidCallback? onEdit;       // pencil icon
  final VoidCallback? onDelete;     // trash icon

  const TransactionCard({
    super.key,
    required this.tx,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;

    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.18),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                tx.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: onSurface.withOpacity(0.95),
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 6),

              // Date chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _fmtDate(tx.date.toLocal()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withOpacity(0.8),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Amount
              Text(
                '\$${tx.amount.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: scheme.primary,
                ),
              ),

              const SizedBox(height: 12),

              // Actions: Edit & Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
