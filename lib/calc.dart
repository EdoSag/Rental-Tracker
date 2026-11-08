// Pure calculation logic (no Flutter, no database) so it can be unit tested.
import 'models.dart';

class MeterResult {
  final double? prev; // effective last reading (manual or automatic)
  final double? cur;
  final bool prevIsAuto; // prev came from an earlier month
  final bool isBase; // first reading: no previous reading exists
  final bool belowPrev; // current reading lower than previous (meter replaced?)
  final double usage;
  final double charge;

  MeterResult({
    required this.prev,
    required this.cur,
    required this.prevIsAuto,
    required this.isBase,
    required this.belowPrev,
    required this.usage,
    required this.charge,
  });
}

class TenantResult {
  final int tenant;
  final double rent;
  final MeterResult elec;
  final MeterResult water;
  final double arnona;
  final bool paid;

  TenantResult(this.tenant, this.rent, this.elec, this.water, this.arnona, this.paid);

  double get total => rent + elec.charge + water.charge + arnona;
}

class MonthResult {
  final String month;
  final List<TenantResult> tenants;
  final MonthExpense expense;
  final double mgmtPct;
  final List<double> partnerPcts;

  MonthResult(this.month, this.tenants, this.expense, this.mgmtPct, this.partnerPcts);

  double get rent => tenants.fold(0.0, (a, t) => a + t.rent);
  double get elecIncome => tenants.fold(0.0, (a, t) => a + t.elec.charge);
  double get waterIncome => tenants.fold(0.0, (a, t) => a + t.water.charge);
  double get arnonaIncome => tenants.fold(0.0, (a, t) => a + t.arnona);
  double get income => tenants.fold(0.0, (a, t) => a + t.total);
  double get paidIncome => tenants.where((t) => t.paid).fold(0.0, (a, t) => a + t.total);
  double get mgmtFee => income * mgmtPct / 100;
  double get cityExpenses => expense.cityTotal;
  double get otherExpenses => expense.other;
  double get expenses => expense.cityTotal + expense.other + mgmtFee;
  double get net => income - expenses;
  List<double> get partnerShares => [for (final p in partnerPcts) net * p / 100];
}

/// Aggregate over several months.
class Totals {
  double rent = 0, elecIncome = 0, waterIncome = 0, arnonaIncome = 0;
  double income = 0, cityExpenses = 0, otherExpenses = 0, mgmtFee = 0, expenses = 0, net = 0;
  late List<double> partnerShares;

  Totals(int partners) {
    partnerShares = List.filled(partners, 0);
  }

  factory Totals.of(Iterable<MonthResult> months, int partners) {
    final t = Totals(partners);
    for (final m in months) {
      t.rent += m.rent;
      t.elecIncome += m.elecIncome;
      t.waterIncome += m.waterIncome;
      t.arnonaIncome += m.arnonaIncome;
      t.income += m.income;
      t.cityExpenses += m.cityExpenses;
      t.otherExpenses += m.otherExpenses;
      t.mgmtFee += m.mgmtFee;
      t.expenses += m.expenses;
      t.net += m.net;
      final s = m.partnerShares;
      for (var i = 0; i < partners; i++) {
        t.partnerShares[i] += s[i];
      }
    }
    return t;
  }
}

class Calculator {
  final Map<String, TenantMonth> rows; // key: "$month#$tenant"
  final Map<String, MonthExpense> expenses;
  final Settings settings;

  Calculator(Iterable<TenantMonth> rows, Iterable<MonthExpense> expenses, this.settings)
      : rows = {for (final r in rows) '${r.month}#${r.tenant}': r},
        expenses = {for (final e in expenses) e.month: e};

  static String rowKey(String month, int tenant) => '$month#$tenant';

  /// Months that have any saved data, sorted ascending.
  List<String> get months {
    final s = <String>{...rows.values.map((r) => r.month), ...expenses.keys};
    return s.toList()..sort();
  }

  /// Latest current reading entered for [tenant] in a month before [month].
  double? lastReadingBefore(int tenant, String month, bool elec) {
    String? best;
    double? value;
    for (final r in rows.values) {
      if (r.tenant != tenant || r.month.compareTo(month) >= 0) continue;
      final v = elec ? r.elecCur : r.waterCur;
      if (v == null) continue;
      if (best == null || r.month.compareTo(best) > 0) {
        best = r.month;
        value = v;
      }
    }
    return value;
  }

  MeterResult _meter(int tenant, String month, double? manualPrev, double? cur, bool elec) {
    final auto = manualPrev == null;
    final prev = manualPrev ?? lastReadingBefore(tenant, month, elec);
    final price = elec ? settings.kwhPrice : settings.waterPrice;
    if (cur == null) {
      return MeterResult(
          prev: prev, cur: null, prevIsAuto: auto, isBase: false, belowPrev: false, usage: 0, charge: 0);
    }
    if (prev == null) {
      return MeterResult(
          prev: null, cur: cur, prevIsAuto: auto, isBase: true, belowPrev: false, usage: 0, charge: 0);
    }
    final diff = cur - prev;
    final usage = diff < 0 ? 0.0 : diff;
    return MeterResult(
      prev: prev,
      cur: cur,
      prevIsAuto: auto,
      isBase: false,
      belowPrev: diff < 0,
      usage: usage,
      charge: usage * price,
    );
  }

  TenantResult tenant(String month, int tenant) {
    final r = rows[rowKey(month, tenant)];
    return TenantResult(
      tenant,
      r?.rent ?? 0,
      _meter(tenant, month, r?.elecPrev, r?.elecCur, true),
      _meter(tenant, month, r?.waterPrev, r?.waterCur, false),
      r?.arnona ?? 0,
      r?.paid ?? false,
    );
  }

  MonthResult month(String month) => MonthResult(
        month,
        [for (var i = 0; i < kTenants.length; i++) tenant(month, i)],
        expenses[month] ?? MonthExpense(month: month),
        settings.mgmtPct,
        List.of(settings.partnerPcts),
      );

  List<MonthResult> allMonths() => [for (final m in months) month(m)];
}
