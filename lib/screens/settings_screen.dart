import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../services/backup.dart';
import '../state.dart';
import '../widgets/common.dart';
import '../widgets/num_field.dart';

class SettingsScreen extends StatelessWidget {
  final AppState state;
  final String currentMonth;
  const SettingsScreen({super.key, required this.state, required this.currentMonth});

  void _upd(void Function(Settings s) f) => state.updateSettings(f, currentMonth: currentMonth);

  Future<void> _backup(BuildContext context) async {
    try {
      await shareBackup(state);
    } catch (e) {
      if (context.mounted) _snack(context, 'הגיבוי נכשל: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final content = await pickBackup();
      if (content == null || !context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('לשחזר מגיבוי?'),
          content: Text(
              'כל הנתונים והתמונות הקיימים בטלפון יוחלפו בתוכן הגיבוי '
              '(${content.rows.map((r) => r.month).toSet().length} חודשים, ${content.photos.length} תמונות).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ביטול')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('שחזר')),
          ],
        ),
      );
      if (ok != true) return;
      await restoreBackup(state, content);
      if (context.mounted) _snack(context, 'השחזור הושלם');
    } catch (e) {
      if (context.mounted) _snack(context, 'השחזור נכשל: $e');
    }
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final s = state.settings;
    final sum = s.partnerPctSum;
    final sumOk = (sum - 100).abs() < 0.001;
    return ListView(
      key: ValueKey(state.dataVersion),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        SectionCard(title: 'מחירים', children: [
          NumField(label: 'מחיר לקוט"ש (₪)', value: s.kwhPrice, onChanged: (v) => _upd((s) => s.kwhPrice = v ?? 0)),
          const SizedBox(height: 12),
          NumField(label: 'מחיר למ"ק מים (₪)', value: s.waterPrice, onChanged: (v) => _upd((s) => s.waterPrice = v ?? 0)),
          const SizedBox(height: 12),
          NumField(
            label: 'דמי ניהול נכסים (%)',
            value: s.mgmtPct,
            suffix: '%',
            helper: 'אחוז מסך ההכנסות',
            onChanged: (v) => _upd((s) => s.mgmtPct = v ?? 0),
          ),
        ]),
        SectionCard(title: 'שכר דירה חודשי', children: [
          for (var i = 0; i < kTenants.length; i++) ...[
            NumField(
              label: '${kTenants[i]} (₪)',
              value: s.rents[i],
              onChanged: (v) => _upd((s) => s.rents[i] = v ?? 0),
            ),
            const SizedBox(height: 12),
          ],
          Text('שינוי כאן מעדכן את ${monthLabel(currentMonth)} והחודשים שאחריו. חודשים קודמים נשארים כמו שהיו.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        SectionCard(title: 'חלוקת רווחים בין השותפים', children: [
          for (var i = 0; i < kPartners.length; i++) ...[
            NumField(
              label: kPartners[i],
              value: s.partnerPcts[i],
              suffix: '%',
              onChanged: (v) => _upd((s) => s.partnerPcts[i] = v ?? 0),
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Icon(sumOk ? Icons.check_circle : Icons.warning_amber_rounded,
                color: sumOk ? Colors.green.shade700 : Colors.orange.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sumOk ? 'סה"כ 100%' : 'שים לב: סכום האחוזים הוא ${number(sum)}% ולא 100%',
                style: TextStyle(
                    color: sumOk ? Colors.green.shade700 : Colors.orange.shade800, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ]),
        SectionCard(title: 'גיבוי ושחזור', children: [
          const Text('כל הנתונים והתמונות נשמרים רק בטלפון. מומלץ לגבות מדי פעם לקובץ zip (Drive, מייל, WhatsApp).'),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _backup(context),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('ייצוא גיבוי (zip)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _restore(context),
            icon: const Icon(Icons.restore),
            label: const Text('שחזור מגיבוי'),
          ),
        ]),
      ],
    );
  }
}
