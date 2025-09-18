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

  String _fmtMoney(double v) {
    final isNeg = v < 0;
    final n = v.abs();
    final s = n.toStringAsFixed(2);
    return '${isNeg ? '-' : ''}\$$s';
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  // 0..1 time progress across the budget range
  double _timeProgress(DateTime start, DateTime end, DateTime now) {
    if (!now.isAfter(start)) return 0;
    if (!end.isAfter(start)) return 1;
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
    final percent = ((spent / (budget.amount == 0 ? 1 : budget.amount)) * 100).clamp(0, 100);
    final daysLeft = _daysLeft(budget.endDate, now);
    final daily = daysLeft > 0 ? remaining / daysLeft : remaining;

    // Card width for a tight, centered look
    const maxWidth = 520.0;

    // Clamp text scaling inside this tight card to avoid overflow on Android.
    final mq = MediaQuery.of(context);
    final clampedMQ = mq.copyWith(
      textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.2),
    );

    return MediaQuery(
      data: clampedMQ,
      child: Center(
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
                            // Title shrinks/ellipsizes to avoid overflow
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                        tooltip: 'Update Budget',
                        icon: const Icon(Icons.tune, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(height: 4),
                                Text(
                                  _fmtDate(budget.startDate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('End',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(height: 4),
                                Text(
                                  _fmtDate(budget.endDate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Progress bar with percent overlay and "today" knob
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth;
                          final knobX = (barWidth * (spent / (budget.amount == 0 ? 1 : budget.amount)))
                              .clamp(0.0, barWidth);

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
                                width: (barWidth * (spent / (budget.amount == 0 ? 1 : budget.amount)))
                                    .clamp(0.0, barWidth),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              // Percent overlay text, scales down if space is tight
                              Positioned.fill(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${percent.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Footer stats row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Daily: ${_fmtMoney(daily)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            daysLeft > 0 ? '${daysLeft}d left' : 'Ends today',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
