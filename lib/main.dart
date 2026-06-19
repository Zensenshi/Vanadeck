import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_settings_controller.dart';

void main() {
  runApp(const VanaDeckApp());
}

class VanaDeckApp extends StatefulWidget {
  const VanaDeckApp({super.key});

  @override
  State<VanaDeckApp> createState() => _VanaDeckAppState();
}

class _VanaDeckAppState extends State<VanaDeckApp> {
  late final AppSettingsController _settings;
  static const _oledGunmetal = Color(0xFF2D363B);
  static const _oledGunmetalAccent = Color(0xFF46535A);
  static const _oledGunmetalText = Color(0xFFE5ECEF);

  @override
  void initState() {
    super.initState();
    _settings = AppSettingsController()..load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'VanaDeck',
          debugShowCheckedModeBanner: false,
          locale: const Locale.fromSubtags(
            languageCode: 'ja',
            scriptCode: 'Jpan',
            countryCode: 'JP',
          ),
          themeMode: _settings.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: _AppBackground(
            settings: _settings,
            child: HomeScreen(settings: _settings),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final hasBackgroundImage = _settings.backgroundImageBytes != null;
    final colorScheme = _buildColorScheme(brightness);
    final oledBlack = brightness == Brightness.dark && _isOledBlack;
    final usesAmbientBackground =
        hasBackgroundImage ||
        (!oledBlack &&
            _settings.backgroundGradientScheme != AppGradientScheme.none);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: usesAmbientBackground
          ? Colors.transparent
          : _backgroundColor(brightness),
      appBarTheme: AppBarTheme(
        backgroundColor: oledBlack
            ? Colors.black
            : usesAmbientBackground
            ? Colors.transparent
            : null,
        foregroundColor: oledBlack ? _oledGunmetalText : null,
        surfaceTintColor: oledBlack || usesAmbientBackground
            ? Colors.transparent
            : null,
        elevation: usesAmbientBackground ? 0 : null,
        shape: oledBlack
            ? const Border(bottom: BorderSide(color: _oledGunmetal))
            : null,
      ),
      useMaterial3: true,
    );
  }

  ColorScheme _buildColorScheme(Brightness brightness) {
    if (brightness == Brightness.dark && _isOledBlack) {
      return ColorScheme.fromSeed(
        seedColor: _oledGunmetal,
        brightness: brightness,
      ).copyWith(
        primary: const Color(0xFFA7B2B7),
        onPrimary: Colors.black,
        primaryContainer: _oledGunmetalAccent,
        onPrimaryContainer: _oledGunmetalText,
        secondary: const Color(0xFF9DAAB0),
        onSecondary: Colors.black,
        secondaryContainer: const Color(0xFF354047),
        onSecondaryContainer: _oledGunmetalText,
        tertiary: const Color(0xFFB6BFC4),
        onTertiary: Colors.black,
        tertiaryContainer: const Color(0xFF3D484F),
        onTertiaryContainer: _oledGunmetalText,
        surface: Colors.black,
        onSurface: _oledGunmetalText,
        surfaceContainerHighest: const Color(0xFF151A1D),
        onSurfaceVariant: const Color(0xFFC2CCD1),
        outline: const Color(0xFF5C686F),
        outlineVariant: _oledGunmetal,
      );
    }

    final selectedColor = _settings.seedColor;
    final selectedOnColor = _onColor(selectedColor);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _settings.seedColor,
      brightness: brightness,
    );
    return baseScheme.copyWith(
      primary: selectedColor,
      onPrimary: selectedOnColor,
      primaryContainer: selectedColor,
      onPrimaryContainer: selectedOnColor,
      secondary: selectedColor,
      onSecondary: selectedOnColor,
      secondaryContainer: Color.alphaBlend(
        selectedColor.withValues(
          alpha: brightness == Brightness.dark ? 0.42 : 0.24,
        ),
        baseScheme.surface,
      ),
      onSecondaryContainer: baseScheme.onSurface,
    );
  }

  Color _backgroundColor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (dark && _isOledBlack) {
      return Colors.black;
    }
    return Color.alphaBlend(
      _settings.seedColor.withValues(alpha: dark ? 0.08 : 0.05),
      dark ? const Color(0xFF111816) : const Color(0xFFF7FAF8),
    );
  }

  bool get _isOledBlack => _settings.isOledBlack;

  Color _onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

class _AppBackground extends StatelessWidget {
  const _AppBackground({required this.settings, required this.child});

  final AppSettingsController settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final oledBlack = dark && settings.isOledBlack;
    final fallbackColor = Color.alphaBlend(
      settings.seedColor.withValues(
        alpha: oledBlack ? 0 : (dark ? 0.08 : 0.05),
      ),
      oledBlack
          ? Colors.black
          : dark
          ? const Color(0xFF111816)
          : const Color(0xFFF7FAF8),
    );
    final backgroundBytes = settings.backgroundImageBytes;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fallbackColor,
        gradient: backgroundBytes == null
            ? settings.backgroundGradientScheme.gradient(
                brightness: brightness,
                seedColor: settings.seedColor,
                fallbackColor: fallbackColor,
                isOledBlack: oledBlack,
              )
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundBytes != null)
            Image.memory(
              backgroundBytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          if (backgroundBytes != null)
            ColoredBox(
              color: dark
                  ? Colors.black.withValues(alpha: 0.58)
                  : Colors.white.withValues(alpha: 0.68),
            ),
          child,
        ],
      ),
    );
  }
}
