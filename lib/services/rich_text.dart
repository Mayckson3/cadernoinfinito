import 'package:flutter/material.dart';

/// Character formatting is stored in compact UTF-16 ranges in InkElement.meta.
/// Relative font sizes keep formatting proportional when an object is resized.
typedef TextMarks = ({int flags, int? color, int? highlight, double scale});

class RichTextFormat {
  static const bold = 1, italic = 2, underline = 4, strike = 8;
  static const TextMarks plain = (flags: 0, color: null, highlight: null, scale: 1.0);

  static List<TextMarks> decode(String text, Object? raw) {
    final marks = List<TextMarks>.filled(text.length, plain);
    if (raw is! List) return marks;
    for (final run in raw.whereType<Map>()) {
      final start = run['start'], end = run['end'];
      if (start is! int || end is! int || start < 0 || end <= start || end > text.length) continue;
      final scale = run['scale'];
      final mark = (flags: run['flags'] is int ? (run['flags'] as int) & 15 : 0,
        color: run['color'] is int ? run['color'] as int : null,
        highlight: run['highlight'] is int ? run['highlight'] as int : null,
        scale: scale is num && scale.isFinite ? scale.toDouble().clamp(.008, 125.0).toDouble() : 1.0);
      marks.fillRange(start, end, mark);
    }
    return marks;
  }

  static List<Map<String, dynamic>> encode(List<TextMarks> marks) {
    final runs = <Map<String, dynamic>>[];
    var start = 0;
    while (start < marks.length) {
      final mark = marks[start];
      var end = start + 1;
      while (end < marks.length && marks[end] == mark) { end++; }
      if (mark != plain) {
        runs.add({'start': start, 'end': end, 'flags': mark.flags,
          if (mark.color != null) 'color': mark.color,
          if (mark.highlight != null) 'highlight': mark.highlight,
          if (mark.scale != 1) 'scale': mark.scale});
      }
      start = end;
    }
    return runs;
  }

  static TextStyle style(TextMarks mark, TextStyle base, {bool composing = false}) {
    final decorations = <TextDecoration>[
      if ((mark.flags & underline) != 0 || composing) TextDecoration.underline,
      if ((mark.flags & strike) != 0) TextDecoration.lineThrough,
    ];
    return base.copyWith(
      fontWeight: (mark.flags & bold) != 0 ? FontWeight.bold : FontWeight.w400,
      fontStyle: (mark.flags & italic) != 0 ? FontStyle.italic : FontStyle.normal,
      decoration: decorations.isEmpty ? TextDecoration.none : TextDecoration.combine(decorations),
      color: mark.color == null ? base.color : Color(mark.color!).withValues(alpha: base.color?.a ?? 1.0),
      backgroundColor: mark.highlight == null ? null : Color(mark.highlight!).withValues(alpha: base.color?.a ?? 1.0),
      fontSize: (base.fontSize ?? 18.0) * mark.scale,
    );
  }

  static TextSpan span(String text, List<TextMarks> marks, TextStyle base,
      {TextRange? composing}) {
    final children = <TextSpan>[];
    var start = 0;
    bool isComposing(int i) => composing != null && composing.isValid &&
      i >= composing.start && i < composing.end;
    while (start < text.length) {
      final mark = marks[start];
      final composingHere = isComposing(start);
      var end = start + 1;
      while (end < text.length && marks[end] == mark && isComposing(end) == composingHere) { end++; }
      children.add(TextSpan(text: text.substring(start, end),
        style: style(mark, base, composing: composingHere)));
      start = end;
    }
    return TextSpan(style: base, children: children);
  }

  static TextSpan fromRuns(String text, Object? runs, TextStyle base) =>
    runs is List && runs.isNotEmpty ? span(text, decode(text, runs), base) : TextSpan(text: text, style: base);
}

class RichTextController extends TextEditingController {
  late List<TextMarks> _marks;
  TextMarks _typing = RichTextFormat.plain;
  RichTextController({String text = '', Object? runs}) : super(text: text) {
    _marks = RichTextFormat.decode(text, runs);
    selection = TextSelection.collapsed(offset: text.length);
  }
  List<Map<String, dynamic>> get runs => RichTextFormat.encode(_marks);
  TextMarks get current {
    if (!selection.isValid || selection.isCollapsed || _marks.isEmpty) return _typing;
    return _marks[selection.start.clamp(0, _marks.length - 1).toInt()];
  }

  @override
  set value(TextEditingValue next) {
    final old = super.value;
    if (old.text != next.text) {
      var start = 0;
      var oldEnd = old.text.length, newEnd = next.text.length;
      // Prefer the previous selection when it explains the edit. This also
      // handles inserting repeated letters beside differently formatted runs.
      final s = old.selection;
      if (s.isValid && s.end <= oldEnd && next.text.length >= s.start + oldEnd - s.end &&
          next.text.startsWith(old.text.substring(0, s.start)) &&
          next.text.endsWith(old.text.substring(s.end))) {
        start = s.start;
        newEnd = next.text.length - (oldEnd - s.end);
        oldEnd = s.end;
      } else {
        while (start < oldEnd && start < newEnd && old.text.codeUnitAt(start) == next.text.codeUnitAt(start)) { start++; }
        while (oldEnd > start && newEnd > start && old.text.codeUnitAt(oldEnd - 1) == next.text.codeUnitAt(newEnd - 1)) { oldEnd--; newEnd--; }
      }
      final mark = oldEnd > start && start < _marks.length ? _marks[start] : _typing;
      _marks = [..._marks.take(start), ...List<TextMarks>.filled(newEnd - start, mark), ..._marks.skip(oldEnd)];
      _typing = mark;
    } else if (old.selection != next.selection && next.selection.isValid && _marks.isNotEmpty) {
      final at = next.selection.start;
      _typing = _marks[(at > 0 && next.selection.isCollapsed ? at - 1 : at).clamp(0, _marks.length - 1).toInt()];
    }
    super.value = next;
  }

  void _apply(TextMarks Function(TextMarks) change) {
    final s = selection;
    if (!s.isValid || s.isCollapsed) {
      _typing = change(_typing);
    } else {
      for (var i = s.start.clamp(0, _marks.length).toInt(); i < s.end && i < _marks.length; i++) {
        _marks[i] = change(_marks[i]);
      }
      _typing = change(_typing);
    }
    notifyListeners();
  }
  bool active(int flag) => (current.flags & flag) != 0;
  void toggle(int flag) {
    final enable = !active(flag);
    _apply((m) => (flags: enable ? m.flags | flag : m.flags & ~flag,
      color: m.color, highlight: m.highlight, scale: m.scale));
  }
  void setColor(int? color) => _apply((m) => (flags: m.flags, color: color, highlight: m.highlight, scale: m.scale));
  void setHighlight(int? color) => _apply((m) => (flags: m.flags, color: m.color, highlight: color, scale: m.scale));
  void setRelativeSize(double scale) => _apply((m) => (flags: m.flags, color: m.color,
    highlight: m.highlight, scale: scale.clamp(.008, 125.0).toDouble()));
  void clearFormatting() => _apply((_) => RichTextFormat.plain);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) =>
    RichTextFormat.span(text, _marks, style ?? const TextStyle(fontSize: 18),
      composing: withComposing && value.isComposingRangeValid ? value.composing : null);
}
