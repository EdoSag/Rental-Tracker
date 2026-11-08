import 'package:intl/intl.dart';

final _whole = NumberFormat('#,##0', 'en_US');
final _frac = NumberFormat('#,##0.00', 'en_US');
final _num = NumberFormat('#,##0.##', 'en_US');

/// "1,234 ₪" or "1,234.50 ₪", with thousands separators.
String money(double v) {
  final r = (v * 100).roundToDouble() / 100;
  final s = r == r.roundToDouble() ? _whole.format(r) : _frac.format(r);
  return '$s ₪';
}

/// Plain number with thousands separators and up to 2 decimals.
String number(double v) => _num.format(v);

/// For editable fields: no thousands separators, no trailing ".0".
String editable(double? v) {
  if (v == null) return '';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}
