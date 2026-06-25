import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MacroCastFeedbackStyle { fillBar, edgeGlow }

enum OverlayAppearance {
  gameGlass('Game glass'),
  solidDark('Solid');

  const OverlayAppearance(this.label);

  final String label;
}

enum OverlayTabPosition {
  top('Top'),
  bottom('Bottom'),
  left('Left'),
  right('Right');

  const OverlayTabPosition(this.label);

  final String label;
}

enum ColorFillStyle {
  solid('Solid'),
  gradation('Gradation');

  const ColorFillStyle(this.label);

  final String label;
}

class SurfaceGradientColors {
  const SurfaceGradientColors({required this.start, required this.end});

  final Color start;
  final Color end;

  Color appColor({
    required ColorFillStyle style,
    required Brightness brightness,
    required Color fallbackColor,
    required bool isOledBlack,
  }) {
    if (isOledBlack || style == ColorFillStyle.gradation) {
      return fallbackColor;
    }

    return Color.alphaBlend(
      start.withValues(alpha: brightness == Brightness.dark ? 0.48 : 0.30),
      fallbackColor,
    );
  }

  LinearGradient? appGradient({
    required ColorFillStyle style,
    required Brightness brightness,
    required Color fallbackColor,
    required bool isOledBlack,
  }) {
    if (isOledBlack || style == ColorFillStyle.solid) {
      return null;
    }

    final dark = brightness == Brightness.dark;
    final alpha = dark ? 0.30 : 0.20;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(start.withValues(alpha: alpha), fallbackColor),
        Color.alphaBlend(end.withValues(alpha: alpha * 0.86), fallbackColor),
      ],
    );
  }

  Color iconBarColor({
    required ColorFillStyle style,
    required Color baseColor,
  }) {
    if (style == ColorFillStyle.gradation) {
      return baseColor;
    }

    return Color.alphaBlend(start.withValues(alpha: 0.54), baseColor);
  }

  LinearGradient? iconBarGradient({
    required ColorFillStyle style,
    required Color baseColor,
    required bool vertical,
  }) {
    if (style == ColorFillStyle.solid) {
      return null;
    }

    return LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: [
        Color.alphaBlend(start.withValues(alpha: 0.42), baseColor),
        Color.alphaBlend(end.withValues(alpha: 0.34), baseColor),
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
  Color _buttonTextColor = defaultButtonTextColor;
  SurfaceGradientColors _iconBarColors =
      AppSettingsService.defaultIconBarColors;
  ColorFillStyle _iconBarColorStyle = ColorFillStyle.solid;
  Color _macroCastFeedbackColor = defaultCastFeedbackColor;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _oledBlack = false;
  String _chatFontFamily = defaultChatFontFamily;
  double _chatFontSize = 14;
  ColorFillStyle _backgroundColorStyle = ColorFillStyle.gradation;
  SurfaceGradientColors _surfaceGradientColors =
      AppSettingsService.defaultSurfaceGradientColors;
  Map<ChatColorRole, Color> _chatColors = _defaultChatColors();
  MacroCastFeedbackStyle _macroCastFeedbackStyle =
      MacroCastFeedbackStyle.fillBar;
  double _overlayScale = AppSettingsService.defaultOverlayScale;
  OverlayAppearance _overlayAppearance =
      AppSettingsService.defaultOverlayAppearance;
  OverlayTabPosition _overlayTabPosition =
      AppSettingsService.defaultOverlayTabPosition;
  String? _lastKeyboardId;
  String? _lastKeyboardName;
  String? _resourceFolderName;
  String? _backgroundImageName;
  Uint8List? _backgroundImageBytes;
  bool _loaded = false;
  bool _selectingResourceFolder = false;
  bool _selectingBackgroundImage = false;

  static const defaultSeedColor = Color(0xFF3E6B5B);
  static const defaultButtonTextColor = Colors.white;
  static const defaultCastFeedbackColor = Color(0xFF4FC3F7);

  Color get seedColor => _seedColor;

  Color get buttonColor => _seedColor;

  Color get buttonTextColor => _buttonTextColor;

  SurfaceGradientColors get iconBarColors => _iconBarColors;

  Color get iconBarStartColor => _iconBarColors.start;

  Color get iconBarEndColor => _iconBarColors.end;

  ColorFillStyle get iconBarColorStyle => _iconBarColorStyle;

  Color get navigationSeedColor => _iconBarColors.start;

  Color get macroCastFeedbackColor => _macroCastFeedbackColor;

  ThemeMode get themeMode => _themeMode;

  String get chatFontFamily => _chatFontFamily;

  double get chatFontSize => _chatFontSize;

  ColorFillStyle get backgroundColorStyle => _backgroundColorStyle;

  SurfaceGradientColors get surfaceGradientColors => _surfaceGradientColors;

  Color get surfaceGradientStartColor => _surfaceGradientColors.start;

  Color get surfaceGradientEndColor => _surfaceGradientColors.end;

  Map<ChatColorRole, Color> get chatColors => _chatColors;

  Color chatColor(ChatColorRole role) => _chatColors[role] ?? role.defaultColor;

  MacroCastFeedbackStyle get macroCastFeedbackStyle => _macroCastFeedbackStyle;

  double get overlayScale => _overlayScale;

  OverlayAppearance get overlayAppearance => _overlayAppearance;

  OverlayTabPosition get overlayTabPosition => _overlayTabPosition;

  String? get lastKeyboardId => _lastKeyboardId;

  String? get lastKeyboardName => _lastKeyboardName;

  String? get resourceFolderName => _resourceFolderName;

  String? get backgroundImageName => _backgroundImageName;

  Uint8List? get backgroundImageBytes => _backgroundImageBytes;

  bool get loaded => _loaded;

  bool get selectingResourceFolder => _selectingResourceFolder;

  bool get selectingBackgroundImage => _selectingBackgroundImage;

  bool get isOledBlack => _oledBlack;

  Future<void> load() async {
    final settings = await _service.load();
    _seedColor = settings.seedColor;
    _buttonTextColor = settings.buttonTextColor;
    _iconBarColors = settings.iconBarColors;
    _iconBarColorStyle = settings.iconBarColorStyle;
    _macroCastFeedbackColor = settings.macroCastFeedbackColor;
    _themeMode = settings.themeMode;
    _oledBlack = settings.oledBlack;
    _chatFontFamily = settings.chatFontFamily;
    _chatFontSize = settings.chatFontSize;
    _backgroundColorStyle = settings.backgroundColorStyle;
    _surfaceGradientColors = settings.surfaceGradientColors;
    _chatColors = settings.chatColors;
    _macroCastFeedbackStyle = settings.macroCastFeedbackStyle;
    _overlayScale = settings.overlayScale;
    _overlayAppearance = settings.overlayAppearance;
    _overlayTabPosition = settings.overlayTabPosition;
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

  Future<void> setButtonTextColor(Color color) async {
    _buttonTextColor = color;
    notifyListeners();
    await _service.saveButtonTextColor(color);
  }

  Future<void> setNavigationSeedColor(Color color) async {
    await setIconBarStartColor(color);
  }

  Future<void> setIconBarColorStyle(ColorFillStyle style) async {
    _iconBarColorStyle = style;
    notifyListeners();
    await _service.saveIconBarColorStyle(style);
  }

  Future<void> setIconBarStartColor(Color color) async {
    _iconBarColors = SurfaceGradientColors(
      start: color,
      end: _iconBarColors.end,
    );
    notifyListeners();
    await _service.saveIconBarStartColor(color);
  }

  Future<void> setIconBarEndColor(Color color) async {
    _iconBarColors = SurfaceGradientColors(
      start: _iconBarColors.start,
      end: color,
    );
    notifyListeners();
    await _service.saveIconBarEndColor(color);
  }

  Future<void> resetIconBarColors() async {
    _iconBarColorStyle = ColorFillStyle.solid;
    _iconBarColors = AppSettingsService.defaultIconBarColors;
    notifyListeners();
    await _service.saveIconBarColorStyle(_iconBarColorStyle);
    await _service.saveIconBarStartColor(_iconBarColors.start);
    await _service.saveIconBarEndColor(_iconBarColors.end);
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

  Future<void> setOledBlack(bool oledBlack) async {
    _oledBlack = oledBlack;
    notifyListeners();
    await _service.saveOledBlack(oledBlack);
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

  Future<void> setBackgroundColorStyle(ColorFillStyle style) async {
    _backgroundColorStyle = style;
    notifyListeners();
    await _service.saveBackgroundColorStyle(style);
  }

  Future<void> setSurfaceGradientStartColor(Color color) async {
    _surfaceGradientColors = SurfaceGradientColors(
      start: color,
      end: _surfaceGradientColors.end,
    );
    notifyListeners();
    await _service.saveSurfaceGradientStartColor(color);
  }

  Future<void> setSurfaceGradientEndColor(Color color) async {
    _surfaceGradientColors = SurfaceGradientColors(
      start: _surfaceGradientColors.start,
      end: color,
    );
    notifyListeners();
    await _service.saveSurfaceGradientEndColor(color);
  }

  Future<void> resetSurfaceGradientColors() async {
    _surfaceGradientColors = AppSettingsService.defaultSurfaceGradientColors;
    notifyListeners();
    await _service.saveSurfaceGradientStartColor(_surfaceGradientColors.start);
    await _service.saveSurfaceGradientEndColor(_surfaceGradientColors.end);
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

  Future<void> setOverlayScale(double scale) async {
    _overlayScale = scale
        .clamp(
          AppSettingsService.minOverlayScale,
          AppSettingsService.maxOverlayScale,
        )
        .toDouble();
    notifyListeners();
    await _service.saveOverlayScale(_overlayScale);
  }

  Future<void> setOverlayAppearance(OverlayAppearance appearance) async {
    _overlayAppearance = appearance;
    notifyListeners();
    await _service.saveOverlayAppearance(appearance);
  }

  Future<void> setOverlayTabPosition(OverlayTabPosition position) async {
    _overlayTabPosition = position;
    notifyListeners();
    await _service.saveOverlayTabPosition(position);
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
    required this.buttonTextColor,
    required this.iconBarColors,
    required this.iconBarColorStyle,
    required this.macroCastFeedbackColor,
    required this.themeMode,
    required this.oledBlack,
    required this.chatFontFamily,
    required this.chatFontSize,
    required this.backgroundColorStyle,
    required this.surfaceGradientColors,
    required this.chatColors,
    required this.macroCastFeedbackStyle,
    required this.overlayScale,
    required this.overlayAppearance,
    required this.overlayTabPosition,
    this.lastKeyboardId,
    this.lastKeyboardName,
    this.resourceFolderName,
    this.backgroundImageName,
    this.backgroundImageBytes,
  });

  final Color seedColor;
  final Color buttonTextColor;
  final SurfaceGradientColors iconBarColors;
  final ColorFillStyle iconBarColorStyle;
  final Color macroCastFeedbackColor;
  final ThemeMode themeMode;
  final bool oledBlack;
  final String chatFontFamily;
  final double chatFontSize;
  final ColorFillStyle backgroundColorStyle;
  final SurfaceGradientColors surfaceGradientColors;
  final Map<ChatColorRole, Color> chatColors;
  final MacroCastFeedbackStyle macroCastFeedbackStyle;
  final double overlayScale;
  final OverlayAppearance overlayAppearance;
  final OverlayTabPosition overlayTabPosition;
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
  static const _buttonTextColorKey = 'button_text_color';
  static const _oledBlackKey = 'oled_black';
  static const _iconBarColorStyleKey = 'icon_bar_color_style';
  static const _iconBarEndColorKey = 'icon_bar_end_color';
  static const _macroCastFeedbackColorKey = 'macro_cast_feedback_color';
  static const _macroCastFeedbackStyleKey = 'macro_cast_feedback_style';
  static const _overlayScaleKey = 'overlay_scale';
  static const _overlayAppearanceKey = 'overlay_appearance';
  static const _overlayTabPositionKey = 'overlay_tab_position';
  static const _backgroundGradientSchemeKey = 'background_gradient_scheme';
  static const _backgroundColorStyleKey = 'background_color_style';
  static const _surfaceGradientStartColorKey = 'surface_gradient_start_color';
  static const _surfaceGradientEndColorKey = 'surface_gradient_end_color';
  static const _chatColorsKey = 'chat_colors';
  static const _lastKeyboardIdKey = 'last_keyboard_id';
  static const _lastKeyboardNameKey = 'last_keyboard_name';
  static const _statusIconRecordSize = 0x1800;
  static const _statusIconPixelOffset = 0x2F4;
  static const _statusIconSize = 32;
  static const minOverlayScale = 0.36;
  static const maxOverlayScale = 0.72;
  static const defaultOverlayScale = 0.41;
  static const defaultOverlayAppearance = OverlayAppearance.gameGlass;
  static const defaultOverlayTabPosition = OverlayTabPosition.top;
  static const defaultIconBarColors = SurfaceGradientColors(
    start: AppSettingsController.defaultSeedColor,
    end: Color(0xFF1C7C82),
  );
  static const defaultSurfaceGradientColors = SurfaceGradientColors(
    start: Color(0xFF1C7C82),
    end: Color(0xFF5D6AA2),
  );
  static final Map<int, Future<Uint8List?>> _iconCache = {};

  Future<AppSettings> load() async {
    final seedColor = await _loadSeedColor();
    final buttonTextColor = await _loadButtonTextColor(seedColor);
    final iconBarColors = await _loadIconBarColors(seedColor);
    final iconBarColorStyle = await _loadIconBarColorStyle();
    final macroCastFeedbackColor = await _loadMacroCastFeedbackColor();
    final themeMode = await _loadThemeMode();
    final oledBlack = await _loadOledBlack(seedColor);
    final chatFontFamily = await _loadChatFontFamily();
    final chatFontSize = await _loadChatFontSize();
    final backgroundColorStyle = await _loadBackgroundColorStyle();
    final surfaceGradientColors = await _loadSurfaceGradientColors();
    final chatColors = await _loadChatColors();
    final macroCastFeedbackStyle = await _loadMacroCastFeedbackStyle();
    final overlayScale = await _loadOverlayScale();
    final overlayAppearance = await loadOverlayAppearance();
    final overlayTabPosition = await loadOverlayTabPosition();
    final lastKeyboardId = await _loadSetting(_lastKeyboardIdKey);
    final lastKeyboardName = await _loadSetting(_lastKeyboardNameKey);
    final folderName = await resourceFolderName();
    final backgroundName = await backgroundImageName();
    final backgroundBytes = await loadBackgroundImageBytes();
    return AppSettings(
      seedColor: seedColor,
      buttonTextColor: buttonTextColor,
      iconBarColors: iconBarColors,
      iconBarColorStyle: iconBarColorStyle,
      macroCastFeedbackColor: macroCastFeedbackColor,
      themeMode: themeMode,
      oledBlack: oledBlack,
      chatFontFamily: chatFontFamily,
      chatFontSize: chatFontSize,
      backgroundColorStyle: backgroundColorStyle,
      surfaceGradientColors: surfaceGradientColors,
      chatColors: chatColors,
      macroCastFeedbackStyle: macroCastFeedbackStyle,
      overlayScale: overlayScale,
      overlayAppearance: overlayAppearance,
      overlayTabPosition: overlayTabPosition,
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
    await saveIconBarStartColor(color);
  }

  Future<void> saveButtonTextColor(Color color) async {
    await _saveSetting(_buttonTextColorKey, color.toARGB32().toString());
  }

  Future<void> saveOledBlack(bool oledBlack) async {
    await _saveSetting(_oledBlackKey, oledBlack.toString());
  }

  Future<void> saveIconBarColorStyle(ColorFillStyle style) async {
    await _saveSetting(_iconBarColorStyleKey, style.name);
  }

  Future<void> saveIconBarStartColor(Color color) async {
    await _saveSetting(_navigationSeedColorKey, color.toARGB32().toString());
  }

  Future<void> saveIconBarEndColor(Color color) async {
    await _saveSetting(_iconBarEndColorKey, color.toARGB32().toString());
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

  Future<Color> loadMacroCastFeedbackColor() {
    return _loadMacroCastFeedbackColor();
  }

  Future<Color> loadButtonColor() {
    return _loadSeedColor();
  }

  Future<Color> loadButtonTextColor() async {
    return _loadButtonTextColor(await _loadSeedColor());
  }

  Future<ColorFillStyle> loadIconBarColorStyle() {
    return _loadIconBarColorStyle();
  }

  Future<SurfaceGradientColors> loadIconBarColors() async {
    return _loadIconBarColors(await _loadSeedColor());
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

  Future<void> saveOverlayScale(double scale) async {
    try {
      await _channel.invokeMethod<void>('saveSetting', {
        'key': _overlayScaleKey,
        'value': scale.toStringAsFixed(3),
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> saveOverlayAppearance(OverlayAppearance appearance) async {
    await _saveSetting(_overlayAppearanceKey, appearance.name);
  }

  Future<void> saveOverlayTabPosition(OverlayTabPosition position) async {
    await _saveSetting(_overlayTabPositionKey, position.name);
  }

  Future<OverlayAppearance> loadOverlayAppearance() async {
    final value = await _loadSetting(_overlayAppearanceKey);
    return OverlayAppearance.values.firstWhere(
      (appearance) => appearance.name == value,
      orElse: () => defaultOverlayAppearance,
    );
  }

  Future<OverlayTabPosition> loadOverlayTabPosition() async {
    final value = await _loadSetting(_overlayTabPositionKey);
    return OverlayTabPosition.values.firstWhere(
      (position) => position.name == value,
      orElse: () => defaultOverlayTabPosition,
    );
  }

  Future<void> saveSurfaceGradientStartColor(Color color) async {
    await _saveSetting(
      _surfaceGradientStartColorKey,
      color.toARGB32().toString(),
    );
  }

  Future<void> saveSurfaceGradientEndColor(Color color) async {
    await _saveSetting(
      _surfaceGradientEndColorKey,
      color.toARGB32().toString(),
    );
  }

  Future<Color> loadSurfaceGradientStartColor() async {
    return (await _loadSurfaceGradientColors()).start;
  }

  Future<Color> loadSurfaceGradientEndColor() async {
    return (await _loadSurfaceGradientColors()).end;
  }

  Future<void> saveBackgroundColorStyle(ColorFillStyle style) async {
    await _saveSetting(_backgroundColorStyleKey, style.name);
  }

  Future<ColorFillStyle> loadBackgroundColorStyle() {
    return _loadBackgroundColorStyle();
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

  Future<Color> _loadButtonTextColor(Color seedColor) async {
    final fallback = _onColor(seedColor);
    final stored = _parseStoredColor(await _loadSetting(_buttonTextColorKey));
    return stored ?? fallback;
  }

  Future<SurfaceGradientColors> _loadIconBarColors(Color seedColor) async {
    final start = await _loadNavigationSeedColor(seedColor);
    final end =
        _parseStoredColor(await _loadSetting(_iconBarEndColorKey)) ??
        defaultIconBarColors.end;
    return SurfaceGradientColors(start: start, end: end);
  }

  Future<Color> _loadNavigationSeedColor(Color seedColor) async {
    final fallback = seedColor.toARGB32() == Colors.black.toARGB32()
        ? AppSettingsController.defaultSeedColor
        : seedColor;
    return _parseStoredColor(await _loadSetting(_navigationSeedColorKey)) ??
        fallback;
  }

  Future<ColorFillStyle> _loadIconBarColorStyle() async {
    return _loadColorFillStyle(
      key: _iconBarColorStyleKey,
      fallback: ColorFillStyle.solid,
    );
  }

  Future<bool> _loadOledBlack(Color seedColor) async {
    final value = await _loadSetting(_oledBlackKey);
    if (value != null) {
      return value == 'true';
    }
    return seedColor.toARGB32() == Colors.black.toARGB32();
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

  Future<double> _loadOverlayScale() async {
    final value = await _loadSetting(_overlayScaleKey);
    final parsed = double.tryParse(value ?? '');
    return (parsed ?? defaultOverlayScale)
        .clamp(minOverlayScale, maxOverlayScale)
        .toDouble();
  }

  Future<ColorFillStyle> _loadBackgroundColorStyle() async {
    return _loadColorFillStyle(
      key: _backgroundColorStyleKey,
      fallback: ColorFillStyle.gradation,
    );
  }

  Future<SurfaceGradientColors> _loadSurfaceGradientColors() async {
    final legacyColors = _legacySurfaceGradientColors(
      await _loadSetting(_backgroundGradientSchemeKey),
    );
    final fallback = legacyColors ?? defaultSurfaceGradientColors;
    final start =
        _parseStoredColor(await _loadSetting(_surfaceGradientStartColorKey)) ??
        fallback.start;
    final end =
        _parseStoredColor(await _loadSetting(_surfaceGradientEndColorKey)) ??
        fallback.end;
    return SurfaceGradientColors(start: start, end: end);
  }

  Future<ColorFillStyle> _loadColorFillStyle({
    required String key,
    required ColorFillStyle fallback,
  }) async {
    final value = await _loadSetting(key);
    return ColorFillStyle.values.firstWhere(
      (style) => style.name == value,
      orElse: () => fallback,
    );
  }

  SurfaceGradientColors? _legacySurfaceGradientColors(String? value) {
    return switch (value) {
      'seaGlass' => const SurfaceGradientColors(
        start: Color(0xFF1C7C82),
        end: Color(0xFF5D6AA2),
      ),
      'duskBloom' => const SurfaceGradientColors(
        start: Color(0xFF80589B),
        end: Color(0xFF1C7C82),
      ),
      'emberSteel' => const SurfaceGradientColors(
        start: Color(0xFF9B5D2E),
        end: Color(0xFF2962A8),
      ),
      'deepCurrent' => const SurfaceGradientColors(
        start: Color(0xFF2962A8),
        end: Color(0xFF2F6F3E),
      ),
      _ => null,
    };
  }

  Color? _parseStoredColor(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) {
      return null;
    }
    return Color(parsed.toUnsigned(32));
  }

  Color _onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
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
