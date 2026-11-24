import 'package:flutter/gestures.dart';

/// Atalhos físicos: nunca altera a ferramenta escolhida permanentemente.
/// As ações só são ativadas quando o dispositivo realmente envia o botão.
class StylusShortcuts {
  static String? temporaryTool(PointerDeviceKind kind, int buttons,
      {bool useEraser = true, bool useLasso = true}) {
    if (kind == PointerDeviceKind.invertedStylus) {
      return useEraser ? 'eraser' : null;
    }
    if (kind != PointerDeviceKind.stylus) return null;
    if (useLasso && (buttons & kSecondaryStylusButton) != 0) return 'lasso';
    if (useEraser && (buttons & kPrimaryStylusButton) != 0) return 'eraser';
    return null;
  }
}

/// Reconhece um toque rápido com vários dedos ao SOLTAR os dedos.
/// Assim um gesto de zoom ou movimento não dispara Desfazer por engano.
class MultiTouchQuickGestures {
  final Map<int, Offset> _touches = {};
  final Map<int, Offset> _startPositions = {};
  DateTime? _startedAt;
  int _maxFingers = 0;
  bool _moved = false;
  final Duration maxDuration;
  final double maxTravel;

  MultiTouchQuickGestures({this.maxDuration = const Duration(milliseconds: 380),
      this.maxTravel = 14});

  void down(int pointer, Offset position, {DateTime? at}) {
    if (_touches.isEmpty) {
      _startedAt = at ?? DateTime.now();
      _maxFingers = 0;
      _moved = false;
      _startPositions.clear();
    }
    _touches[pointer] = position;
    _startPositions[pointer] = position;
    if (_touches.length > _maxFingers) _maxFingers = _touches.length;
  }

  void move(int pointer, Offset position) {
    if (!_touches.containsKey(pointer)) return;
    _touches[pointer] = position;
    final start = _startPositions[pointer];
    if (start != null && (start - position).distance > maxTravel) _moved = true;
  }

  int? up(int pointer, Offset position, {DateTime? at, bool cancelled = false}) {
    move(pointer, position);
    if (cancelled) _moved = true;
    _touches.remove(pointer);
    if (_touches.isNotEmpty) return null;
    final elapsed = (at ?? DateTime.now()).difference(_startedAt ?? DateTime.now());
    final result = (!_moved && _maxFingers >= 2 &&
       elapsed >= Duration.zero && elapsed <= maxDuration) ? _maxFingers : null;
    reset();
    return result;
  }

  void reset() {
    _touches.clear();
    _startPositions.clear();
    _startedAt = null;
    _maxFingers = 0;
    _moved = false;
  }
}
