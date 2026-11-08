import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/common.dart';
import '../widgets/month_picker.dart';
import '../widgets/num_field.dart';
import '../widgets/photo_strip.dart';

class MonthScreen extends StatelessWidget {
  final AppState state;
  final String month;
  final ValueChanged<String> onMonthChanged;
  const MonthScreen({super.key, required this.state, required this.month, required this.onMonthChanged});

  @override
  Widget build(BuildContext context) {
    final result = state.calc.month(month);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        MonthPicker(month: month, onChanged: onMonthChanged),
        for (var i = 0; i < kTenants.length; i++)
          _TenantCard(key: ValueKey('t$month#$i#${state.dataVersion}'), state: state, month: month, result: result.tenants[i]),
        _ExpenseCard(key: ValueKey('e$month#${state.dataVersion}'), state: state, month: month),
        _ResultsCard(result: result),
      ],
    );
  }
}

const _baseNote = 'קריאה ראשונה – בסיס';
const _belowWarning = 'הקריאה הנוכחית נמוכה מהקודמת – ייתכן שהוחלף שעון';

class _TenantCard extends StatelessWidget {
  final AppState state;
  final String month;
  final TenantResult result;
  const _TenantCard({super.key, required this.state, required this.month, required this.result});

  String? _prevHelper(MeterResult m) {
    if (m.prev == null) return null;
    return m.prevIsAuto ? 'מולא אוטומטית מהחודש הקודם' : 'הוזן ידנית';
  }

  @override
  Widget build(BuildContext context) {
    final t = result.tenant;
    final row = state.row(month, t);
    void upd(void Function(TenantMonth r) f) => state.updateTenant(month, t, f);

    Widget meter(String title, MeterResult m, String unit, bool elec) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: NumField(
              label: 'קריאה אחרונה',
              value: m.prev,
              helper: _prevHelper(m),
              onChanged: (v) => upd((r) => elec ? r.elecPrev = v : r.waterPrev = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumField(
              label: 'קריאה נוכחית',
              value: m.cur,
              helper: m.isBase ? _baseNote : (m.cur != null ? 'צריכה: ${number(m.usage)} $unit' : null),
              warning: m.belowPrev ? _belowWarning : null,
              onChanged: (v) => upd((r) => elec ? r.elecCur = v : r.waterCur = v),
            ),
          ),
        ]),
      ]);
    }

    return SectionCard(
      title: kTenants[t],
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('שולם'),
        Checkbox(value: result.paid, onChanged: (v) => upd((r) => r.paid = v ?? false)),
      ]),
      children: [
        meter('חשמל', result.elec, 'קוט"ש', true),
        const SizedBox(height: 12),
        meter('מים', result.water, 'מ"ק', false),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: NumField(
              label: 'ארנונה (₪)',
              value: row?.arnona ?? 0,
              onChanged: (v) => upd((r) => r.arnona = v ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumField(
              label: 'שכירות (₪)',
              value: row?.rent ?? state.settings.rents[t],
              helper: 'ברירת מחדל מההגדרות',
              onChanged: (v) => upd((r) => r.rent = v ?? 0),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        PhotoStrip(state: state, month: month, tenant: t),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final AppState state;
  final String month;
  const _ExpenseCard({super.key, required this.state, required this.month});

  @override
  Widget build(BuildContext context) {
    final e = state.expense(month) ?? MonthExpense(month: month);
    void upd(void Function(MonthExpense e) f) => state.updateExpense(month, f);
    Widget f(String label, double v, void Function(MonthExpense e, double v) set) => Expanded(
          child: NumField(label: label, value: v, onChanged: (x) => upd((e) => set(e, x ?? 0))),
        );
    return SectionCard(title: 'חיובים שלי מהעירייה והחברות', children: [
      Row(children: [
        f('חשמל (₪)', e.elec, (e, v) => e.elec = v),
        const SizedBox(width: 8),
        f('מים (₪)', e.water, (e, v) => e.water = v),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        f('ארנונה (₪)', e.arnona, (e, v) => e.arnona = v),
        const SizedBox(width: 8),
        f('הוצאות אחרות (₪)', e.other, (e, v) => e.other = v),
      ]),
    ]);
  }
}

class _ResultsCard extends StatelessWidget {
  final MonthResult result;
  const _ResultsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return SectionCard(title: 'תוצאות החודש', children: [
      for (final t in r.tenants)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(t.paid ? '✅' : '⏳', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(kTenants[t.tenant], style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${number(t.elec.usage)} קוט"ש · ${number(t.water.usage)} מ"ק'
                  '${t.elec.isBase || t.water.isBase ? ' · $_baseNote' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
            Text(money(t.total), textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      const Divider(height: 24),
      KV('שולם בפועל מתוך סך ההכנסות', '${money(r.paidIncome)} / ${money(r.income)}'),
      KV.money('סה"כ הכנסות', r.income, bold: true),
      KV.money('דמי ניהול נכסים (${number(r.mgmtPct)}%)', r.mgmtFee),
      KV.money('סה"כ הוצאות (כולל דמי ניהול)', r.expenses, bold: true),
      KV.money('רווח נקי', r.net, bold: true, signColor: true),
      const Divider(height: 24),
      const Text('חלוקת הרווח', style: TextStyle(fontWeight: FontWeight.w600)),
      for (var i = 0; i < kPartners.length; i++)
        KV.money('${kPartners[i]} (${number(r.partnerPcts[i])}%)', r.partnerShares[i]),
    ]);
  }
}
