import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MacroCastFeedbackStyle { fillBar, edgeGlow }

enum AppGradientScheme {
  none('None'),
  seaGlass('Sea glass'),
  duskBloom('Dusk bloom'),
  emberSteel('Ember steel'),
  deepCurrent('Deep current');

  const AppGradientScheme(this.label);

  final String label;

  LinearGradient? gradient({
    required Brightness brightness,
    required Color seedColor,
    required Color fallbackColor,
    required bool isOledBlack,
  }) {
    if (this == AppGradientScheme.none || isOledBlack) {
      return null;
    }

    final dark = brightness == Brightness.dark;
    final colors = switch (this) {
      AppGradientScheme.seaGlass =>
        dark
            ? const [Color(0xFF0D1918), Color(0xFF14312F), Color(0xFF1B2632)]
            : const [Color(0xFFF2FAF8), Color(0xFFD8EEE9), Color(0xFFEAF1FA)],
      AppGradientScheme.duskBloom =>
        dark
            ? const [Color(0xFF15121A), Color(0xFF2C1F32), Color(0xFF173340)]
            : const [Color(0xFFFBF3F7), Color(0xFFE7E1FA), Color(0xFFE1F0F4)],
      AppGradientScheme.emberSteel =>
        dark
            ? const [Color(0xFF171412), Color(0xFF34241C), Color(0xFF1D3037)]
            : const [Color(0xFFFBF6EF), Color(0xFFF0D7C2), Color(0xFFDDE9EF)],
      AppGradientScheme.deepCurrent =>
        dark
            ? const [Color(0xFF0D1218), Color(0xFF102B3A), Color(0xFF1D362B)]
            : const [Color(0xFFF1F7FB), Color(0xFFD8EAF5), Color(0xFFDDEDE4)],
      AppGradientScheme.none => [fallbackColor, fallbackColor],
    };

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          seedColor.withValues(alpha: dark ? 0.10 : 0.06),
          colors[0],
        ),
        colors[1],
        colors[2],
      ],
    );
  }
}

enum ChatColorRole {
  say('Say', Color(0xFFEDE8D8)),
  shout('Shout', Color(0xFFFF9C57)),
  yell('Yell', Color(0xFFFFE45C)),
  tell('Tell', Color(0xFFFF8DFF)),
  party('Party', Color(0xFF80D8FF)),
  linkshell('Linkshell', Color(0xFF86F67C)),
  linkshellTwo('Linkshell 2', Color(0xFFA6EF5E)),
  assistJ('Assist J', Color(0xFFFFDF7E)),
  assistE('Assist E', Color(0xFFFFC66D)),
  unity('Unity', Color(0xFFFFD85F)),
  emote('Emotes', Color(0xFFFFA3D7)),
  message('Messages', Color(0xFFF1EAD5)),
  npc('NPC conversation', Color(0xFFE7D097));

  const ChatColorRole(this.label, this.defaultColor);

  final String label;
  final Color defaultColor;
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({AppSettingsService? service})
    : _service = service ?? const AppSettingsService();

  static const defaultChatFontFamily = 'jp-sans';
  static const validChatFontFamilies = {
    defaultChatFontFamily,
    'sans-serif',
    'sans-serif-medium',
    'sans-serif-condensed',
    'monospace',
    'serif',
    'casual',
    'jp-gothic',
    'jp-serif',
    'jp-mincho',
  };

  final AppSettingsService _service;
  Color _seedColor = defaultSeedColor;
  Color _navigationSeedColor = defaultSeedColor;
  Color _macroCastFeedbackColor = defaultCastFeedbackColor;
  ThemeMode _themeMode = ThemeMode.dark;
  String _chatFontFamily = defaultChatFontFamily;
  double _chatFontSize = 14;
  AppGradientScheme _backgroundGradientScheme = AppGradientScheme.none;
  Map<ChatColorRole, Color> _chatColors = _defaultChatColors();
  MacroCastFeedbackStyle _macroCastFeedbackStyle =
      MacroCastFeedbackStyle.fillBar;
  String? _lastKeyboardId;
  String? _lastKeyboardName;
  String? _resourceFolderName;
  String? _backgroundImageName;
  Uint8List? _backgroundImageBytes;
  bool _loaded = false;
  bool _selectingResourceFolder = false;
  bool _selectingBackgroundImage = false;

  static const defaultSeedColor = Color(0xFF3E6B5B);
  static const defaultCastFeedbackColor = Color(0xFF4FC3F7);

  Color get seedColor => _seedColor;

  Color get navigationSeedColor => _navigationSeedColor;

  Color get macroCastFeedbackColor => _macroCastFeedbackColor;

  ThemeMode get themeMode => _themeMode;

  String get chatFontFamily => _chatFontFamily;

  double get chatFontSize => _chatFontSize;

  AppGradientScheme get backgroundGradientScheme => _backgroundGradientScheme;

  Map<ChatColorRole, Color> get chatColors => _chatColors;

  Color chatColor(ChatColorRole role) => _chatColors[role] ?? role.defaultColor;

  MacroCastFeedbackStyle get macroCastFeedbackStyle => _macroCastFeedbackStyle;

  String? get lastKeyboardId => _lastKeyboardId;

  String? get lastKeyboardName => _lastKeyboardName;

  String? get resourceFolderName => _resourceFolderName;

  String? get backgroundImageName => _backgroundImageName;

  Uint8List? get backgroundImageBytes => _backgroundImageBytes;

  bool get loaded => _loaded;

  bool get selectingResourceFolder => _selectingResourceFolder;

  bool get selectingBackgroundImage => _selectingBackgroundImage;

  bool get isOledBlack => _seedColor.toARGB32() == Colors.black.toARGB32();

  Future<void> load() async {
    final settings = await _service.load();
    _seedColor = settings.seedColor;
    _navigationSeedColor = settings.navigationSeedColor;
    _macroCastFeedbackColor = settings.macroCastFeedbackColor;
    _themeMode = settings.themeMode;
    _chatFontFamily = settings.chatFontFamily;
    _chatFontSize = settings.chatFontSize;
    _backgroundGradientScheme = settings.backgroundGradientScheme;
    _chatColors = settings.chatColors;
    _macroCastFeedbackStyle = settings.macroCastFeedbackStyle;
    _lastKeyboardId = settings.lastKeyboardId;
    _lastKeyboardName = settings.lastKeyboardName;
    _resourceFolderName = settings.resourceFolderName;
    _backgroundImageName = settings.backgroundImageName;
    _backgroundImageBytes = settings.backgroundImageBytes;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    await _service.saveSeedColor(color);
  }

  Future<void> setNavigationSeedColor(Color color) async {
    _navigationSeedColor = color;
    notifyListeners();
    await _service.saveNavigationSeedColor(color);
  }

  Future<void> setMacroCastFeedbackColor(Color color) async {
    _macroCastFeedbackColor = color;
    notifyListeners();
    await _service.saveMacroCastFeedbackColor(color);
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    await _service.saveThemeMode(themeMode);
  }

  Future<void> setChatFontFamily(String fontFamily) async {
    _chatFontFamily = normalizeChatFontFamily(fontFamily);
    notifyListeners();
    await _service.saveChatFontFamily(_chatFontFamily);
  }

  Future<void> setChatFontSize(double fontSize) async {
    _chatFontSize = fontSize.clamp(11, 22).toDouble();
    notifyListeners();
    await _service.saveChatFontSize(_chatFontSize);
  }

  Future<void> setBackgroundGradientScheme(AppGradientScheme scheme) async {
    _backgroundGradientScheme = scheme;
    notifyListeners();
    await _service.saveBackgroundGradientScheme(scheme);
  }

  Future<void> setChatColor(ChatColorRole role, Color color) async {
    _chatColors = Map<ChatColorRole, Color>.unmodifiable({
      ..._chatColors,
      role: color,
    });
    notifyListeners();
    await _service.saveChatColors(_chatColors);
  }

  Future<void> resetChatColors() async {
    _chatColors = _defaultChatColors();
    notifyListeners();
    await _service.saveChatColors(_chatColors);
  }

  Future<void> setMacroCastFeedbackStyle(MacroCastFeedbackStyle style) async {
    _macroCastFeedbackStyle = style;
    notifyListeners();
    await _service.saveMacroCastFeedbackStyle(style);
  }

  Future<void> rememberKeyboard({String? id, String? name}) async {
    final normalizedId = id?.trim();
    if (normalizedId == null || normalizedId.isEmpty) {
      return;
    }

    final normalizedName = name?.trim();
    _lastKeyboardId = normalizedId;
    _lastKeyboardName = normalizedName?.isEmpty == false
        ? normalizedName
        : normalizedId;
    notifyListeners();
    await _service.saveLastKeyboard(
      id: _lastKeyboardId,
      name: _lastKeyboardName,
    );
  }

  Future<bool> pickResourceFolder() async {
    _selectingResourceFolder = true;
    notifyListeners();

    final selected = await _service.pickResourceFolder();
    _resourceFolderName = await _service.resourceFolderName();
    _selectingResourceFolder = false;
    _service.clearIconCache();
    notifyListeners();
    return selected;
  }

  Future<bool> pickBackgroundImage() async {
    _selectingBackgroundImage = true;
    notifyListeners();

    final selected = await _service.pickBackgroundImage();
    _backgroundImageName = await _service.backgroundImageName();
    _backgroundImageBytes = await _service.loadBackgroundImageBytes();
    _selectingBackgroundImage = false;
    notifyListeners();
    return selected;
  }

  Future<void> clearBackgroundImage() async {
    await _service.clearBackgroundImage();
    _backgroundImageName = null;
    _backgroundImageBytes = null;
    notifyListeners();
  }

  Future<Uint8List?> loadStatusIconBytes(int id) {
    return _service.loadStatusIconBytes(id);
  }

  static Map<ChatColorRole, Color> _defaultChatColors() {
    return Map<ChatColorRole, Color>.unmodifiable({
      for (final role in ChatColorRole.values) role: role.defaultColor,
    });
  }

  static String normalizeChatFontFamily(String? fontFamily) {
    if (fontFamily == null || !validChatFontFamilies.contains(fontFamily)) {
      return defaultChatFontFamily;
    }
    return fontFamily;
  }
}

class AppSettings {
  const AppSettings({
    required this.seedColor,
    required this.navigationSeedColor,
    required this.macroCastFeedbackColor,
    required this.themeMode,
    required this.chatFontFamily,
    required this.chatFontSize,
    required this.backgroundGradientScheme,
    required this.chatColors,
    required this.macroCastFeedbackStyle,
    this.lastKeyboardId,
    this.lastKeyboardName,
    this.resourceFolderName,
    this.backgroundImageName,
    this.backgroundImageBytes,
  });

  final Color seedColor;
  final Color navigationSeedColor;
  final Color macroCastFeedbackColor;
  final ThemeMode themeMode;
  final String chatFontFamily;
  final double chatFontSize;
  final AppGradientScheme backgroundGradientScheme;
  final Map<ChatColorRole, Color> chatColors;
  final MacroCastFeedbackStyle macroCastFeedbackStyle;
  final String? lastKeyboardId;
  final String? lastKeyboardName;
  final String? resourceFolderName;
  final String? backgroundImageName;
  final Uint8List? backgroundImageBytes;
}

class AppSettingsService {
  const AppSettingsService();

  static const _channel = MethodChannel('vanadeck/settings');
  static const _navigationSeedColorKey = 'navigation_seed_color';
  static const _macroCastFeedbackColorKey = 'macro_cast_feedback_color';
  static const _macroCastFeedbackStyleKey = 'macro_cast_feedback_style';
  static const _backgroundGradientSchemeKey = 'background_gradient_scheme';
  static const _chatColorsKey = 'chat_colors';
  static const _lastKeyboardIdKey = 'last_keyboard_id';
  static const _lastKeyboardNameKey = 'last_keyboard_name';
  static const _statusIconRecordSize = 0x1800;
  static const _statusIconPixelOffset = 0x2F4;
  static const _statusIconSize = 32;
  static final Map<int, Future<Uint8List?>> _iconCache = {};

  Future<AppSettings> load() async {
    final seedColor = await _loadSeedColor();
    final navigationSeedColor = await _loadNavigationSeedColor(seedColor);
    final macroCastFeedbackColor = await _loadMacroCastFeedbackColor();
    final themeMode = await _loadThemeMode();
    final chatFontFamily = await _loadChatFontFamily();
    final chatFontSize = await _loadChatFontSize();
    final backgroundGradientScheme = await _loadBackgroundGradientScheme();
    final chatColors = await _loadChatColors();
    final macroCastFeedbackStyle = await _loadMacroCastFeedbackStyle();
    final lastKeyboardId = await _loadSetting(_lastKeyboardIdKey);
    final lastKeyboardName = await _loadSetting(_lastKeyboardNameKey);
    final folderName = await resourceFolderName();
    final backgroundName = await backgroundImageName();
    final backgroundBytes = await loadBackgroundImageBytes();
    return AppSettings(
      seedColor: seedColor,
      navigationSeedColor: navigationSeedColor,
      macroCastFeedbackColor: macroCastFeedbackColor,
      themeMode: themeMode,
      chatFontFamily: chatFontFamily,
      chatFontSize: chatFontSize,
      backgroundGradientScheme: backgroundGradientScheme,
      chatColors: chatColors,
      macroCastFeedbackStyle: macroCastFeedbackStyle,
      lastKeyboardId: lastKeyboardId,
      lastKeyboardName: lastKeyboardName,
      resourceFolderName: folderName,
      backgroundImageName: backgroundName,
      backgroundImageBytes: backgroundBytes,
    );
  }

  Future<void> saveSeedColor(Color color) async {
    try {
      await _channel.invokeMethod<void>(
        'saveSeedColor',
        color.toARGB32().toSigned(32),
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveNavigationSeedColor(Color color) async {
    try {
      await _channel.invokeMethod<void>('saveSetting', {
        'key': _navigationSeedColorKey,
        'value': color.toARGB32().toString(),
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveMacroCastFeedbackColor(Color color) async {
    try {
      await _channel.invokeMethod<void>('saveSetting', {
        'key': _macroCastFeedbackColorKey,
        'value': color.toARGB32().toString(),
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    try {
      await _channel.invokeMethod<void>('saveThemeMode', themeMode.name);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveChatFontFamily(String fontFamily) async {
    try {
      await _channel.invokeMethod<void>('saveChatFontFamily', fontFamily);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveChatFontSize(double fontSize) async {
    try {
      await _channel.invokeMethod<void>('saveChatFontSize', fontSize);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveMacroCastFeedbackStyle(MacroCastFeedbackStyle style) async {
    try {
      await _channel.invokeMethod<void>('saveSetting', {
        'key': _macroCastFeedbackStyleKey,
        'value': style.name,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveBackgroundGradientScheme(AppGradientScheme scheme) async {
    await _saveSetting(_backgroundGradientSchemeKey, scheme.name);
  }

  Future<void> saveChatColors(Map<ChatColorRole, Color> colors) async {
    final encoded = json.encode({
      for (final entry in colors.entries)
        entry.key.name: entry.value.toARGB32().toString(),
    });
    await _saveSetting(_chatColorsKey, encoded);
  }

  Future<void> saveLastKeyboard({String? id, String? name}) async {
    await _saveSetting(_lastKeyboardIdKey, id);
    await _saveSetting(_lastKeyboardNameKey, name);
  }

  Future<bool> pickResourceFolder() async {
    try {
      final selected = await _channel.invokeMethod<bool>('pickResourceFolder');
      return selected ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> pickBackgroundImage() async {
    try {
      final selected = await _channel.invokeMethod<bool>('pickBackgroundImage');
      return selected ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> clearBackgroundImage() async {
    try {
      await _channel.invokeMethod<void>('clearBackgroundImage');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<String?> backgroundImageName() async {
    try {
      return await _channel.invokeMethod<String>('getBackgroundImageName');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Uint8List?> loadBackgroundImageBytes() async {
    try {
      return await _channel.invokeMethod<Uint8List>('loadBackgroundImageBytes');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<String?> resourceFolderName() async {
    try {
      return await _channel.invokeMethod<String>('getResourceFolderName');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Uint8List?> loadStatusIconBytes(int id) {
    return _iconCache.putIfAbsent(id, () => _loadStatusIconBytes(id));
  }

  void clearIconCache() {
    _iconCache.clear();
  }

  Future<Color> _loadSeedColor() async {
    try {
      final value = await _channel.invokeMethod<int>('loadSeedColor');
      if (value != null) {
        return Color(value.toUnsigned(32));
      }
    } on MissingPluginException {
      return AppSettingsController.defaultSeedColor;
    } on PlatformException {
      return AppSettingsController.defaultSeedColor;
    }

    return AppSettingsController.defaultSeedColor;
  }

  Future<Color> _loadNavigationSeedColor(Color seedColor) async {
    final fallback = seedColor.toARGB32() == Colors.black.toARGB32()
        ? AppSettingsController.defaultSeedColor
        : seedColor;
    try {
      final value = await _channel.invokeMethod<String>(
        'loadSetting',
        _navigationSeedColorKey,
      );
      final parsed = int.tryParse(value ?? '');
      if (parsed != null) {
        return Color(parsed.toUnsigned(32));
      }
    } on MissingPluginException {
      return fallback;
    } on PlatformException {
      return fallback;
    }

    return fallback;
  }

  Future<Color> _loadMacroCastFeedbackColor() async {
    try {
      final value = await _channel.invokeMethod<String>(
        'loadSetting',
        _macroCastFeedbackColorKey,
      );
      final parsed = int.tryParse(value ?? '');
      if (parsed != null) {
        return Color(parsed.toUnsigned(32));
      }
    } on MissingPluginException {
      return AppSettingsController.defaultCastFeedbackColor;
    } on PlatformException {
      return AppSettingsController.defaultCastFeedbackColor;
    }

    return AppSettingsController.defaultCastFeedbackColor;
  }

  Future<ThemeMode> _loadThemeMode() async {
    try {
      final value = await _channel.invokeMethod<String>('loadThemeMode');
      return ThemeMode.values.firstWhere(
        (themeMode) => themeMode.name == value,
        orElse: () => ThemeMode.dark,
      );
    } on MissingPluginException {
      return ThemeMode.dark;
    } on PlatformException {
      return ThemeMode.dark;
    }
  }

  Future<String> _loadChatFontFamily() async {
    try {
      return AppSettingsController.normalizeChatFontFamily(
        await _channel.invokeMethod<String>('loadChatFontFamily'),
      );
    } on MissingPluginException {
      return AppSettingsController.defaultChatFontFamily;
    } on PlatformException {
      return AppSettingsController.defaultChatFontFamily;
    }
  }

  Future<double> _loadChatFontSize() async {
    try {
      final value = await _channel.invokeMethod<num>('loadChatFontSize');
      return (value?.toDouble() ?? 14).clamp(11, 22).toDouble();
    } on MissingPluginException {
      return 14;
    } on PlatformException {
      return 14;
    }
  }

  Future<MacroCastFeedbackStyle> _loadMacroCastFeedbackStyle() async {
    try {
      final value = await _loadSetting(_macroCastFeedbackStyleKey);
      return MacroCastFeedbackStyle.values.firstWhere(
        (style) => style.name == value,
        orElse: () => MacroCastFeedbackStyle.fillBar,
      );
    } on MissingPluginException {
      return MacroCastFeedbackStyle.fillBar;
    } on PlatformException {
      return MacroCastFeedbackStyle.fillBar;
    }
  }

  Future<AppGradientScheme> _loadBackgroundGradientScheme() async {
    final value = await _loadSetting(_backgroundGradientSchemeKey);
    return AppGradientScheme.values.firstWhere(
      (scheme) => scheme.name == value,
      orElse: () => AppGradientScheme.none,
    );
  }

  Future<Map<ChatColorRole, Color>> _loadChatColors() async {
    final colors = AppSettingsController._defaultChatColors();
    final value = await _loadSetting(_chatColorsKey);
    if (value == null) {
      return colors;
    }

    try {
      final decoded = json.decode(value);
      if (decoded is! Map) {
        return colors;
      }

      return Map<ChatColorRole, Color>.unmodifiable({
        for (final role in ChatColorRole.values)
          role:
              _parseStoredColor(decoded[role.name]?.toString()) ??
              role.defaultColor,
      });
    } on FormatException {
      return colors;
    }
  }

  Color? _parseStoredColor(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) {
      return null;
    }
    return Color(parsed.toUnsigned(32));
  }

  Future<String?> _loadSetting(String key) async {
    try {
      final value = await _channel.invokeMethod<String>('loadSetting', key);
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) {
        return null;
      }
      return normalized;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _saveSetting(String key, String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('saveSetting', {
        'key': key,
        'value': normalized,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<Uint8List?> _loadStatusIconBytes(int id) async {
    for (final path in ['status_icons/$id.png', '$id.png']) {
      final bytes = await _loadResourceBytes(path);
      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
    }

    return _loadDatStatusIconBytes(id);
  }

  Future<Uint8List?> _loadResourceBytes(String relativePath) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'loadResourceBytes',
        relativePath,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Uint8List?> _loadDatStatusIconBytes(int id) async {
    for (final path in const [
      'ROM/119/57.DAT',
      '119/57.DAT',
      'ROM/0/12.DAT',
      '0/12.DAT',
    ]) {
      final datBytes = await _loadResourceBytes(path);
      if (datBytes == null || datBytes.isEmpty) {
        continue;
      }

      final iconBytes = _extractStatusIconPng(datBytes, id);
      if (iconBytes != null) {
        return iconBytes;
      }
    }

    return null;
  }

  Uint8List? _extractStatusIconPng(Uint8List datBytes, int id) {
    if (id < 0) {
      return null;
    }

    final recordOffset = id * _statusIconRecordSize;
    final pixelOffset = recordOffset + _statusIconPixelOffset;
    final pixelByteLength = _statusIconSize * _statusIconSize * 4;
    if (pixelOffset + pixelByteLength > datBytes.length) {
      return null;
    }

    final nameStart = recordOffset + 0x280;
    final nameEnd = (nameStart + 0x40).clamp(0, datBytes.length);
    final recordName = ascii.decode(
      datBytes.sublist(nameStart, nameEnd),
      allowInvalid: true,
    );
    if (!recordName.contains('sts_icon')) {
      return null;
    }

    final rgba = Uint8List(pixelByteLength);
    for (var y = 0; y < _statusIconSize; y++) {
      for (var x = 0; x < _statusIconSize; x++) {
        final sourceX = (x + (_statusIconSize ~/ 2)) % _statusIconSize;
        final source = pixelOffset + ((y * _statusIconSize + sourceX) * 4);
        final target = (y * _statusIconSize + x) * 4;
        final alpha = datBytes[source];
        rgba[target] = datBytes[source + 1];
        rgba[target + 1] = datBytes[source + 2];
        rgba[target + 2] = datBytes[source + 3];
        rgba[target + 3] = alpha;
      }
    }

    return _encodePngRgba(_statusIconSize, _statusIconSize, rgba);
  }

  Uint8List _encodePngRgba(int width, int height, Uint8List rgba) {
    final scanlineLength = width * 4 + 1;
    final raw = Uint8List(scanlineLength * height);
    for (var row = 0; row < height; row++) {
      raw[row * scanlineLength] = 0;
      raw.setRange(
        row * scanlineLength + 1,
        (row + 1) * scanlineLength,
        rgba,
        row * width * 4,
      );
    }

    final header = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8)
      ..setUint8(9, 6)
      ..setUint8(10, 0)
      ..setUint8(11, 0)
      ..setUint8(12, 0);

    final builder = BytesBuilder()
      ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
      ..add(_pngChunk('IHDR', header.buffer.asUint8List()))
      ..add(_pngChunk('IDAT', ZLibEncoder().convert(raw)))
      ..add(_pngChunk('IEND', Uint8List(0)));

    return builder.toBytes();
  }

  Uint8List _pngChunk(String type, List<int> data) {
    final typeBytes = ascii.encode(type);
    final crcBytes = BytesBuilder()
      ..add(typeBytes)
      ..add(data);
    final output = BytesBuilder()
      ..add(_uint32Bytes(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_uint32Bytes(_crc32(crcBytes.toBytes())));
    return output.toBytes();
  }

  Uint8List _uint32Bytes(int value) {
    final bytes = ByteData(4)..setUint32(0, value);
    return bytes.buffer.asUint8List();
  }

  int _crc32(Uint8List bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc = _crc32Table[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF).toUnsigned(32);
  }

  static final List<int> _crc32Table = List<int>.generate(256, (index) {
    var crc = index;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? 0xEDB88320 ^ (crc >>> 1) : crc >>> 1;
    }
    return crc.toUnsigned(32);
  });
}
