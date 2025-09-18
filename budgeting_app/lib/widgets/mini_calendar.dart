import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A compact, reusable month calendar that can be collapsed/expanded,
/// supports browsing months, and highlights the remaining days from
/// [currentDate] through [endDate] (inclusive). Today is emphasized; past days
/// are muted.
///
/// Defaults:
///  - Starts on the month that contains [endDate]
///  - Collapsible UI is enabled and starts expanded
///  - Left/right chevrons let you switch months
///
/// Example:
///   MiniCalendarRange(
///     currentDate: DateTime.now(),
///     endDate: budget.endDate,
///   )
class MiniCalendarRange extends StatefulWidget {
  /// The "today" reference.
  final DateTime currentDate;

  /// The last day to highlight (inclusive).
  final DateTime endDate;

  /// Start on a specific month (if omitted, uses endDate's month).
  final DateTime? initialVisibleMonth;

  /// If true, renders an expand/collapse control in the header.
  final bool collapsible;

  /// Initial expanded state when [collapsible] is true.
  final bool initiallyExpanded;

  /// Callback when expanded state changes.
  final ValueChanged<bool>? onExpandedChanged;

  /// Show the small legend (shown when expanded).
  final bool showLegend;

  /// Outer padding around the whole widget.
  final EdgeInsetsGeometry padding;

  const MiniCalendarRange({
    super.key,
    required this.currentDate,
    required this.endDate,
    this.initialVisibleMonth,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.onExpandedChanged,
    this.showLegend = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  @override
  State<MiniCalendarRange> createState() => _MiniCalendarRangeState();
}

class _MiniCalendarRangeState extends State<MiniCalendarRange> {
  late DateTime _visibleMonth; // normalized to first-of-month
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    final startMonth = widget.initialVisibleMonth ?? widget.currentDate;
    _visibleMonth = DateTime(startMonth.year, startMonth.month, 1);
    _expanded = widget.initiallyExpanded;
  }

  void _goPrevMonth() {
    setState(() {
      _visibleMonth = _addMonths(_visibleMonth, -1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _visibleMonth = _addMonths(_visibleMonth, 1);
    });
  }

  void _toggleExpanded() {
    if (!widget.collapsible) return;
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    // Clamp text scale inside the calendar to stop header/day text from
    // exploding on Android with large system fonts.
    final clampedMQ = mq.copyWith(
      textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15),
    );

    final daysInMonth = _daysInMonth(_visibleMonth);
    final firstWeekday = _visibleMonth.weekday; // 1=Mon..7=Sun (Mon-first grid)
    final leadingEmpty = (firstWeekday - 1);

    final monthLabel = '${_fmtMonthName(_visibleMonth.month)} ${_visibleMonth.year}';

    // Normalize reference dates to YMD for comparison
    final todayYMD = DateTime(widget.currentDate.year, widget.currentDate.month, widget.currentDate.day);
    final endYMD = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);

    // Build the day cells once; sizing is handled below.
    List<Widget> _buildCells() {
      final totalCells = leadingEmpty + daysInMonth;
      final cells = List<Widget>.generate(totalCells, (index) {
        if (index < leadingEmpty) return const SizedBox.shrink();

        final day = index - leadingEmpty + 1;
        final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
        final dateYMD = DateTime(date.year, date.month, date.day);

        final isToday = _isSameDate(dateYMD, todayYMD);
        final isPast = dateYMD.isBefore(todayYMD);
        final isAfterEnd = dateYMD.isAfter(endYMD);
        final isWithinRemaining = !isPast && !isAfterEnd;

        final baseFg = theme.colorScheme.onSurface.withOpacity(0.8);
        final mutedFg = theme.colorScheme.onSurface.withOpacity(0.45);
        final highlightBg = theme.colorScheme.primary.withOpacity(0.12);
        final highlightBorder = theme.colorScheme.primary.withOpacity(0.65);

        BoxDecoration? deco;
        TextStyle textStyle = TextStyle(
          fontWeight: FontWeight.w600,
          color: isPast ? mutedFg : baseFg,
        );

        if (isWithinRemaining) {
          deco = BoxDecoration(
            color: highlightBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlightBorder, width: 1),
          );
          textStyle = textStyle.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          );
        } else if (isToday) {
          deco = BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.primary, width: 2),
          );
          textStyle = textStyle.copyWith(fontWeight: FontWeight.w800);
        }

        return Container(
          alignment: Alignment.center,
          decoration: deco,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('$day', style: textStyle),
          ),
        );
      });

      return cells;
    }

    // Weekday labels + grid (sized via LayoutBuilder to avoid overflow).
    Widget _sizedGrid() {
      final cells = _buildCells();

      return LayoutBuilder(
        builder: (context, constraints) {
          // Available width for the calendar content inside our padding.
          final resolvedPad = widget.padding.resolve(Directionality.of(context));
          final innerWidth = math.max(0.0, constraints.maxWidth - resolvedPad.horizontal);

          // Rows/weeks to render
          final totalCells = leadingEmpty + daysInMonth;
          final weeks = ((totalCells + 6) ~/ 7); // ceil(total/7)

          // Square-ish cells: derive tile size from width/7, then clamp by height budget.
          const spacing = 6.0;
          final tileWidth = (innerWidth - spacing * 6) / 7.0;

          // Height budget: keep grid within ~38% of screen height to avoid squeezing other content.
          final screenH = clampedMQ.size.height;
          final maxGridHeight = screenH * 0.38;

          double cellSize = tileWidth;
          double gridHeight = weeks * cellSize + spacing * (weeks - 1);

          if (gridHeight > maxGridHeight) {
            cellSize = (maxGridHeight - spacing * (weeks - 1)) / weeks;
            gridHeight = weeks * cellSize + spacing * (weeks - 1);
          }

          final childAspectRatio = tileWidth <= 0 ? 1.0 : (tileWidth / cellSize);

          return Column(
            children: [
              // Weekday headers (Mon..Sun)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _WeekdayLabel('M'),
                  _WeekdayLabel('T'),
                  _WeekdayLabel('W'),
                  _WeekdayLabel('T'),
                  _WeekdayLabel('F'),
                  _WeekdayLabel('S'),
                  _WeekdayLabel('S'),
                ],
              ),
              const SizedBox(height: spacing),
              SizedBox(
                height: gridHeight,
                width: innerWidth,
                child: GridView.count(
                  crossAxisCount: 7,
                  childAspectRatio: childAspectRatio,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: cells,
                ),
              ),
            ],
          );
        },
      );
    }

    // Header row (buttons + month). Legend moved below to prevent row overflow.
    Widget _headerRow() {
      return Row(
        children: [
          if (widget.collapsible)
            IconButton(
              onPressed: _toggleExpanded,
              tooltip: _expanded ? 'Collapse calendar' : 'Expand calendar',
              icon: AnimatedRotation(
                turns: _expanded ? 0.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more),
              ),
            ),
          IconButton(
            onPressed: _expanded ? _goPrevMonth : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),
          // Month label shrinks instead of overflowing
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _expanded ? _goNextMonth : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      );
    }

    // Legend placed on its own line (wraps as needed on small screens)
    Widget _legend() {
      if (!widget.showLegend || !_expanded) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _legendDot(context, theme.colorScheme.primary, 'Remaining'),
            _legendDot(context, theme.colorScheme.onSurface.withOpacity(0.45), 'Past'),
          ],
        ),
      );
    }

    final content = Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerRow(),
          const SizedBox(height: 8),
          _legend(),
          const SizedBox(height: 8),
          // Collapsible body
          AnimatedCrossFade(
            firstChild: _sizedGrid(),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );

    return MediaQuery(data: clampedMQ, child: content);
  }

  // ---- helpers ----

  static int _daysInMonth(DateTime d) {
    final beginningNextMonth = (d.month < 12)
        ? DateTime(d.year, d.month + 1, 1)
        : DateTime(d.year + 1, 1, 1);
    return beginningNextMonth.subtract(const Duration(days: 1)).day;
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _fmtMonthName(int m) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return months[m - 1];
  }

  static DateTime _addMonths(DateTime monthStart, int delta) {
    final year = monthStart.year + ((monthStart.month - 1 + delta) ~/ 12);
    final month = (monthStart.month - 1 + delta) % 12 + 1;
    return DateTime(year, month, 1);
  }

  static Widget _legendDot(BuildContext context, Color color, String label) {
    final fg = Theme.of(context).colorScheme.onSurface.withOpacity(0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
