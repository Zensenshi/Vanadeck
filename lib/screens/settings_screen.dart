import 'package:flutter/material.dart';

import '../services/app_settings_controller.dart';
import '../services/ime_input_service.dart';
import '../services/map_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _imeInputService = const ImeInputService();
  String? _mapsFolderName;
  ImeInputStatus _imeStatus = const ImeInputStatus();
  bool _selectingMapsFolder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_handleSettingsChanged);
    _mapsFolderName = MapService.mapsFolderName;
    _loadMapsFolderName();
    _refreshKeyboardStatus();
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
                      onSelected: widget.settings.setThemeMode,
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ThemeColorSetting(
                      title: 'App color',
                      selectedColor: widget.settings.seedColor,
                      onSelected: widget.settings.setSeedColor,
                      showOledBlack: true,
                      onReset: () => widget.settings.setSeedColor(
                        AppSettingsController.defaultSeedColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _ThemeColorSetting(
                      title: 'Navigation color',
                      selectedColor: widget.settings.navigationSeedColor,
                      onSelected: widget.settings.setNavigationSeedColor,
                      onReset: () => widget.settings.setNavigationSeedColor(
                        AppSettingsController.defaultSeedColor,
                      ),
                      onMatchApp: () => widget.settings.setNavigationSeedColor(
                        widget.settings.seedColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    _GradientSchemeSetting(
                      selectedScheme: widget.settings.backgroundGradientScheme,
                      onSelected: widget.settings.setBackgroundGradientScheme,
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
                const _AboutSetting(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
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
    required this.onSelected,
  });

  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mode', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
          ],
          selected: {
            selectedMode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark,
          },
          onSelectionChanged: (selected) => onSelected(selected.first),
        ),
      ],
    );
  }
}

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

class _GradientSchemeSetting extends StatelessWidget {
  const _GradientSchemeSetting({
    required this.selectedScheme,
    required this.onSelected,
  });

  final AppGradientScheme selectedScheme;
  final ValueChanged<AppGradientScheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Surface style', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<AppGradientScheme>(
          initialValue: selectedScheme,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final scheme in AppGradientScheme.values)
              DropdownMenuItem(value: scheme, child: Text(scheme.label)),
          ],
          onChanged: (value) {
            if (value != null) {
              onSelected(value);
            }
          },
        ),
      ],
    );
  }
}

class _ThemeColorSetting extends StatelessWidget {
  const _ThemeColorSetting({
    required this.title,
    required this.selectedColor,
    required this.onSelected,
    this.showOledBlack = false,
    this.onReset,
    this.onMatchApp,
  });

  final String title;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;
  final bool showOledBlack;
  final VoidCallback? onReset;
  final VoidCallback? onMatchApp;

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
            if (showOledBlack)
              OutlinedButton.icon(
                onPressed: () => onSelected(Colors.black),
                icon: const Icon(Icons.contrast),
                label: const Text('OLED black'),
              ),
            if (onMatchApp != null)
              OutlinedButton.icon(
                onPressed: onMatchApp,
                icon: const Icon(Icons.format_paint_outlined),
                label: const Text('Match app'),
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
