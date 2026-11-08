import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';

/// Numeric text field that reports every keystroke (auto-save) and follows
/// outside changes to [value] while it isn't being edited.
class NumField extends StatefulWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final String? helper;
  final String? warning;
  final String? hint;
  final String? suffix;

  const NumField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.warning,
    this.hint,
    this.suffix,
  });

  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController _c = TextEditingController(text: editable(widget.value));
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(NumField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && parseNum(_c.text) != widget.value) {
      _c.text = editable(widget.value);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warnColor = Colors.orange.shade800;
    return TextField(
      controller: _c,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixText: widget.suffix,
        isDense: true,
        border: const OutlineInputBorder(),
        helperText: widget.warning ?? widget.helper,
        helperMaxLines: 3,
        helperStyle: widget.warning != null ? TextStyle(color: warnColor, fontWeight: FontWeight.w600) : null,
        enabledBorder: widget.warning != null
            ? OutlineInputBorder(borderSide: BorderSide(color: warnColor))
            : null,
      ),
      onChanged: (s) => widget.onChanged(parseNum(s)),
    );
  }
}
