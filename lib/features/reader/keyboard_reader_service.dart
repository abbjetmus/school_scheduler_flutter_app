import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Läsare som skriver som ett tangentbord — de flesta billiga RFID- och
/// streckkodsläsare: de "skriver" koden snabbt och trycker Enter.
///
/// Tjänsten lyssnar på tangentbordet i hela appen och skickar en kod när
/// tecken kommit tätt (mindre än [maxGap] mellan dem) och avslutats med Enter.
/// En människa skriver inte så fort, så vanlig inmatning blir aldrig en kod.
/// När ett textfält har fokus gör tjänsten ingenting — då hamnar koden i fältet,
/// som får hantera den själv (t.ex. sökfält och "Skriv kod").
class KeyboardReaderService {
  // 100 ms räcker även för Bluetooth-läsare i tangentbordsläge (t.ex.
  // Okeeyseda-läsaren skolan redan har), som skriver långsammare än USB.
  KeyboardReaderService({this.maxGap = const Duration(milliseconds: 100), this.minLength = 4});

  final Duration maxGap;
  final int minLength;

  final _codeController = StreamController<String>.broadcast();
  Stream<String> get codes => _codeController.stream;

  final _buffer = StringBuffer();
  DateTime? _last;
  bool _enabled = true;
  bool _attached = false;

  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    _buffer.clear();
  }

  void attach() {
    if (_attached) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _attached = false;
  }

  bool _textFieldHasFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText || context.findAncestorStateOfType<EditableTextState>() != null;
  }

  bool _onKey(KeyEvent event) {
    if (!_enabled || event is KeyUpEvent || _textFieldHasFocus()) return false;

    final now = DateTime.now();
    if (_last != null && now.difference(_last!) > maxGap) _buffer.clear();
    _last = now;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      if (code.length >= minLength) {
        _codeController.add(code);
        return true;
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.length == 1 && char.codeUnitAt(0) >= 0x20) {
      _buffer.write(char);
    }
    return false;
  }

  void dispose() {
    detach();
    _codeController.close();
  }
}
