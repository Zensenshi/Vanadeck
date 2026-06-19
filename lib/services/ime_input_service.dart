import 'package:flutter/services.dart';

class ImeInputService {
  const ImeInputService();

  static const MethodChannel _channel = MethodChannel('vanadeck/ime');

  Future<void> openInputMethodSettings() async {
    try {
      await _channel.invokeMethod<void>('openInputMethodSettings');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> showInputMethodPicker() async {
    try {
      await _channel.invokeMethod<void>('showInputMethodPicker');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<ImeInputStatus> status() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'getStatus',
      );
      return ImeInputStatus(
        hasEnabledKeyboards: value?['hasEnabledKeyboards'] == true,
        selectedKeyboardId: value?['selectedKeyboardId'] as String?,
        selectedKeyboardName: value?['selectedKeyboardName'] as String?,
      );
    } on MissingPluginException {
      return const ImeInputStatus();
    } on PlatformException {
      return const ImeInputStatus();
    }
  }
}

class ImeInputStatus {
  const ImeInputStatus({
    this.hasEnabledKeyboards = false,
    this.selectedKeyboardId,
    this.selectedKeyboardName,
  });

  final bool hasEnabledKeyboards;
  final String? selectedKeyboardId;
  final String? selectedKeyboardName;

  bool get hasSelectedKeyboard =>
      selectedKeyboardId != null && selectedKeyboardId!.trim().isNotEmpty;
}
