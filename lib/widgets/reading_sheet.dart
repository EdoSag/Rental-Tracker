import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../services/meter_ocr.dart';
import '../services/reading_extractor.dart';
import '../state.dart';

/// Reads the meter value from a photo and offers to fill it in.
/// Always asks for a one-tap confirmation, so a misread never slips in silently.
Future<void> showReadingFromPhoto(
    BuildContext context, AppState state, String month, int tenant, String imagePath) async {
  final calcTenant = state.calc.tenant(month, tenant);
  ExtractionResult? result;
  String? error;
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
        SizedBox(width: 16),
        Text('מזהה קריאה מהתמונה...'),
      ]),
    ),
  );
  try {
    final text = await recognizeText(imagePath);
    result = extractReadings(text, prevElec: calcTenant.elec.prev, prevWater: calcTenant.water.prev);
  } catch (e) {
    error = '$e';
  } finally {
    nav.pop();
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _ReadingSheet(
      state: state,
      month: month,
      tenant: tenant,
      result: result,
      error: error,
    ),
  );
}

class _ReadingSheet extends StatefulWidget {
  final AppState state;
  final String month;
  final int tenant;
  final ExtractionResult? result;
  final String? error;
  const _ReadingSheet({required this.state, required this.month, required this.tenant, this.result, this.error});

  @override
  State<_ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends State<_ReadingSheet> {
  late MeterKind _kind = widget.result?.likelyKind ?? MeterKind.elec;
  final _c = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectTop();
  }

  void _selectTop() {
    final list = widget.result?.forKind(_kind) ?? const [];
    _c.text = list.isEmpty ? '' : editable(list.first.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _apply() {
    final v = parseNum(_c.text);
    if (v == null) return;
    widget.state.updateTenant(widget.month, widget.tenant, (r) {
      if (_kind == MeterKind.elec) {
        r.elecCur = v;
      } else {
        r.waterCur = v;
      }
    });
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text('${_kind == MeterKind.elec ? 'חשמל' : 'מים'}: קריאה נוכחית עודכנה ל-${number(v)}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.result?.forKind(_kind) ?? const <ReadingCandidate>[];
    final current = widget.state.row(widget.month, widget.tenant);
    final existing = _kind == MeterKind.elec ? current?.elecCur : current?.waterCur;
    final prev = _kind == MeterKind.elec
        ? widget.state.calc.tenant(widget.month, widget.tenant).elec.prev
        : widget.state.calc.tenant(widget.month, widget.tenant).water.prev;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('זיהוי קריאה מהתמונה – ${kTenants[widget.tenant]}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (widget.error != null)
            Text('לא ניתן היה לקרוא את התמונה. אפשר להזין את הקריאה ידנית.',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          SegmentedButton<MeterKind>(
            segments: const [
              ButtonSegment(value: MeterKind.elec, label: Text('חשמל'), icon: Icon(Icons.bolt)),
              ButtonSegment(value: MeterKind.water, label: Text('מים'), icon: Icon(Icons.water_drop_outlined)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              _selectTop();
            }),
          ),
          const SizedBox(height: 12),
          if (candidates.isEmpty && widget.error == null)
            const Text('לא נמצאו מספרים בתמונה. אפשר להזין את הקריאה ידנית.'),
          if (candidates.isNotEmpty) ...[
            const Text('מספרים שזוהו (המתאים ביותר ראשון):'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final cnd in candidates)
                ChoiceChip(
                  label: Text(number(cnd.value), textDirection: TextDirection.ltr),
                  selected: parseNum(_c.text) == cnd.value,
                  onSelected: (_) => setState(() => _c.text = editable(cnd.value)),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'קריאה נוכחית',
              border: const OutlineInputBorder(),
              helperText: [
                if (prev != null) 'קריאה אחרונה: ${number(prev)}',
                if (existing != null) 'יחליף את הערך הקיים ${number(existing)}',
              ].join(' · '),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: parseNum(_c.text) == null ? null : _apply,
                icon: const Icon(Icons.check),
                label: const Text('מלא קריאה'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('דלג')),
          ]),
        ],
      ),
    );
  }
}
