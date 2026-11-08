import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../calc.dart';
import '../models.dart';
import '../state.dart';

const summarySheet = 'סיכום';
const tenantsSheet = 'פירוט שוכרים';

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// Builds the .xlsx bytes: two right-to-left sheets.
List<int> buildExcel(Calculator calc) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, summarySheet);
  final s = excel[summarySheet];
  final t = excel[tenantsSheet];
  s.isRTL = true;
  t.isRTL = true;

  final bold = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
  CellValue txt(String v) => TextCellValue(v);
  CellValue? numv(double? v) => v == null ? null : DoubleCellValue(_r2(v));

  final sHead = [
    'חודש', 'שכירות', 'חשמל', 'מים', 'ארנונה', 'סה"כ הכנסות', 'הוצאות עירייה/חברות',
    'דמי ניהול', 'הוצאות אחרות', 'רווח נקי', ...kPartners,
  ];
  s.appendRow([for (final h in sHead) txt(h)]);
  final months = calc.allMonths();
  for (final m in months) {
    s.appendRow([
      txt(monthLabel(m.month)),
      numv(m.rent), numv(m.elecIncome), numv(m.waterIncome), numv(m.arnonaIncome),
      numv(m.income), numv(m.cityExpenses), numv(m.mgmtFee), numv(m.otherExpenses), numv(m.net),
      for (final x in m.partnerShares) numv(x),
    ]);
  }
  final tot = Totals.of(months, kPartners.length);
  s.appendRow([
    txt('סה"כ'),
    numv(tot.rent), numv(tot.elecIncome), numv(tot.waterIncome), numv(tot.arnonaIncome),
    numv(tot.income), numv(tot.cityExpenses), numv(tot.mgmtFee), numv(tot.otherExpenses), numv(tot.net),
    for (final x in tot.partnerShares) numv(x),
  ]);

  final tHead = [
    'חודש', 'שוכר', 'קריאת חשמל', 'קריאת מים', 'קוט"ש', 'מ"ק', 'שכירות',
    'חשמל ₪', 'מים ₪', 'ארנונה ₪', 'סה"כ', 'שולם',
  ];
  t.appendRow([for (final h in tHead) txt(h)]);
  for (final m in months) {
    for (final r in m.tenants) {
      t.appendRow([
        txt(monthLabel(m.month)),
        txt(kTenants[r.tenant]),
        numv(r.elec.cur), numv(r.water.cur),
        numv(r.elec.usage), numv(r.water.usage),
        numv(r.rent), numv(r.elec.charge), numv(r.water.charge), numv(r.arnona), numv(r.total),
        txt(r.paid ? 'כן' : 'לא'),
      ]);
    }
  }

  for (final sheet in [s, t]) {
    final cols = sheet == s ? sHead.length : tHead.length;
    for (var c = 0; c < cols; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = bold;
      sheet.setColumnWidth(c, c == 0 ? 16 : 14);
    }
  }
  final lastRow = months.length + 1;
  for (var c = 0; c < sHead.length; c++) {
    s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: lastRow)).cellStyle = CellStyle(bold: true);
  }
  excel.setDefaultSheet(summarySheet);
  return forceRtl(excel.encode()!);
}

/// The excel package doesn't reliably write right-to-left for new sheets,
/// so set rightToLeft="1" on every worksheet's sheetView directly.
List<int> forceRtl(List<int> xlsx) {
  final input = ZipDecoder().decodeBytes(xlsx);
  final out = Archive();
  for (final f in input.files) {
    if (f.isFile && f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
      var xml = utf8.decode(f.content as List<int>);
      xml = xml.replaceAllMapped(RegExp(r'<sheetView(?=[\s/>])(?![^>]*rightToLeft)'), (_) => '<sheetView rightToLeft="1"');
      final bytes = utf8.encode(xml);
      out.addFile(ArchiveFile(f.name, bytes.length, bytes));
    } else {
      out.addFile(f);
    }
  }
  return ZipEncoder().encode(out)!;
}

Future<void> shareExcel(AppState state) async {
  final bytes = buildExcel(state.calc);
  final dir = await getTemporaryDirectory();
  final now = DateTime.now();
  final file = File(p.join(dir.path, 'דוח_הכנסות_${monthKey(now.year, now.month)}.xlsx'));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
    subject: 'דוח הכנסות והוצאות',
  ));
}
