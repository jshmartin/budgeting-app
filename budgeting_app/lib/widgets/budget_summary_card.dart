import 'package:flutter/material.dart';
import '../models/budget.dart';

class BudgetSummaryCard extends StatelessWidget {
  final BudgetModel budget;
  final double spent;
  final VoidCallback? onChangeRange;
  final VoidCallback? onSetBudget;

  final String title;

  const BudgetSummaryCard({
    super.key,
    required this.budget,
    required this.spent,
    required this.title,
    this.onChangeRange,
    this.onSetBudget,
  });

  String _fmtDate(DateTime d) {
    // Example: Aug 5
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _fmtMoney(double v) {
    // Simple currency formatter without intl dependency
    final s = v.abs().toStringAsFixed(2);
    return (v < 0 ? '-\$' : '\$') + s;
  }

  // Percentage of time elapsed in the budget window, clamped 0..1
  double _timeProgress(DateTime start, DateTime end, DateTime now) {
    if (!end.isAfter(start)) return 1;
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return 1;
    final total = end.difference(start).inMilliseconds;
    final soFar = now.difference(start).inMilliseconds;
    return soFar / total;
  }

  // Days remaining (>= 0)
  int _daysLeft(DateTime end, DateTime now) {
    final d = end.difference(DateTime(now.year, now.month, now.day)).inDays;
    return d < 0 ? 0 : d;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = (budget.amount - spent).clamp(-999999999.0, 999999999.0);
    final progress = _timeProgress(budget.startDate, budget.endDate, now);
    final percent = ((spent/budget.amount) * 100).clamp(0, 100);
    final daysLeft = _daysLeft(budget.endDate, now);
    final daily = daysLeft > 0 ? remaining / daysLeft : remaining;

    // Card width for a tight, centered look
    const maxWidth = 520.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_fmtMoney(remaining)} left of ${_fmtMoney(budget.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onSetBudget,
                      tooltip: 'Set / Update Budget',
                      icon: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Body
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.12),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    // Dates + timeline
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmtDate(budget.startDate),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _fmtDate(budget.endDate),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar with "Today" bubble & % label
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth = constraints.maxWidth;
                        final knobX = (barWidth * spent / budget.amount).clamp(0.0, barWidth);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Track
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            // Fill
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 18,
                              width: knobX,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            // Knob + bubble
                            Positioned(
                              left: (knobX - 10).clamp(0.0, barWidth - 20),
                              top: -28,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: const Text(
                                      'Remaining Budget',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 3,
                                      ),
                                    ),
                                    child: Text(
                                      '${percent.round()}%',
                                      style: const TextStyle(
                                        fontSize: 0, // visually hide inside the knob
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Percent overlay text centered
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  '${percent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Daily spend hint
                    Text(
                      daysLeft > 0
                          ? 'You can spend ${_fmtMoney(daily)}/day for $daysLeft more day${daysLeft == 1 ? '' : 's'}'
                          : 'Budget period ends today',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
