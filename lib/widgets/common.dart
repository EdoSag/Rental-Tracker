import 'package:flutter/material.dart';

import '../format.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const SectionCard({super.key, required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// "label ........ value" row.
class KV extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const KV(this.label, this.value, {super.key, this.bold = false, this.color});

  factory KV.money(String label, double v, {bool bold = false, bool signColor = false}) => KV(
        label,
        money(v),
        bold: bold,
        color: signColor ? (v >= 0 ? Colors.green.shade700 : Colors.red.shade700) : null,
      );

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style, textDirection: TextDirection.ltr),
      ]),
    );
  }
}

Color signColor(double v) => v >= 0 ? Colors.green.shade700 : Colors.red.shade700;
