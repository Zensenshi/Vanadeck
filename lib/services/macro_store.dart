import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/macro.dart';

class MacroBackup {
  const MacroBackup({required this.macros, required this.bookTitles});

  final Map<String, Macro> macros;
  final Map<int, String> bookTitles;
}

class MacroStore {
  const MacroStore();

  static const _channel = MethodChannel('vanadeck/macros');

  Future<Map<String, Macro>> load() async {
    try {
      final payload = await _channel.invokeMethod<String>('loadMacros');
      if (payload == null || payload.isEmpty) {
        return {};
      }

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return decoded.map((id, value) {
        return MapEntry(id, Macro.fromJson(value as Map<String, dynamic>));
      });
    } on MissingPluginException {
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<int, String>> loadBookTitles() async {
    try {
      final payload = await _channel.invokeMethod<String>(
        'loadMacroBookTitles',
      );
      if (payload == null || payload.isEmpty) {
        return {};
      }

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return decoded.map((book, title) {
        return MapEntry(int.tryParse(book) ?? 1, title as String? ?? '');
      });
    } on MissingPluginException {
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, Macro> macros) async {
    final payload = jsonEncode(
      macros.map((id, macro) => MapEntry(id, macro.toJson())),
    );

    try {
      await _channel.invokeMethod<void>('saveMacros', payload);
    } on MissingPluginException {
      return;
    }
  }

  Future<void> saveBookTitles(Map<int, String> titles) async {
    final payload = jsonEncode(
      titles.map((book, title) => MapEntry(book.toString(), title)),
    );

    try {
      await _channel.invokeMethod<void>('saveMacroBookTitles', payload);
    } on MissingPluginException {
      return;
    }
  }

  Future<bool> exportBackup({
    required Map<String, Macro> macros,
    required Map<int, String> bookTitles,
  }) async {
    final payload = _encodeBackup(macros: macros, bookTitles: bookTitles);

    try {
      return await _channel.invokeMethod<bool>('exportMacroBackup', payload) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<MacroBackup?> importBackup() async {
    try {
      final payload = await _channel.invokeMethod<String>('importMacroBackup');
      if (payload == null || payload.isEmpty) {
        return null;
      }

      return _decodeBackup(payload);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _encodeBackup({
    required Map<String, Macro> macros,
    required Map<int, String> bookTitles,
  }) {
    return jsonEncode({
      'version': 1,
      'macros': macros.map((id, macro) => MapEntry(id, macro.toJson())),
      'bookTitles': bookTitles.map(
        (book, title) => MapEntry(book.toString(), title),
      ),
    });
  }

  MacroBackup _decodeBackup(String payload) {
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    final macrosJson = decoded['macros'] as Map<String, dynamic>? ?? {};
    final titlesJson = decoded['bookTitles'] as Map<String, dynamic>? ?? {};

    return MacroBackup(
      macros: macrosJson.map((id, value) {
        return MapEntry(id, Macro.fromJson(value as Map<String, dynamic>));
      }),
      bookTitles: titlesJson.map((book, title) {
        return MapEntry(int.tryParse(book) ?? 1, title as String? ?? '');
      }),
    );
  }
}
