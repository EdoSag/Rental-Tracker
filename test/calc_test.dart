import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_tracker/calc.dart';
import 'package:rental_tracker/models.dart';
import 'package:rental_tracker/services/backup.dart';
import 'package:rental_tracker/services/excel_export.dart';

/// Sample data: 3 months, 4 tenants. Expected values were computed by hand.
Settings sampleSettings() => Settings(
      kwhPrice: 0.65,
      waterPrice: 12,
      mgmtPct: 10,
      rents: [3000, 3200, 2800, 3500],
      partnerPcts: [25, 25, 25, 25],
    );

TenantMonth tm(String m, int t, double rent, double? e, double? w,
        {double? ePrev, bool paid = false}) =>
    TenantMonth(month: m, tenant: t, rent: rent, elecCur: e, waterCur: w, elecPrev: ePrev, arnona: 300, paid: paid);

List<TenantMonth> sampleRows() => [
      // August: first readings, base only.
      tm('2026-08', 0, 3000, 1000, 100),
      tm('2026-08', 1, 3200, 2000, 200),
      tm('2026-08', 2, 2800, 3000, 300),
      tm('2026-08', 3, 3500, 4000, 400),
      // September
      tm('2026-09', 0, 3000, 1200, 105, paid: true),
      tm('2026-09', 1, 3200, 2150, 208, paid: true),
      tm('2026-09', 2, 2800, 3300, 303),
      tm('2026-09', 3, 3500, 4100, 410),
      // October: Yaakov's meter replaced, Katya manual previous reading, Anna no readings.
      tm('2026-10', 0, 3000, 50, 110, paid: true),
      tm('2026-10', 1, 3200, 2250, 215, ePrev: 2100, paid: true),
      tm('2026-10', 2, 2800, null, null, paid: true),
      tm('2026-10', 3, 3500, 4300, 420, paid: true),
    ];

List<MonthExpense> sampleExpenses() => [
      MonthExpense(month: '2026-08', arnona: 1500, other: 200),
      MonthExpense(month: '2026-09', elec: 400, water: 250, arnona: 1500),
      MonthExpense(month: '2026-10', elec: 500, water: 300, arnona: 1500, other: 1000),
    ];

Calculator sample([Settings? s]) => Calculator(sampleRows(), sampleExpenses(), s ?? sampleSettings());

void main() {
  test('month 1: first readings are a base, no usage charge', () {
    final m = sample().month('2026-08');
    for (final t in m.tenants) {
      expect(t.elec.isBase, isTrue);
      expect(t.water.isBase, isTrue);
      expect(t.elec.charge, 0);
      expect(t.water.charge, 0);
    }
    expect(m.income, 13700);
    expect(m.mgmtFee, closeTo(1370, 1e-9));
    expect(m.expenses, closeTo(3070, 1e-9));
    expect(m.net, closeTo(10630, 1e-9));
    expect(m.partnerShares, everyElement(closeTo(2657.5, 1e-9)));
  });

  test('month 2: usage, charges, paid amount', () {
    final m = sample().month('2026-09');
    final y = m.tenants[0];
    expect(y.elec.prev, 1000);
    expect(y.elec.prevIsAuto, isTrue);
    expect(y.elec.usage, 200);
    expect(y.elec.charge, closeTo(130, 1e-9));
    expect(y.water.usage, 5);
    expect(y.water.charge, 60);
    expect(y.total, closeTo(3490, 1e-9));
    expect(m.tenants[1].total, closeTo(3693.5, 1e-9));
    expect(m.tenants[2].total, closeTo(3331, 1e-9));
    expect(m.tenants[3].total, closeTo(3985, 1e-9));
    expect(m.income, closeTo(14499.5, 1e-9));
    expect(m.paidIncome, closeTo(7183.5, 1e-9));
    expect(m.mgmtFee, closeTo(1449.95, 1e-9));
    expect(m.expenses, closeTo(3599.95, 1e-9));
    expect(m.net, closeTo(10899.55, 1e-9));
  });

  test('month 3: meter replaced, manual previous reading, missing readings', () {
    final m = sample().month('2026-10');
    final y = m.tenants[0];
    expect(y.elec.belowPrev, isTrue);
    expect(y.elec.usage, 0);
    expect(y.total, closeTo(3360, 1e-9));
    final k = m.tenants[1];
    expect(k.elec.prev, 2100);
    expect(k.elec.prevIsAuto, isFalse);
    expect(k.elec.usage, 150);
    expect(k.total, closeTo(3681.5, 1e-9));
    expect(m.tenants[2].total, 3100);
    expect(m.tenants[2].elec.isBase, isFalse);
    expect(m.tenants[3].total, closeTo(4050, 1e-9));
    expect(m.income, closeTo(14191.5, 1e-9));
    expect(m.paidIncome, closeTo(14191.5, 1e-9));
    expect(m.expenses, closeTo(4719.15, 1e-9));
    expect(m.net, closeTo(9472.35, 1e-9));
  });

  test('last reading carries over months without a reading', () {
    final c = sample();
    expect(c.lastReadingBefore(2, '2026-11', true), 3300);
    expect(c.lastReadingBefore(0, '2026-11', true), 50);
    expect(c.lastReadingBefore(0, '2026-08', true), isNull);
  });

  test('totals and unequal partner split', () {
    final s = sampleSettings()..partnerPcts = [40, 30, 20, 10];
    final c = sample(s);
    final t = Totals.of(c.allMonths(), 4);
    expect(t.income, closeTo(42391, 1e-6));
    expect(t.net, closeTo(31001.9, 1e-6));
    expect(t.partnerShares[0], closeTo(12400.76, 1e-6));
    expect(t.partnerShares[3], closeTo(3100.19, 1e-6));
    expect(t.partnerShares.reduce((a, b) => a + b), closeTo(t.net, 1e-6));
  });

  test('excel export has two RTL sheets with the right numbers', () {
    final bytes = buildExcel(sample());
    final x = Excel.decodeBytes(bytes);
    expect(x.tables.keys, containsAll([summarySheet, tenantsSheet]));
    final s = x.tables[summarySheet]!;
    final t = x.tables[tenantsSheet]!;
    expect(s.isRTL, isTrue);
    expect(t.isRTL, isTrue);
    expect(s.maxRows, 5); // header + 3 months + total
    expect(t.maxRows, 13); // header + 12 tenant rows
    expect((s.rows[2][5]!.value as DoubleCellValue).value, 14499.5);
    expect((s.rows[2][9]!.value as DoubleCellValue).value, 10899.55);
    expect(t.rows[5][1]!.value.toString(), 'יעקב');
    expect(t.rows[5][11]!.value.toString(), 'כן');
  });

  test('backup zip round trip', () {
    final photo = Photo(month: '2026-09', tenant: 1, fileName: 'a.jpg');
    final zip = buildBackupZip(
      rows: sampleRows(),
      expenses: sampleExpenses(),
      photos: [photo],
      settings: sampleSettings(),
      readPhoto: (_) => [1, 2, 3],
    );
    final c = parseBackupZip(zip);
    expect(c.rows.length, 12);
    expect(c.expenses.length, 3);
    expect(c.photos.single.fileName, 'a.jpg');
    expect(c.photoBytes['a.jpg'], [1, 2, 3]);
    expect(c.settings.mgmtPct, 10);
    final m = Calculator(c.rows, c.expenses, c.settings).month('2026-10');
    expect(m.net, closeTo(9472.35, 1e-9));
  });
}
