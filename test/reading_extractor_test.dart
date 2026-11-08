import 'package:flutter_test/flutter_test.dart';
import 'package:rental_tracker/services/reading_extractor.dart';

void main() {
  test('digital electricity meter with kWh and a serial number', () {
    const text = 'Landis+Gyr\nNo. 7712345678\n012458.6 kWh\n1.8.0\n12/10/2026 08:15';
    final r = extractReadings(text, prevElec: 12210, prevWater: 300);
    expect(r.unitHint, MeterKind.elec);
    expect(r.likelyKind, MeterKind.elec);
    expect(r.elec.first.value, 12458.6);
  });

  test('water odometer with spaced wheels and red decimal digits', () {
    const text = 'm³\n0 0 3 1 2 4 5\nQ3 2.5\nSN 21004567';
    final r = extractReadings(text, prevElec: 5000, prevWater: 3118.2);
    expect(r.likelyKind, MeterKind.water);
    expect(r.water.first.value, 3124.5);
  });

  test('app screenshot with thousands separator and Hebrew units', () {
    const text = 'קריאה נוכחית\n15,320 קוט"ש\nקריאה קודמת 15,010';
    final r = extractReadings(text, prevElec: 15010);
    expect(r.likelyKind, MeterKind.elec);
    expect(r.elec.first.value, 15320);
  });

  test('OCR letter look-alikes are fixed', () {
    const text = 'O12S4O kWh';
    final r = extractReadings(text, prevElec: 12000);
    expect(r.elec.first.value, 12540);
  });

  test('no previous reading: still returns the numbers found', () {
    const text = 'Water meter\n00456';
    final r = extractReadings(text);
    expect(r.likelyKind, MeterKind.water);
    expect(r.water.map((c) => c.value), contains(456));
  });

  test('chooses the meter whose last reading fits when there is no unit text', () {
    const text = '04512';
    final r = extractReadings(text, prevElec: 4480, prevWater: 210);
    expect(r.likelyKind, MeterKind.elec);
    expect(r.elec.first.value, 4512);
  });

  test('no numbers', () {
    final r = extractReadings('hello');
    expect(r.elec, isEmpty);
    expect(r.water, isEmpty);
  });
}
