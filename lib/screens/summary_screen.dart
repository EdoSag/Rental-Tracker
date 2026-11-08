import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../services/excel_export.dart';
import '../state.dart';
import '../widgets/common.dart';

class SummaryScreen extends StatefulWidget {
  final AppState state;
  const SummaryScreen({super.key, required this.state});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int? _year;
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await shareExcel(widget.state);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('הייצוא נכשל: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.state.calc.allMonths();
    final years = {...all.map((m) => monthYear(m.month))}.toList()..sort();
    final year = _year != null && years.contains(_year) ? _year! : (years.isEmpty ? DateTime.now().year : years.last);
    final yearMonths = all.where((m) => monthYear(m.month) == year).toList();
    final total = Totals.of(all, kPartners.length);
    final yt = Totals.of(yearMonths, kPartners.length);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: FilledButton.icon(
            onPressed: _exporting || all.isEmpty ? null : _export,
            icon: _exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.table_view),
            label: const Text('ייצוא לאקסל'),
          ),
        ),
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('עדיין אין נתונים. הזן נתונים בלשונית "חודש".', textAlign: TextAlign.center),
          ),
        SectionCard(title: 'סה"כ כללי', children: [
          KV.money('הכנסות', total.income),
          KV.money('הוצאות', total.expenses),
          KV.money('רווח נקי', total.net, bold: true, signColor: true),
          const Divider(height: 24),
          const Text('חלוקת רווחים כוללת', style: TextStyle(fontWeight: FontWeight.w600)),
          for (var i = 0; i < kPartners.length; i++) KV.money(kPartners[i], total.partnerShares[i]),
        ]),
        SectionCard(
          title: 'סיכום שנתי',
          trailing: years.length > 1
              ? DropdownButton<int>(
                  value: year,
                  underline: const SizedBox(),
                  items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (y) => setState(() => _year = y),
                )
              : Text('$year'),
          children: [
            KV.money('שכירות', yt.rent),
            KV.money('חשמל מהשוכרים', yt.elecIncome),
            KV.money('מים מהשוכרים', yt.waterIncome),
            KV.money('ארנונה מהשוכרים', yt.arnonaIncome),
            KV.money('סה"כ הכנסות', yt.income, bold: true),
            KV.money('סה"כ הוצאות', yt.expenses),
            KV.money('רווח נקי', yt.net, bold: true, signColor: true),
            const Divider(height: 24),
            for (var i = 0; i < kPartners.length; i++) KV.money(kPartners[i], yt.partnerShares[i]),
          ],
        ),
        SectionCard(title: 'חודש־חודש ($year)', children: [
          _MonthTable(months: yearMonths),
        ]),
      ],
    );
  }
}

class _MonthTable extends StatelessWidget {
  final List<MonthResult> months;
  const _MonthTable({required this.months});

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontWeight: FontWeight.bold);
    Widget cell(String s, {TextStyle? style, bool num = true}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(s, style: style, textDirection: num ? TextDirection.ltr : null,
              textAlign: num ? TextAlign.end : TextAlign.start),
        );
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.1)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(horizontalInside: BorderSide(color: Theme.of(context).dividerColor)),
      children: [
        TableRow(children: [
          cell('חודש', style: head, num: false),
          cell('הכנסות', style: head, num: false),
          cell('הוצאות', style: head, num: false),
          cell('נקי', style: head, num: false),
        ]),
        for (final m in months)
          TableRow(children: [
            cell(kHebrewMonths[monthNum(m.month) - 1], num: false),
            cell(money(m.income)),
            cell(money(m.expenses)),
            cell(money(m.net), style: TextStyle(color: signColor(m.net), fontWeight: FontWeight.w600)),
          ]),
      ],
    );
  }
}
