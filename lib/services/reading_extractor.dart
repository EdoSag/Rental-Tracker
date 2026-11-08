// Picks likely meter readings out of OCR text. Pure Dart so it can be unit tested.

enum MeterKind { elec, water }

class ReadingCandidate {
  final double value;
  final String source; // the text it came from
  final double score; // higher is better
  ReadingCandidate(this.value, this.source, this.score);

  @override
  String toString() => 'ReadingCandidate($value, "$source", $score)';
}

class ExtractionResult {
  final List<ReadingCandidate> elec;
  final List<ReadingCandidate> water;
  final MeterKind? unitHint; // from "kWh" / "m³" etc. in the image
  ExtractionResult(this.elec, this.water, this.unitHint);

  /// Which meter the photo most likely shows.
  MeterKind get likelyKind {
    if (unitHint != null) return unitHint!;
    final e = elec.isEmpty ? double.negativeInfinity : elec.first.score;
    final w = water.isEmpty ? double.negativeInfinity : water.first.score;
    return w > e ? MeterKind.water : MeterKind.elec;
  }

  List<ReadingCandidate> forKind(MeterKind k) => k == MeterKind.elec ? elec : water;
}

final _elecHint = RegExp(r'(kwh|kw\s*h|קוט"?ש|קוט״ש|קילוואט|חשמל)', caseSensitive: false);
final _waterHint = RegExp(r'(m3|m³|מ"ק|מ״ק|קוב|מים|water)', caseSensitive: false);

MeterKind? unitHintOf(String text) {
  final e = _elecHint.hasMatch(text);
  final w = _waterHint.hasMatch(text);
  if (e && !w) return MeterKind.elec;
  if (w && !e) return MeterKind.water;
  return null;
}

/// Characters OCR often confuses with digits on meter displays.
String _fixDigitLookalikes(String token) {
  final digits = token.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (digits < 2) return token;
  return token
      .replaceAll(RegExp(r'[oOD]'), '0')
      .replaceAll(RegExp(r'[lI|]'), '1')
      .replaceAll(RegExp(r'[S]'), '5')
      .replaceAll(RegExp(r'[B]'), '8');
}

/// Raw numbers found in the text, each with the text it came from.
List<MapEntry<double, String>> _numbers(String text) {
  final out = <MapEntry<double, String>>[];
  for (var line in text.split('\n')) {
    line = line.trim();
    if (line.isEmpty) continue;
    // Skip dates and times like 12/03/2026 or 14:35.
    final cleaned = line.replaceAll(RegExp(r'\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}'), ' ').replaceAll(RegExp(r'\d{1,2}:\d{2}'), ' ');
    final fixed = cleaned.split(RegExp(r'\s+')).map(_fixDigitLookalikes).join(' ');

    // Tokens such as 12,345.6  12345,6  012345
    for (final m in RegExp(r'\d[\d,.]*').allMatches(fixed)) {
      final v = _parseToken(m.group(0)!);
      if (v != null) out.add(MapEntry(v, m.group(0)!));
    }
    // Digits separated by spaces (odometer wheels): "0 1 2 3 4"
    final spaced = RegExp(r'(?:\d\s+){2,}\d').allMatches(fixed);
    for (final m in spaced) {
      final joined = m.group(0)!.replaceAll(RegExp(r'\s+'), '');
      final v = double.tryParse(joined);
      if (v != null) out.add(MapEntry(v, m.group(0)!));
    }
  }
  return out;
}

double? _parseToken(String t) {
  t = t.replaceAll(RegExp(r'[.,]+$'), '');
  if (t.isEmpty) return null;
  // 12,345 or 1,234,567(.8)  -> thousands separators
  if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(t)) return double.tryParse(t.replaceAll(',', ''));
  // 12345,6 -> decimal comma
  if (RegExp(r'^\d+,\d{1,3}$').hasMatch(t)) return double.tryParse(t.replaceAll(',', '.'));
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return double.tryParse(t);
  return null;
}

/// Ranks candidate readings for one meter given its last reading.
List<ReadingCandidate> _rank(List<MapEntry<double, String>> nums, double? prev, bool hintMatches) {
  final seen = <double>{};
  final out = <ReadingCandidate>[];

  void add(double v, String src, double score) {
    if (seen.add(v)) out.add(ReadingCandidate(v, src, score));
  }

  for (final n in nums) {
    final digits = n.value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 2 || digits.length > 9) continue; // too short, or a serial number
    final variants = <double>[n.key];
    // Odometer-style meters: last 1-3 digits are often decimals (red wheels).
    if (prev != null && !n.value.contains(RegExp(r'[.,]'))) {
      for (var d = 1; d <= 3 && d < digits.length; d++) {
        variants.add(n.key / _pow10(d));
      }
    }
    for (final v in variants) {
      var score = 0.0;
      if (hintMatches) score += 1;
      if (digits.length >= 4) score += 0.5;
      if (prev != null) {
        final diff = v - prev;
        if (diff == 0) {
          score += 3; // same as last month: often the previous reading printed on a screenshot
        } else if (diff > 0) {
          // A month of use is small relative to the meter total.
          final allowed = (prev.abs() * 0.5) + 3000;
          score += diff <= allowed ? 5 - (diff / allowed) * 2 : 0.5;
        } else {
          score -= 2; // lower than last reading: possible but unlikely
        }
        if (v != n.key) score -= 0.5; // prefer the number as written
      }
      add(v, n.value, score);
    }
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out.take(6).toList();
}

double _pow10(int d) => [1.0, 10.0, 100.0, 1000.0][d];

ExtractionResult extractReadings(String text, {double? prevElec, double? prevWater}) {
  final hint = unitHintOf(text);
  final nums = _numbers(text);
  return ExtractionResult(
    _rank(nums, prevElec, hint == MeterKind.elec),
    _rank(nums, prevWater, hint == MeterKind.water),
    hint,
  );
}
