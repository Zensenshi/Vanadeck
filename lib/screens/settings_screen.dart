import 'package:flutter/material.dart';

import '../services/app_settings_controller.dart';
import '../services/game_status_service.dart';
import '../services/ime_input_service.dart';
import '../services/map_service.dart';
import '../services/overlay_mode_controller.dart';
import '../services/overlay_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _imeInputService = const ImeInputService();
  final _overlayMode = const OverlayModeController();
  final _overlayService = const OverlayService();
  String? _mapsFolderName;
  ImeInputStatus _imeStatus = const ImeInputStatus();
  OverlayModeStatus _overlayStatus = OverlayModeStatus.unknown;
  bool _overlayBusy = false;
  bool _selectingMapsFolder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_handleSettingsChanged);
    _mapsFolderName = MapService.mapsFolderName;
    _loadMapsFolderName();
    _refreshKeyboardStatus();
    _refreshOverlayStatus();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_handleSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshKeyboardStatus();
      _refreshOverlayStatus();
    }
  }

  Future<void> _loadMapsFolderName() async {
    await MapService.loadMappyMaps();
    if (!mounted) {
      return;
    }
    setState(() {
      _mapsFolderName = MapService.mapsFolderName;
    });
  }

  Future<bool> _pickMapsFolder() async {
    setState(() {
      _selectingMapsFolder = true;
    });

    final selected = await MapService.pickMapsFolder();
    if (!mounted) {
      return selected;
    }

    setState(() {
      _mapsFolderName = MapService.mapsFolderName;
      _selectingMapsFolder = false;
    });
    return selected;
  }

  Future<void> _openInputMethodSettings() async {
    await _imeInputService.openInputMethodSettings();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refreshKeyboardStatus();
  }

  Future<void> _showInputMethodPicker() async {
    await _imeInputService.showInputMethodPicker();
    for (final delay in const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1200),
      Duration(milliseconds: 2200),
    ]) {
      await Future<void>.delayed(delay);
      await _refreshKeyboardStatus(remember: true);
    }
  }

  Future<void> _refreshKeyboardStatus({bool remember = false}) async {
    final status = await _imeInputService.status();
    if (!mounted) {
      return;
    }

    setState(() {
      _imeStatus = status;
    });

    if (remember && status.hasSelectedKeyboard) {
      await widget.settings.rememberKeyboard(
        id: status.selectedKeyboardId,
        name: status.selectedKeyboardName,
      );
    }
  }

  Future<void> _refreshOverlayStatus() async {
    final status = await _overlayMode.status();
    if (!mounted) {
      return;
    }

    setState(() {
      _overlayStatus = status;
    });

    if (!status.running) {
      GameStatusService.startDefaultListener();
    }
  }

  Future<void> _requestOverlayPermission() async {
    final status = await _overlayMode.requestPermission();
    if (!mounted) {
      return;
    }

    setState(() {
      _overlayStatus = status;
    });
  }

  Future<void> _startOverlay() async {
    setState(() {
      _overlayBusy = true;
    });

    try {
      final result = await _overlayMode.start(widget.settings);
      if (!mounted) {
        return;
      }

      setState(() {
        _overlayStatus = result.status;
      });

      final message = result.message;
      if (message != null) {
        _showOverlayMessage(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _overlayBusy = false;
        });
      }
    }
  }

  Future<void> _stopOverlay() async {
    setState(() {
      _overlayBusy = true;
    });
    try {
      final result = await _overlayMode.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _overlayStatus = result.status;
      });
    } finally {
      if (mounted) {
        setState(() {
          _overlayBusy = false;
        });
      }
    }
  }

  Future<void> _setOverlayScale(double scale) async {
    await widget.settings.setOverlayScale(scale);
    if (_overlayStatus.running) {
      await _overlayService.updateScale(widget.settings.overlayScale);
    }
  }

  Future<void> _setOverlayAppearance(OverlayAppearance appearance) async {
    await widget.settings.setOverlayAppearance(appearance);
    if (_overlayStatus.running) {
      await _overlayService.updateAppearance(appearance);
    }
  }

  Future<void> _setOverlayTabPosition(OverlayTabPosition position) async {
    await widget.settings.setOverlayTabPosition(position);
    if (_overlayStatus.running) {
      await _overlayService.updateTabPosition(position);
    }
  }

  Future<void> _setDarkMode() async {
    await widget.settings.setOledBlack(false);
    await widget.settings.setThemeMode(ThemeMode.dark);
  }

  Future<void> _setLightMode() async {
    await widget.settings.setOledBlack(false);
    await widget.settings.setThemeMode(ThemeMode.light);
  }

  Future<void> _setOledBlackMode() async {
    await widget.settings.setThemeMode(ThemeMode.dark);
    await widget.settings.setOledBlack(true);
  }

  Future<void> _setButtonColor(Color color) async {
    await widget.settings.setSeedColor(color);
    await _updateRunningOverlayTheme();
  }

  Future<void> _setButtonTextColor(Color color) async {
    await widget.settings.setButtonTextColor(color);
    await _updateRunningOverlayTheme();
  }

  Future<void> _setIconBarColorStyle(ColorFillStyle style) async {
    await widget.settings.setIconBarColorStyle(style);
    await _updateRunningOverlayTheme();
  }

  Future<void> _setIconBarStartColor(Color color) async {
    await widget.settings.setIconBarStartColor(color);
    await _updateRunningOverlayTheme();
  }

  Future<void> _setIconBarEndColor(Color color) async {
    await widget.settings.setIconBarEndColor(color);
    await _updateRunningOverlayTheme();
  }

  Future<void> _resetIconBarColors() async {
    await widget.settings.resetIconBarColors();
    await _updateRunningOverlayTheme();
  }

  Future<void> _setBackgroundColorStyle(ColorFillStyle style) async {
    await widget.settings.setBackgroundColorStyle(style);
  }

  Future<void> _setSurfaceGradientStartColor(Color color) async {
    await widget.settings.setSurfaceGradientStartColor(color);
  }

  Future<void> _setSurfaceGradientEndColor(Color color) async {
    await widget.settings.setSurfaceGradientEndColor(color);
  }

  Future<void> _resetSurfaceGradientColors() async {
    await widget.settings.resetSurfaceGradientColors();
  }

  Future<void> _updateRunningOverlayTheme() async {
    if (_overlayStatus.running) {
      await _overlayService.updateOverlayTheme(
        iconBarColorStyle: widget.settings.iconBarColorStyle,
        iconBarColors: widget.settings.iconBarColors,
        buttonColor: widget.settings.buttonColor,
        buttonTextColor: widget.settings.buttonTextColor,
      );
    }
  }

  void _showOverlayMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.settings,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _SettingsSection(
                  title: 'Resources',
                  children: [
                    _FolderSetting(
                      title: 'Icons folder',
                      subtitle:
                          widget.settings.resourceFolderName ??
                          'Use bundled icons and app resources',
                      selecting: widget.settings.selectingResourceFolder,
                      onPressed: widget.settings.pickResourceFolder,
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _FolderSetting(
                      title: 'Maps folder',
                      subtitle:
                          _mapsFolderName ??
                          'Select the Mappy folder that contains map.ini',
                      selecting: _selectingMapsFolder,
                      onPressed: _pickMapsFolder,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: 'Appearance',
                  children: [
                    _ThemeModeSetting(
                      selectedMode: widget.settings.themeMode,
                      isOledBlack: widget.settings.isOledBlack,
                      onDarkSelected: _setDarkMode,
                      onLightSelected: _setLightMode,
                      onOledBlackSelected: _setOledBlackMode,
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ThemeColorSetting(
                      title: 'Button color',
                      selectedColor: widget.settings.buttonColor,
                      onSelected: _setButtonColor,
                      onReset: () => _setButtonColor(
                        AppSettingsController.defaultSeedColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ThemeColorSetting(
                      title: 'Button text color',
                      selectedColor: widget.settings.buttonTextColor,
                      onSelected: _setButtonTextColor,
                      onReset: () => _setButtonTextColor(
                        AppSettingsController.defaultButtonTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ColorStyleSetting(
                      title: 'Icon Bar color',
                      style: widget.settings.iconBarColorStyle,
                      colors: widget.settings.iconBarColors,
                      onStyleChanged: _setIconBarColorStyle,
                      onStartColorChanged: _setIconBarStartColor,
                      onEndColorChanged: _setIconBarEndColor,
                      onReset: _resetIconBarColors,
                      onMatchButton: () =>
                          _setIconBarStartColor(widget.settings.buttonColor),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ColorStyleSetting(
                      title: 'Background color',
                      style: widget.settings.backgroundColorStyle,
                      colors: widget.settings.surfaceGradientColors,
                      onStyleChanged: _setBackgroundColorStyle,
                      onStartColorChanged: _setSurfaceGradientStartColor,
                      onEndColorChanged: _setSurfaceGradientEndColor,
                      onReset: _resetSurfaceGradientColors,
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _MacroCastFeedbackStyleSetting(
                      selectedStyle: widget.settings.macroCastFeedbackStyle,
                      onSelected: widget.settings.setMacroCastFeedbackStyle,
                    ),
                    const SizedBox(height: 12),
                    _ThemeColorSetting(
                      title: 'Casting color',
                      selectedColor: widget.settings.macroCastFeedbackColor,
                      onSelected: widget.settings.setMacroCastFeedbackColor,
                      onReset: () => widget.settings.setMacroCastFeedbackColor(
                        AppSettingsController.defaultCastFeedbackColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _BackgroundImageSetting(
                      imageName: widget.settings.backgroundImageName,
                      selecting: widget.settings.selectingBackgroundImage,
                      onChoose: widget.settings.pickBackgroundImage,
                      onClear: widget.settings.clearBackgroundImage,
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ChatTypographySetting(
                      fontFamily: widget.settings.chatFontFamily,
                      fontSize: widget.settings.chatFontSize,
                      onFontFamilyChanged: widget.settings.setChatFontFamily,
                      onFontSizeChanged: widget.settings.setChatFontSize,
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ChatColorSetting(
                      colors: widget.settings.chatColors,
                      onSelected: widget.settings.setChatColor,
                      onReset: widget.settings.resetChatColors,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: 'Keyboard',
                  children: [
                    _KeyboardSetupActions(
                      currentKeyboardName: _imeStatus.selectedKeyboardName,
                      onEnableKeyboard: _openInputMethodSettings,
                      onSwitchKeyboard: _showInputMethodPicker,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: 'Overlay Mode',
                  children: [
                    _OverlaySetting(
                      supported: _overlayStatus.supported,
                      permissionGranted: _overlayStatus.permissionGranted,
                      running: _overlayStatus.running,
                      busy: _overlayBusy,
                      scale: widget.settings.overlayScale,
                      appearance: widget.settings.overlayAppearance,
                      tabPosition: widget.settings.overlayTabPosition,
                      onRequestPermission: _requestOverlayPermission,
                      onStart: _startOverlay,
                      onStop: _stopOverlay,
                      onScaleChanged: _setOverlayScale,
                      onAppearanceChanged: _setOverlayAppearance,
                      onTabPositionChanged: _setOverlayTabPosition,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _AboutSetting(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = false;
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[const SizedBox(height: 12), ...widget.children],
          ],
        ),
      ),
    );
  }
}

class _AboutSetting extends StatelessWidget {
  const _AboutSetting();

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'About',
      children: [
        Text(
          'VanaDeck is an unofficial fan project.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _showCredits(context),
              icon: const Icon(Icons.info_outline),
              label: const Text('Credits'),
            ),
            OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'VanaDeck',
                applicationLegalese:
                    'Unofficial fan project. Not affiliated with Square Enix.',
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Licenses'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showCredits(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Credits'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VanaDeck',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Original app and addon source by VanaDeck contributors.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Acknowledgements',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Built with Flutter and Dart, with Material icon support.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The companion addon targets the Ashita addon environment. Ashita documentation credits atom0s and ThornyFFXI as lead developers.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mappy map support is intended for user-selected local map folders. Development references included Brehanin\'s Map Pack, formerly Sean\'s Map Pack, and community map.ini work from JP, NA, EU, and Windower contributors.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Disclaimer',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This project is unofficial and is not affiliated with, sponsored by, or endorsed by Square Enix, Ashita, Windower, or the FINAL FANTASY XI team.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'FINAL FANTASY XI and related names are trademarks or registered trademarks of Square Enix Holdings Co., Ltd. or its affiliates.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _KeyboardSetupActions extends StatelessWidget {
  const _KeyboardSetupActions({
    required this.currentKeyboardName,
    required this.onEnableKeyboard,
    required this.onSwitchKeyboard,
  });

  final String? currentKeyboardName;
  final Future<void> Function() onEnableKeyboard;
  final Future<void> Function() onSwitchKeyboard;

  @override
  Widget build(BuildContext context) {
    final current = _keyboardLabel(currentKeyboardName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () {
                onEnableKeyboard();
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Keyboard settings'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                onSwitchKeyboard();
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch keyboard'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Current: $current', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  String _keyboardLabel(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Unknown';
    }
    return trimmed;
  }
}

class _OverlaySetting extends StatelessWidget {
  const _OverlaySetting({
    required this.supported,
    required this.permissionGranted,
    required this.running,
    required this.busy,
    required this.scale,
    required this.appearance,
    required this.tabPosition,
    required this.onRequestPermission,
    required this.onStart,
    required this.onStop,
    required this.onScaleChanged,
    required this.onAppearanceChanged,
    required this.onTabPositionChanged,
  });

  final bool supported;
  final bool permissionGranted;
  final bool running;
  final bool busy;
  final double scale;
  final OverlayAppearance appearance;
  final OverlayTabPosition tabPosition;
  final Future<void> Function() onRequestPermission;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<OverlayAppearance> onAppearanceChanged;
  final ValueChanged<OverlayTabPosition> onTabPositionChanged;

  @override
  Widget build(BuildContext context) {
    final valueLabel = '${(scale * 100).round()}%';
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Floating controls',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    supported
                        ? running
                              ? 'Overlay Mode is running'
                              : permissionGranted
                              ? 'Ready for a single display'
                              : 'Android overlay permission required'
                        : 'Overlay Mode is unavailable on this Android version',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!permissionGranted && supported)
              OutlinedButton.icon(
                onPressed: busy ? null : onRequestPermission,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Allow'),
              )
            else
              FilledButton.icon(
                onPressed: !supported || busy
                    ? null
                    : running
                    ? onStop
                    : onStart,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        running ? Icons.close_fullscreen : Icons.open_in_full,
                      ),
                label: Text(running ? 'Stop' : 'Start'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Scale', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: scale,
          min: AppSettingsService.minOverlayScale,
          max: AppSettingsService.maxOverlayScale,
          divisions:
              ((AppSettingsService.maxOverlayScale -
                          AppSettingsService.minOverlayScale) /
                      0.05)
                  .round(),
          label: valueLabel,
          onChanged: supported ? onScaleChanged : null,
        ),
        const SizedBox(height: 10),
        Text('Theme', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<OverlayAppearance>(
          segments: [
            for (final option in OverlayAppearance.values)
              ButtonSegment(value: option, label: Text(option.label)),
          ],
          selected: {appearance},
          showSelectedIcon: false,
          onSelectionChanged: supported
              ? (selection) => onAppearanceChanged(selection.first)
              : null,
        ),
        const SizedBox(height: 14),
        Text('Icon Bar', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<OverlayTabPosition>(
          segments: [
            for (final option in OverlayTabPosition.values)
              ButtonSegment(value: option, label: Text(option.label)),
          ],
          selected: {tabPosition},
          showSelectedIcon: false,
          onSelectionChanged: supported
              ? (selection) => onTabPositionChanged(selection.first)
              : null,
        ),
      ],
    );
  }
}

class _FolderSetting extends StatelessWidget {
  const _FolderSetting({
    required this.title,
    required this.subtitle,
    required this.selecting,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool selecting;
  final Future<bool> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: selecting ? null : onPressed,
          icon: selecting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open),
          label: Text(selecting ? 'Opening' : 'Choose'),
        ),
      ],
    );
  }
}

class _ThemeModeSetting extends StatelessWidget {
  const _ThemeModeSetting({
    required this.selectedMode,
    required this.isOledBlack,
    required this.onDarkSelected,
    required this.onLightSelected,
    required this.onOledBlackSelected,
  });

  final ThemeMode selectedMode;
  final bool isOledBlack;
  final Future<void> Function() onDarkSelected;
  final Future<void> Function() onLightSelected;
  final Future<void> Function() onOledBlackSelected;

  @override
  Widget build(BuildContext context) {
    final selected = isOledBlack
        ? _AppearanceMode.oled
        : selectedMode == ThemeMode.light
        ? _AppearanceMode.light
        : _AppearanceMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mode', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<_AppearanceMode>(
          segments: const [
            ButtonSegment(
              value: _AppearanceMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
            ButtonSegment(
              value: _AppearanceMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: _AppearanceMode.oled,
              icon: Icon(Icons.contrast),
              label: Text('OLED black'),
            ),
          ],
          selected: {selected},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            switch (selection.first) {
              case _AppearanceMode.dark:
                onDarkSelected();
              case _AppearanceMode.light:
                onLightSelected();
              case _AppearanceMode.oled:
                onOledBlackSelected();
            }
          },
        ),
      ],
    );
  }
}

enum _AppearanceMode { dark, light, oled }

class _MacroCastFeedbackStyleSetting extends StatelessWidget {
  const _MacroCastFeedbackStyleSetting({
    required this.selectedStyle,
    required this.onSelected,
  });

  final MacroCastFeedbackStyle selectedStyle;
  final ValueChanged<MacroCastFeedbackStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Macro cast feedback',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<MacroCastFeedbackStyle>(
          segments: const [
            ButtonSegment(
              value: MacroCastFeedbackStyle.fillBar,
              icon: Icon(Icons.align_horizontal_left),
              label: Text('Fill bar'),
            ),
            ButtonSegment(
              value: MacroCastFeedbackStyle.edgeGlow,
              icon: Icon(Icons.border_outer),
              label: Text('Edge glow'),
            ),
          ],
          selected: {selectedStyle},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onSelected(selection.first),
        ),
      ],
    );
  }
}

class _ColorStyleSetting extends StatelessWidget {
  const _ColorStyleSetting({
    required this.title,
    required this.style,
    required this.colors,
    required this.onStyleChanged,
    required this.onStartColorChanged,
    required this.onEndColorChanged,
    required this.onReset,
    this.onMatchButton,
  });

  final String title;
  final ColorFillStyle style;
  final SurfaceGradientColors colors;
  final ValueChanged<ColorFillStyle> onStyleChanged;
  final ValueChanged<Color> onStartColorChanged;
  final ValueChanged<Color> onEndColorChanged;
  final VoidCallback onReset;
  final VoidCallback? onMatchButton;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gradient = style == ColorFillStyle.gradation
        ? LinearGradient(colors: [colors.start, colors.end])
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: colors.start,
            gradient: gradient,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<ColorFillStyle>(
          segments: [
            for (final option in ColorFillStyle.values)
              ButtonSegment(value: option, label: Text(option.label)),
          ],
          selected: {style},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onStyleChanged(selection.first),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GradientColorButton(
              label: style == ColorFillStyle.solid ? 'Color' : 'Start color',
              color: colors.start,
              onSelected: onStartColorChanged,
            ),
            if (style == ColorFillStyle.gradation)
              _GradientColorButton(
                label: 'End color',
                color: colors.end,
                onSelected: onEndColorChanged,
              ),
            if (onMatchButton != null)
              OutlinedButton.icon(
                onPressed: onMatchButton,
                icon: const Icon(Icons.format_paint_outlined),
                label: const Text('Match button'),
              ),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GradientColorButton extends StatelessWidget {
  const _GradientColorButton({
    required this.label,
    required this.color,
    required this.onSelected,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showColorPicker(context),
      icon: _ColorSwatch(color: color, size: 18),
      label: Text(label),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) =>
          _ColorPickerDialog(initialColor: color, title: 'Choose $label'),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }
}

class _ThemeColorSetting extends StatelessWidget {
  const _ThemeColorSetting({
    required this.title,
    required this.selectedColor,
    required this.onSelected,
    this.onReset,
  });

  final String title;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ColorSwatch(color: selectedColor, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title $hex',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _showColorPicker(context),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Choose color'),
            ),
            if (onReset != null)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: selectedColor,
        title: 'Choose $title',
      ),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor, required this.title});

  final Color initialColor;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  static const _presetColors = [
    Color(0xFF3E6B5B),
    Color(0xFF1C7C82),
    Color(0xFF2962A8),
    Color(0xFF5D6AA2),
    Color(0xFF80589B),
    Color(0xFFA84C63),
    Color(0xFF9B5D2E),
    Color(0xFF7D7334),
    Color(0xFF2F6F3E),
    Color(0xFF263238),
    Colors.black,
    Color(0xFFF7FAF8),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ColorSwatch(color: _selectedColor, size: 34),
                  const SizedBox(width: 10),
                  Text(hex, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _presetColors)
                    _ColorChoice(
                      color: color,
                      selected: color.toARGB32() == _selectedColor.toARGB32(),
                      onTap: () => setState(() {
                        _selectedColor = color;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _ColorChannelSlider(
                label: 'Red',
                value: _red(_selectedColor),
                activeColor: Colors.red,
                onChanged: (value) => _setChannel(red: value),
              ),
              _ColorChannelSlider(
                label: 'Green',
                value: _green(_selectedColor),
                activeColor: Colors.green,
                onChanged: (value) => _setChannel(green: value),
              ),
              _ColorChannelSlider(
                label: 'Blue',
                value: _blue(_selectedColor),
                activeColor: Colors.blue,
                onChanged: (value) => _setChannel(blue: value),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('OK'),
        ),
      ],
    );
  }

  void _setChannel({int? red, int? green, int? blue}) {
    setState(() {
      _selectedColor = Color.fromARGB(
        255,
        red ?? _red(_selectedColor),
        green ?? _green(_selectedColor),
        blue ?? _blue(_selectedColor),
      );
    });
  }

  int _red(Color color) {
    return (color.toARGB32() >> 16) & 0xff;
  }

  int _green(Color color) {
    return (color.toARGB32() >> 8) & 0xff;
  }

  int _blue(Color color) {
    return color.toARGB32() & 0xff;
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;

    return Tooltip(
      message:
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 3 : 1),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}

class _ColorChannelSlider extends StatelessWidget {
  const _ColorChannelSlider({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color activeColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            activeColor: activeColor,
            label: value.toString(),
            onChanged: (newValue) => onChanged(newValue.round()),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value.toString(), textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _ChatColorSetting extends StatelessWidget {
  const _ChatColorSetting({
    required this.colors,
    required this.onSelected,
    required this.onReset,
  });

  final Map<ChatColorRole, Color> colors;
  final void Function(ChatColorRole role, Color color) onSelected;
  final VoidCallback onReset;

  static const _roles = [
    ChatColorRole.say,
    ChatColorRole.tell,
    ChatColorRole.party,
    ChatColorRole.linkshell,
    ChatColorRole.linkshellTwo,
    ChatColorRole.assistJ,
    ChatColorRole.assistE,
    ChatColorRole.unity,
    ChatColorRole.emote,
    ChatColorRole.message,
    ChatColorRole.npc,
    ChatColorRole.shout,
    ChatColorRole.yell,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Chat colors',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final role in _roles)
              _ChatColorRow(
                role: role,
                color: colors[role] ?? role.defaultColor,
                onSelected: (color) => onSelected(role, color),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChatColorRow extends StatelessWidget {
  const _ChatColorRow({
    required this.role,
    required this.color,
    required this.onSelected,
  });

  final ChatColorRole role;
  final Color color;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: _ColorSwatch(color: color, size: 24),
      title: Text(role.label),
      subtitle: Text(hex),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showColorPicker(context),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: color,
        title: 'Choose ${role.label}',
      ),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }
}

class _ChatTypographySetting extends StatelessWidget {
  const _ChatTypographySetting({
    required this.fontFamily,
    required this.fontSize,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
  });

  final String fontFamily;
  final double fontSize;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;

  static const _fontOptions = [
    DropdownMenuItem(value: 'jp-sans', child: Text('Japanese Sans')),
    DropdownMenuItem(value: 'sans-serif', child: Text('System Sans')),
    DropdownMenuItem(value: 'sans-serif-medium', child: Text('System Medium')),
    DropdownMenuItem(
      value: 'sans-serif-condensed',
      child: Text('System Condensed'),
    ),
    DropdownMenuItem(value: 'monospace', child: Text('Monospace')),
    DropdownMenuItem(value: 'serif', child: Text('Serif')),
    DropdownMenuItem(value: 'casual', child: Text('Casual')),
    DropdownMenuItem(value: 'jp-gothic', child: Text('Japanese Gothic')),
    DropdownMenuItem(value: 'jp-serif', child: Text('Japanese Serif')),
    DropdownMenuItem(value: 'jp-mincho', child: Text('Japanese Mincho')),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chat text', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _fontOptions.any((option) => option.value == fontFamily)
              ? fontFamily
              : AppSettingsController.defaultChatFontFamily,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Font',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _fontOptions,
          onChanged: (value) {
            if (value != null) {
              onFontFamilyChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 52, child: Text('Size')),
            Expanded(
              child: Slider(
                value: fontSize,
                min: 11,
                max: 22,
                divisions: 11,
                label: fontSize.round().toString(),
                onChanged: onFontSizeChanged,
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                fontSize.round().toString(),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackgroundImageSetting extends StatelessWidget {
  const _BackgroundImageSetting({
    required this.imageName,
    required this.selecting,
    required this.onChoose,
    required this.onClear,
  });

  final String? imageName;
  final bool selecting;
  final Future<bool> Function() onChoose;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Background image',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                imageName ?? 'Use themed app background',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (imageName != null)
          IconButton(
            tooltip: 'Clear background image',
            onPressed: selecting ? null : onClear,
            icon: const Icon(Icons.close),
          ),
        FilledButton.icon(
          onPressed: selecting ? null : onChoose,
          icon: selecting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
          label: Text(selecting ? 'Opening' : 'Choose'),
        ),
      ],
    );
  }
}
