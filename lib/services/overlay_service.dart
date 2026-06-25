import 'package:flutter/services.dart';

import 'app_settings_controller.dart';

class OverlayService {
  const OverlayService();

  static const _channel = MethodChannel('vanadeck/overlay');

  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> lastError() async {
    try {
      return await _channel.invokeMethod<String>('lastError');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> start({
    required double scale,
    required OverlayAppearance appearance,
    required OverlayTabPosition tabPosition,
    required OverlayMacroButtonStyle macroButtonStyle,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('start', {
            'scale': scale,
            'appearance': appearance.name,
            'tabPosition': tabPosition.name,
            'macroButtonStyle': macroButtonStyle.name,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      return await _channel.invokeMethod<bool>('stop') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> updateScale(double scale) async {
    try {
      await _channel.invokeMethod<void>('updateScale', {'scale': scale});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> updateAppearance(OverlayAppearance appearance) async {
    try {
      await _channel.invokeMethod<void>('updateAppearance', {
        'appearance': appearance.name,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> updateTabPosition(OverlayTabPosition position) async {
    try {
      await _channel.invokeMethod<void>('updateTabPosition', {
        'tabPosition': position.name,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> updateOverlayTheme({
    required ColorFillStyle iconBarColorStyle,
    required SurfaceGradientColors iconBarColors,
    required Color buttonColor,
    required Color buttonTextColor,
    required OverlayMacroButtonStyle macroButtonStyle,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateOverlayTheme', {
        'iconBarColorStyle': iconBarColorStyle.name,
        'iconBarStartColor': iconBarColors.start.toARGB32().toSigned(32),
        'iconBarEndColor': iconBarColors.end.toARGB32().toSigned(32),
        'buttonColor': buttonColor.toARGB32().toSigned(32),
        'buttonTextColor': buttonTextColor.toARGB32().toSigned(32),
        'macroButtonStyle': macroButtonStyle.name,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> setMinimized(bool minimized) async {
    try {
      await _channel.invokeMethod<void>('setMinimized', {
        'minimized': minimized,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> setKeyboardActive(bool active) async {
    try {
      await _channel.invokeMethod<void>('setKeyboardActive', {
        'active': active,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
