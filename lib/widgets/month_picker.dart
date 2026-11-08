import 'package:flutter/material.dart';

import '../models.dart';

/// "‹ נובמבר 2026 ›" with a tap-to-pick dialog.
class MonthPicker extends StatelessWidget {
  final String month;
  final ValueChanged<String> onChanged;
  const MonthPicker({super.key, required this.month, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    var year = monthYear(month);
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => year--)),
            Expanded(child: Text('$year', textAlign: TextAlign.center)),
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => year++)),
          ]),
          content: SizedBox(
            width: 300,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 2,
              children: [
                for (var m = 1; m <= 12; m++)
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: monthKey(year, m) == month
                        ? FilledButton(
                            onPressed: () => Navigator.pop(c, monthKey(year, m)),
                            style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                            child: Text(kHebrewMonths[m - 1]))
                        : OutlinedButton(
                            onPressed: () => Navigator.pop(c, monthKey(year, m)),
                            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                            child: Text(kHebrewMonths[m - 1])),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'החודש הקודם',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(addMonths(month, -1)),
        ),
        TextButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_month),
          label: Text(monthLabel(month), style: Theme.of(context).textTheme.titleLarge),
        ),
        IconButton(
          tooltip: 'החודש הבא',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(addMonths(month, 1)),
        ),
      ],
    );
  }
}
