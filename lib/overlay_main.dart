import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/party_member.dart';
import 'models/player_status.dart';
import 'services/app_settings_controller.dart';
import 'services/game_status_service.dart';
import 'services/map_service.dart';
import 'services/overlay_service.dart';

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const VanaDeckOverlayApp());
}

class VanaDeckOverlayApp extends StatefulWidget {
  const VanaDeckOverlayApp({super.key});

  @override
  State<VanaDeckOverlayApp> createState() => _VanaDeckOverlayAppState();
}

class _VanaDeckOverlayAppState extends State<VanaDeckOverlayApp> {
  static const _channel = MethodChannel('vanadeck/overlay');

  OverlayAppearance _appearance = AppSettingsService.defaultOverlayAppearance;
  OverlayTabPosition _tabPosition =
      AppSettingsService.defaultOverlayTabPosition;
  ColorFillStyle _iconBarColorStyle = ColorFillStyle.solid;
  SurfaceGradientColors _iconBarColors =
      AppSettingsService.defaultIconBarColors;
  Color _buttonColor = AppSettingsController.defaultSeedColor;
  Color _buttonTextColor = AppSettingsController.defaultButtonTextColor;
  Color _macroCastFeedbackColor =
      AppSettingsController.defaultCastFeedbackColor;

  @override
  void initState() {
    super.initState();
    _loadAppearance();
    _channel.setMethodCallHandler(_handleOverlayMethodCall);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _loadAppearance() async {
    final service = const AppSettingsService();
    final appearance = await service.loadOverlayAppearance();
    final tabPosition = await service.loadOverlayTabPosition();
    final iconBarColorStyle = await service.loadIconBarColorStyle();
    final iconBarColors = await service.loadIconBarColors();
    final buttonColor = await service.loadButtonColor();
    final buttonTextColor = await service.loadButtonTextColor();
    final macroCastFeedbackColor = await service.loadMacroCastFeedbackColor();
    if (!mounted) {
      return;
    }
    setState(() {
      _appearance = appearance;
      _tabPosition = tabPosition;
      _iconBarColorStyle = iconBarColorStyle;
      _iconBarColors = iconBarColors;
      _buttonColor = buttonColor;
      _buttonTextColor = buttonTextColor;
      _macroCastFeedbackColor = macroCastFeedbackColor;
    });
  }

  Future<void> _handleOverlayMethodCall(MethodCall call) async {
    if (call.method == 'setAppearance') {
      final appearance = _parseAppearance(call.arguments);
      if (!mounted || appearance == null) {
        return;
      }
      setState(() {
        _appearance = appearance;
      });
      return;
    }

    if (call.method == 'setTabPosition') {
      final tabPosition = _parseTabPosition(call.arguments);
      if (!mounted || tabPosition == null) {
        return;
      }
      setState(() {
        _tabPosition = tabPosition;
      });
      return;
    }

    if (call.method == 'setOverlayTheme') {
      final theme = _parseOverlayTheme(call.arguments);
      if (!mounted || theme == null) {
        return;
      }
      setState(() {
        _iconBarColorStyle = theme.iconBarColorStyle ?? _iconBarColorStyle;
        _iconBarColors = SurfaceGradientColors(
          start: theme.iconBarStartColor ?? _iconBarColors.start,
          end: theme.iconBarEndColor ?? _iconBarColors.end,
        );
        _buttonColor = theme.buttonColor ?? _buttonColor;
        _buttonTextColor = theme.buttonTextColor ?? _buttonTextColor;
      });
    }
  }

  OverlayAppearance? _parseAppearance(Object? arguments) {
    final value = arguments is Map
        ? arguments['appearance']?.toString()
        : arguments?.toString();
    if (value == null) {
      return null;
    }
    return OverlayAppearance.values.firstWhere(
      (appearance) => appearance.name == value,
      orElse: () => AppSettingsService.defaultOverlayAppearance,
    );
  }

  OverlayTabPosition? _parseTabPosition(Object? arguments) {
    final value = arguments is Map
        ? arguments['tabPosition']?.toString()
        : arguments?.toString();
    if (value == null) {
      return null;
    }
    return OverlayTabPosition.values.firstWhere(
      (position) => position.name == value,
      orElse: () => AppSettingsService.defaultOverlayTabPosition,
    );
  }

  _OverlayThemeUpdate? _parseOverlayTheme(Object? arguments) {
    if (arguments is! Map) {
      return null;
    }
    final iconBarColorStyle = _parseColorFillStyle(
      arguments['iconBarColorStyle'],
    );
    final iconBarStartColor = _parseColor(arguments['iconBarStartColor']);
    final iconBarEndColor = _parseColor(arguments['iconBarEndColor']);
    final buttonColor = _parseColor(arguments['buttonColor']);
    final buttonTextColor = _parseColor(arguments['buttonTextColor']);
    if (iconBarColorStyle == null &&
        iconBarStartColor == null &&
        iconBarEndColor == null &&
        buttonColor == null &&
        buttonTextColor == null) {
      return null;
    }
    return _OverlayThemeUpdate(
      iconBarColorStyle: iconBarColorStyle,
      iconBarStartColor: iconBarStartColor,
      iconBarEndColor: iconBarEndColor,
      buttonColor: buttonColor,
      buttonTextColor: buttonTextColor,
    );
  }

  ColorFillStyle? _parseColorFillStyle(Object? value) {
    final name = value?.toString();
    if (name == null) {
      return null;
    }
    return ColorFillStyle.values.firstWhere(
      (style) => style.name == name,
      orElse: () => _iconBarColorStyle,
    );
  }

  Color? _parseColor(Object? value) {
    final parsed = value is int
        ? value
        : value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return Color(parsed.toUnsigned(32));
  }

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _buttonColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _buttonColor,
          onPrimary: _buttonTextColor,
          primaryContainer: _buttonColor,
          onPrimaryContainer: _buttonTextColor,
        );
    return MaterialApp(
      title: 'VanaDeck Overlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: VanaDeckOverlayPanel(
        appearance: _appearance,
        tabPosition: _tabPosition,
        iconBarColorStyle: _iconBarColorStyle,
        iconBarColors: _iconBarColors,
        buttonColor: _buttonColor,
        buttonTextColor: _buttonTextColor,
        macroCastFeedbackColor: _macroCastFeedbackColor,
      ),
    );
  }
}

class _OverlayThemeUpdate {
  const _OverlayThemeUpdate({
    this.iconBarColorStyle,
    this.iconBarStartColor,
    this.iconBarEndColor,
    this.buttonColor,
    this.buttonTextColor,
  });

  final ColorFillStyle? iconBarColorStyle;
  final Color? iconBarStartColor;
  final Color? iconBarEndColor;
  final Color? buttonColor;
  final Color? buttonTextColor;
}

class VanaDeckOverlayPanel extends StatefulWidget {
  const VanaDeckOverlayPanel({
    super.key,
    required this.appearance,
    required this.tabPosition,
    required this.iconBarColorStyle,
    required this.iconBarColors,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.macroCastFeedbackColor,
  });

  final OverlayAppearance appearance;
  final OverlayTabPosition tabPosition;
  final ColorFillStyle iconBarColorStyle;
  final SurfaceGradientColors iconBarColors;
  final Color buttonColor;
  final Color buttonTextColor;
  final Color macroCastFeedbackColor;

  @override
  State<VanaDeckOverlayPanel> createState() => _VanaDeckOverlayPanelState();
}

class _VanaDeckOverlayPanelState extends State<VanaDeckOverlayPanel> {
  static const _macroInputPrefix = '__vanadeck_macro_input__:';

  late final GameStatusService _statusService;
  late final Stream<PlayerStatus> _statusStream;
  final _chatController = TextEditingController();
  final _chatFocusNode = FocusNode();
  var _macroModifier = _OverlayMacroModifier.ctrl;
  var _selectedTab = _OverlayTab.map;
  var _chatMode = _OverlayChatMode.say;
  var _minimized = false;
  var _sendingChat = false;

  @override
  void initState() {
    super.initState();
    _statusService = const GameStatusService();
    _statusStream = _statusService.statusStream.asBroadcastStream();
    _chatFocusNode.addListener(_handleChatFocusChanged);
    _loadMapData();
  }

  @override
  void dispose() {
    _chatFocusNode.removeListener(_handleChatFocusChanged);
    _chatController.dispose();
    _chatFocusNode.dispose();
    const OverlayService().setKeyboardActive(false);
    super.dispose();
  }

  Future<void> _loadMapData() async {
    await MapService.loadMappyMaps();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleChatFocusChanged() async {
    await const OverlayService().setKeyboardActive(_chatFocusNode.hasFocus);
  }

  Future<void> _sendOverlayCommand(String command) async {
    try {
      await _statusService.sendCommands([command]);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for game connection')),
      );
    }
  }

  Future<void> _sendMacroInput(String action) {
    return _sendOverlayCommand('$_macroInputPrefix$action');
  }

  Future<void> _sendChatMessage() async {
    final body = _chatController.text.trim();
    if (body.isEmpty || _sendingChat) {
      return;
    }

    setState(() {
      _sendingChat = true;
    });

    final message = '${_chatMode.prefix}$body';
    try {
      await _statusService.sendChatMessage(message);
      if (!mounted) {
        return;
      }
      _chatController.clear();
      _chatFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for game connection')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingChat = false;
        });
      }
    }
  }

  Future<void> _focusChatComposer() async {
    await const OverlayService().setKeyboardActive(true);
    if (mounted) {
      _chatFocusNode.requestFocus();
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) {
      _chatFocusNode.requestFocus();
    }
  }

  Future<void> _setMinimized(bool minimized) async {
    if (minimized) {
      _chatFocusNode.unfocus();
      await const OverlayService().setKeyboardActive(false);
    }
    setState(() {
      _minimized = minimized;
    });
    await const OverlayService().setMinimized(minimized);
  }

  Future<void> _stopOverlay() async {
    _chatFocusNode.unfocus();
    await const OverlayService().setKeyboardActive(false);
    await const OverlayService().stop();
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _OverlayMinimizedButton(
          appearance: widget.appearance,
          onRestore: () => _setMinimized(false),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _OverlaySurface(
        appearance: widget.appearance,
        child: StreamBuilder<PlayerStatus>(
          stream: _statusStream,
          builder: (context, snapshot) {
            final status = snapshot.data;
            return _OverlayPanelLayout(
              tabPosition: widget.tabPosition,
              bar: _OverlayControlBar(
                appearance: widget.appearance,
                tabPosition: widget.tabPosition,
                iconBarColorStyle: widget.iconBarColorStyle,
                iconBarColors: widget.iconBarColors,
                buttonColor: widget.buttonColor,
                buttonTextColor: widget.buttonTextColor,
                selectedTab: _selectedTab,
                onTabSelected: (tab) {
                  if (tab != _OverlayTab.chat) {
                    _chatFocusNode.unfocus();
                    const OverlayService().setKeyboardActive(false);
                  } else {
                    const OverlayService().setKeyboardActive(true);
                  }
                  setState(() {
                    _selectedTab = tab;
                  });
                },
                onMinimize: () => _setMinimized(true),
                onStop: _stopOverlay,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: status == null
                    ? const _OverlayWaitingState()
                    : _OverlayTabBody(
                        tab: _selectedTab,
                        status: status,
                        modifier: _macroModifier,
                        macroCastFeedbackColor: widget.macroCastFeedbackColor,
                        buttonColor: widget.buttonColor,
                        buttonTextColor: widget.buttonTextColor,
                        onModifierChanged: (modifier) {
                          setState(() {
                            _macroModifier = modifier;
                          });
                        },
                        onMacroInput: _sendMacroInput,
                        chatController: _chatController,
                        chatFocusNode: _chatFocusNode,
                        chatMode: _chatMode,
                        sendingChat: _sendingChat,
                        onChatModeChanged: (mode) {
                          setState(() {
                            _chatMode = mode;
                          });
                          _focusChatComposer();
                        },
                        onChatFieldTap: _focusChatComposer,
                        onSendChat: _sendChatMessage,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverlaySurface extends StatelessWidget {
  const _OverlaySurface({
    required this.appearance,
    required this.child,
    this.iconOnly = false,
  });

  final OverlayAppearance appearance;
  final Widget child;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final palette = _OverlayPalette.forAppearance(appearance);
    final radius = BorderRadius.circular(iconOnly ? 999 : 12);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        gradient: palette.gradient,
        border: Border.all(color: palette.border),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: iconOnly
                ? 10
                : appearance == OverlayAppearance.gameGlass
                ? 14
                : 18,
            offset: iconOnly ? const Offset(0, 4) : const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: radius,
      child: appearance == OverlayAppearance.gameGlass
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: panel,
            )
          : panel,
    );
  }
}

class _OverlayPalette {
  const _OverlayPalette({
    required this.surface,
    required this.handle,
    required this.border,
    required this.shadow,
    this.gradient,
  });

  final Color surface;
  final Color handle;
  final Color border;
  final Color shadow;
  final Gradient? gradient;

  static _OverlayPalette forAppearance(OverlayAppearance appearance) {
    return switch (appearance) {
      OverlayAppearance.gameGlass => _OverlayPalette(
        surface: const Color(0x4D0B1112),
        handle: const Color(0x4D0B1112),
        border: Colors.white.withValues(alpha: 0.30),
        shadow: const Color(0x52000000),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      OverlayAppearance.solidDark => const _OverlayPalette(
        surface: Color(0xF20B1112),
        handle: Color(0xF20B1112),
        border: Color(0x805E756E),
        shadow: Color(0xAA000000),
      ),
    };
  }
}

class _OverlayMinimizedButton extends StatelessWidget {
  const _OverlayMinimizedButton({
    required this.appearance,
    required this.onRestore,
  });

  final OverlayAppearance appearance;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return _OverlaySurface(
      appearance: appearance,
      iconOnly: true,
      child: Center(
        child: IconButton.filledTonal(
          tooltip: 'Restore VanaDeck',
          onPressed: onRestore,
          icon: const Icon(Icons.open_in_full, size: 20),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(42),
            fixedSize: const Size.square(42),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _OverlayPanelLayout extends StatelessWidget {
  const _OverlayPanelLayout({
    required this.tabPosition,
    required this.bar,
    required this.child,
  });

  final OverlayTabPosition tabPosition;
  final Widget bar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (tabPosition) {
      OverlayTabPosition.bottom => Column(
        children: [
          Expanded(child: child),
          bar,
        ],
      ),
      OverlayTabPosition.left => Row(
        children: [
          bar,
          Expanded(child: child),
        ],
      ),
      OverlayTabPosition.right => Row(
        children: [
          Expanded(child: child),
          bar,
        ],
      ),
      OverlayTabPosition.top => Column(
        children: [
          bar,
          Expanded(child: child),
        ],
      ),
    };
  }
}

class _OverlayControlBar extends StatelessWidget {
  const _OverlayControlBar({
    required this.appearance,
    required this.tabPosition,
    required this.iconBarColorStyle,
    required this.iconBarColors,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onMinimize,
    required this.onStop,
  });

  final OverlayAppearance appearance;
  final OverlayTabPosition tabPosition;
  final ColorFillStyle iconBarColorStyle;
  final SurfaceGradientColors iconBarColors;
  final Color buttonColor;
  final Color buttonTextColor;
  final _OverlayTab selectedTab;
  final ValueChanged<_OverlayTab> onTabSelected;
  final VoidCallback onMinimize;
  final VoidCallback onStop;

  bool get _vertical =>
      tabPosition == OverlayTabPosition.left ||
      tabPosition == OverlayTabPosition.right;

  @override
  Widget build(BuildContext context) {
    final palette = _OverlayPalette.forAppearance(appearance);
    final barColor = iconBarColors.iconBarColor(
      style: iconBarColorStyle,
      baseColor: palette.handle,
    );
    final barDecoration = BoxDecoration(
      color: barColor,
      gradient: iconBarColors.iconBarGradient(
        style: iconBarColorStyle,
        baseColor: barColor,
        vertical: _vertical,
      ),
    );
    final tabButtons = [
      for (final tab in _OverlayTab.values)
        _OverlayIconBarButton(
          tab: tab,
          selected: selectedTab == tab,
          buttonColor: buttonColor,
          buttonTextColor: buttonTextColor,
          onPressed: () => onTabSelected(tab),
        ),
    ];
    final minimizeButton = IconButton(
      tooltip: 'Minimize VanaDeck',
      onPressed: onMinimize,
      icon: Icon(Icons.minimize, size: 17, color: buttonTextColor),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(30),
        fixedSize: const Size.square(30),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
    final stopButton = IconButton(
      tooltip: 'Stop overlay mode',
      onPressed: onStop,
      icon: Icon(Icons.close_fullscreen, size: 17, color: buttonTextColor),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(30),
        fixedSize: const Size.square(30),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    if (_vertical) {
      return Container(
        width: 40,
        decoration: barDecoration,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Column(
          children: [
            Icon(Icons.drag_indicator, size: 18, color: buttonTextColor),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: tabButtons,
              ),
            ),
            minimizeButton,
            stopButton,
          ],
        ),
      );
    }

    return Container(
      height: 40,
      decoration: barDecoration,
      padding: const EdgeInsets.only(left: 7, right: 4),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 18, color: buttonTextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: tabButtons,
            ),
          ),
          minimizeButton,
          stopButton,
        ],
      ),
    );
  }
}

class _OverlayIconBarButton extends StatelessWidget {
  const _OverlayIconBarButton({
    required this.tab,
    required this.selected,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.onPressed,
  });

  final _OverlayTab tab;
  final bool selected;
  final Color buttonColor;
  final Color buttonTextColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: IconButton(
        tooltip: tab.label,
        onPressed: onPressed,
        icon: Icon(tab.icon, size: 17),
        style: IconButton.styleFrom(
          foregroundColor: buttonTextColor.withValues(
            alpha: selected ? 1 : 0.78,
          ),
          backgroundColor: selected
              ? buttonColor.withValues(alpha: 0.70)
              : Colors.white.withValues(alpha: 0.04),
          minimumSize: const Size.square(30),
          fixedSize: const Size.square(30),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

enum _OverlayTab {
  map('Map', Icons.explore),
  macros('Macros', Icons.keyboard_command_key),
  chat('Chat', Icons.chat_bubble);

  const _OverlayTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _OverlayWaitingState extends StatelessWidget {
  const _OverlayWaitingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(strokeWidth: 2),
        const SizedBox(height: 14),
        Text(
          'Waiting for addon',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Keep VanaDeck loaded in Ashita.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OverlayTabBody extends StatelessWidget {
  const _OverlayTabBody({
    required this.tab,
    required this.status,
    required this.modifier,
    required this.macroCastFeedbackColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.onModifierChanged,
    required this.onMacroInput,
    required this.chatController,
    required this.chatFocusNode,
    required this.chatMode,
    required this.sendingChat,
    required this.onChatModeChanged,
    required this.onChatFieldTap,
    required this.onSendChat,
  });

  final _OverlayTab tab;
  final PlayerStatus status;
  final _OverlayMacroModifier modifier;
  final Color macroCastFeedbackColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final ValueChanged<_OverlayMacroModifier> onModifierChanged;
  final Future<void> Function(String action) onMacroInput;
  final TextEditingController chatController;
  final FocusNode chatFocusNode;
  final _OverlayChatMode chatMode;
  final bool sendingChat;
  final ValueChanged<_OverlayChatMode> onChatModeChanged;
  final VoidCallback onChatFieldTap;
  final Future<void> Function() onSendChat;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      _OverlayTab.map => _OverlayMapTab(status: status),
      _OverlayTab.macros => _OverlayMacroTab(
        status: status,
        modifier: modifier,
        macroCastFeedbackColor: macroCastFeedbackColor,
        buttonColor: buttonColor,
        buttonTextColor: buttonTextColor,
        onModifierChanged: onModifierChanged,
        onMacroInput: onMacroInput,
      ),
      _OverlayTab.chat => _OverlayChatTab(
        controller: chatController,
        focusNode: chatFocusNode,
        mode: chatMode,
        sending: sendingChat,
        onModeChanged: onChatModeChanged,
        onFieldTap: onChatFieldTap,
        onSend: onSendChat,
      ),
    };
  }
}

class _OverlayMacroTab extends StatefulWidget {
  const _OverlayMacroTab({
    required this.status,
    required this.modifier,
    required this.macroCastFeedbackColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.onModifierChanged,
    required this.onMacroInput,
  });

  final PlayerStatus status;
  final _OverlayMacroModifier modifier;
  final Color macroCastFeedbackColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final ValueChanged<_OverlayMacroModifier> onModifierChanged;
  final Future<void> Function(String action) onMacroInput;

  @override
  State<_OverlayMacroTab> createState() => _OverlayMacroTabState();
}

class _OverlayMacroTabState extends State<_OverlayMacroTab> {
  static const _feedbackDuration = Duration(milliseconds: 2200);
  static const _maxFeedbackListenDuration = Duration(seconds: 30);

  String? _glowingMacroKey;
  String? _listeningMacroKey;
  DateTime? _feedbackListenUntil;
  Timer? _glowTimer;
  int _glowPulseId = 0;
  bool _gameCastActive = false;
  double? _lastGameCastProgress;

  @override
  void dispose() {
    _glowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateGameCastTracking(
      isCasting: widget.status.castState?.isCasting ?? false,
      progress: widget.status.castState?.progress?.clamp(0.0, 1.0).toDouble(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 120) {
          return;
        }
        widget.onModifierChanged(
          velocity < 0 ? _OverlayMacroModifier.alt : _OverlayMacroModifier.ctrl,
        );
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 160) {
          return;
        }
        unawaited(widget.onMacroInput(velocity < 0 ? 'page_up' : 'page_down'));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OverlayMacroHeader(status: widget.status, modifier: widget.modifier),
          const SizedBox(height: 6),
          Expanded(
            child: _OverlayMacroGrid(
              status: widget.status,
              modifier: widget.modifier,
              glowingMacroKey: _glowingMacroKey,
              glowPulseId: _glowPulseId,
              glowColor: widget.macroCastFeedbackColor,
              buttonColor: widget.buttonColor,
              buttonTextColor: widget.buttonTextColor,
              onMacroPressed: (context, slot, needsTarget) {
                return _handleMacroPressed(context, slot, needsTarget);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMacroPressed(
    BuildContext context,
    int slot,
    bool needsTarget,
  ) async {
    if (!needsTarget || widget.status.partyMembers.isEmpty) {
      await widget.onMacroInput('${widget.modifier.commandValue}:$slot');
      _startGlow(slot);
      return;
    }

    final selectedPartyIndex = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) {
        return _OverlayPartyTargetDialog(
          targets: widget.status.partyMembers.take(6).toList(),
        );
      },
    );
    if (selectedPartyIndex == null) {
      return;
    }

    await widget.onMacroInput(
      'targeted:${widget.modifier.commandValue}:$slot:$selectedPartyIndex',
    );
    _startGlow(slot);
  }

  void _startGlow(int slot) {
    final macroKey = _macroKey(widget.modifier, slot);
    _listeningMacroKey = macroKey;
    _feedbackListenUntil = DateTime.now().add(_maxFeedbackListenDuration);
    _showGlowPulse(macroKey);
  }

  void _showGlowPulse(String macroKey) {
    _glowTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _glowingMacroKey = macroKey;
      _glowPulseId += 1;
    });
    _glowTimer = Timer(_feedbackDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _glowingMacroKey = null;
      });
    });
  }

  void _updateGameCastTracking({
    required bool isCasting,
    required double? progress,
  }) {
    final wasCasting = _gameCastActive;
    final previousProgress = _lastGameCastProgress;
    _gameCastActive = isCasting;
    _lastGameCastProgress = isCasting ? progress : null;

    final castStarted = isCasting && !wasCasting;
    final castProgressRestarted =
        isCasting &&
        wasCasting &&
        _castProgressRestarted(previousProgress, progress);
    if (!castStarted && !castProgressRestarted) {
      return;
    }

    final macroKey = _activeListeningMacroKey();
    if (macroKey == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gameCastActive) {
        return;
      }

      final activeMacroKey = _activeListeningMacroKey();
      if (activeMacroKey == null) {
        return;
      }

      _showGlowPulse(activeMacroKey);
    });
  }

  bool _castProgressRestarted(double? previous, double? current) {
    if (previous == null || current == null) {
      return false;
    }

    return previous > 0.55 && current < 0.35 && previous - current > 0.35;
  }

  String? _activeListeningMacroKey() {
    final macroKey = _listeningMacroKey;
    final listenUntil = _feedbackListenUntil;
    if (macroKey == null || listenUntil == null) {
      return null;
    }
    if (DateTime.now().isAfter(listenUntil)) {
      _listeningMacroKey = null;
      _feedbackListenUntil = null;
      return null;
    }

    return macroKey;
  }

  String _macroKey(_OverlayMacroModifier modifier, int slot) {
    return '${modifier.commandValue}:$slot';
  }
}

class _OverlayMacroHeader extends StatelessWidget {
  const _OverlayMacroHeader({required this.status, required this.modifier});

  final PlayerStatus status;
  final _OverlayMacroModifier modifier;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Text(
            'Set ${status.activeMacroBook}-${status.activeMacroSet}',
            style: textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            modifier.label,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPartyTargetDialog extends StatelessWidget {
  const _OverlayPartyTargetDialog({required this.targets});

  final List<PartyMember> targets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Subtarget',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 16),
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(28),
                      fixedSize: const Size.square(28),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    return _OverlayPartyTargetRow(
                      member: targets[index],
                      index: index,
                      onTap: () => Navigator.of(context).pop(index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayPartyTargetRow extends StatelessWidget {
  const _OverlayPartyTargetRow({
    required this.member,
    required this.index,
    required this.onTap,
  });

  final PartyMember member;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.lightBlueAccent.shade400),
                ),
                child: Text(
                  '<p$index>',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Lv.${member.level} ${member.job}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: member.hpPercent,
                    color: Colors.redAccent.shade400,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayMapTab extends StatelessWidget {
  const _OverlayMapTab({required this.status});

  final PlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final player = status.partyMembers.isEmpty ? null : status.partyMembers[0];
    final zone = player?.location ?? '';
    final mapEntry = player == null
        ? MapService.getMappyMapEntry(zone)
        : MapService.getMappyMapEntry(
            zone,
            zoneId: player.zoneId,
            subMapNum: player.subMapNum,
            worldX: player.worldX,
            worldY: player.worldY,
            worldZ: player.worldZ,
          );
    final imageUri = mapEntry?.imageUri;

    if (player == null || imageUri == null || mapEntry == null) {
      final message = MapService.mapsFolderName == null
          ? 'Select Mappy Maps in Settings'
          : zone.isEmpty
          ? 'Waiting for location'
          : 'No map for $zone';
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final playerPosition = _playerMapPosition(player, zone);
    final markers = _entityMarkers(
      zone: zone,
      zoneId: player.zoneId,
      mapEntry: mapEntry,
    );

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: _OverlayMapViewport(
            imageUri: imageUri,
            player: player,
            playerPosition: playerPosition,
            markers: markers,
          ),
        ),
      ),
    );
  }

  Offset _playerMapPosition(PartyMember player, String zone) {
    final worldX = player.worldX;
    final worldMapY = player.worldY ?? player.worldZ;
    if (worldX != null && worldMapY != null) {
      final position = MapService.worldToMap(
        zoneName: zone,
        zoneId: player.zoneId,
        subMapNum: player.subMapNum,
        worldX: worldX,
        worldY: player.worldY,
        worldZ: player.worldZ,
      );
      return Offset(position.x, position.y);
    }

    return Offset(player.locationX, player.locationY);
  }

  List<_OverlayMapMarkerData> _entityMarkers({
    required String zone,
    required int? zoneId,
    required MappyMapEntry mapEntry,
  }) {
    final markers = <_OverlayMapMarkerData>[];
    for (final entity in status.mapEntities) {
      if (!_isEntityInCurrentZone(entity, zone: zone, zoneId: zoneId)) {
        continue;
      }
      if (!entity.isNpc && !entity.isMob) {
        continue;
      }

      final position = _mapEntityPosition(entity, mapEntry);
      if (position == null) {
        continue;
      }
      markers.add(
        _OverlayMapMarkerData(
          position: position,
          color: entity.isMob
              ? const Color(0xFFE86D6D)
              : const Color(0xFF63A6FF),
          size: 1,
        ),
      );
    }
    return markers;
  }

  bool _isEntityInCurrentZone(
    MapEntityLocation entity, {
    required String zone,
    required int? zoneId,
  }) {
    if (entity.zoneId != null && zoneId != null) {
      return entity.zoneId == zoneId;
    }
    return entity.location == zone;
  }

  Offset? _mapEntityPosition(MapEntityLocation entity, MappyMapEntry mapEntry) {
    final worldX = entity.worldX;
    final worldMapY = entity.worldY ?? entity.worldZ;

    if (worldX != null && worldMapY != null) {
      if (entity.worldY != null &&
          entity.worldZ != null &&
          !mapEntry.contains(
            worldX: worldX,
            worldY: entity.worldY,
            worldZ: entity.worldZ,
          )) {
        return null;
      }
      final position = mapEntry.worldToMap(
        worldX: worldX,
        worldMapY: worldMapY,
      );
      return Offset(position.x, position.y);
    }

    return Offset(entity.locationX, entity.locationY);
  }
}

class _OverlayMapViewport extends StatefulWidget {
  const _OverlayMapViewport({
    required this.imageUri,
    required this.player,
    required this.playerPosition,
    required this.markers,
  });

  final String imageUri;
  final PartyMember player;
  final Offset playerPosition;
  final List<_OverlayMapMarkerData> markers;

  @override
  State<_OverlayMapViewport> createState() => _OverlayMapViewportState();
}

class _OverlayMapViewportState extends State<_OverlayMapViewport> {
  static const _defaultScale = 2.0;

  late final TransformationController _transformationController;
  Offset? _lastPlayerPosition;
  String? _lastImageUri;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        _centerOnPlayerWhenNeeded(mapSize: size, viewportSize: viewportSize);

        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(256),
                minScale: 1,
                maxScale: 5,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionStart: (_) {
                  _isInteracting = true;
                },
                onInteractionEnd: (_) {
                  _isInteracting = false;
                },
                child: SizedBox.square(
                  dimension: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _OverlayMappyMapImage(imageUri: widget.imageUri),
                      _OverlayMapMarkers(
                        player: widget.player,
                        playerPosition: widget.playerPosition,
                        markers: widget.markers,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _centerOnPlayerWhenNeeded({
    required double mapSize,
    required Size viewportSize,
  }) {
    final lastPosition = _lastPlayerPosition;
    final mapChanged = _lastImageUri != widget.imageUri;
    final moved =
        lastPosition == null ||
        (widget.playerPosition - lastPosition).distance > 0.0005;

    _lastPlayerPosition = widget.playerPosition;
    _lastImageUri = widget.imageUri;

    if (_isInteracting || (!mapChanged && !moved)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isInteracting || mapSize <= 0) {
        return;
      }

      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      final scale = currentScale <= 1.01 ? _defaultScale : currentScale;
      final playerOffset = Offset(
        widget.playerPosition.dx * mapSize,
        widget.playerPosition.dy * mapSize,
      );
      final centeredOffset =
          viewportSize.center(Offset.zero) -
          Offset(playerOffset.dx * scale, playerOffset.dy * scale);

      _transformationController.value = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, centeredOffset.dx)
        ..setEntry(1, 3, centeredOffset.dy);
    });
  }
}

class _OverlayMapMarkers extends StatelessWidget {
  const _OverlayMapMarkers({
    required this.player,
    required this.playerPosition,
    required this.markers,
  });

  final PartyMember player;
  final Offset playerPosition;
  final List<_OverlayMapMarkerData> markers;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              for (final marker in markers)
                Positioned(
                  left: (constraints.maxWidth * marker.position.dx).clamp(
                    0.0,
                    constraints.maxWidth,
                  ),
                  top: (constraints.maxHeight * marker.position.dy).clamp(
                    0.0,
                    constraints.maxHeight,
                  ),
                  child: _OverlayMapMarker(marker: marker),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 650),
                curve: Curves.linear,
                left: (constraints.maxWidth * playerPosition.dx).clamp(
                  0.0,
                  constraints.maxWidth,
                ),
                top: (constraints.maxHeight * playerPosition.dy).clamp(
                  0.0,
                  constraints.maxHeight,
                ),
                child: _OverlayPlayerMarker(heading: player.heading),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverlayMappyMapImage extends StatelessWidget {
  const _OverlayMappyMapImage({required this.imageUri});

  final String imageUri;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: MapService.loadMappyMapBytes(imageUri),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true);
      },
    );
  }
}

class _OverlayMapMarkerData {
  const _OverlayMapMarkerData({
    required this.position,
    required this.color,
    required this.size,
  });

  final Offset position;
  final Color color;
  final double size;
}

class _OverlayMapMarker extends StatelessWidget {
  const _OverlayMapMarker({required this.marker});

  final _OverlayMapMarkerData marker;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-marker.size / 2, -marker.size / 2),
      child: DecoratedBox(
        decoration: BoxDecoration(color: marker.color, shape: BoxShape.circle),
        child: SizedBox.square(dimension: marker.size),
      ),
    );
  }
}

class _OverlayPlayerMarker extends StatelessWidget {
  const _OverlayPlayerMarker({required this.heading});

  final double? heading;

  @override
  Widget build(BuildContext context) {
    final angle = (heading ?? 0) + 1.5708;
    return Transform.translate(
      offset: const Offset(-6, -6),
      child: Transform.rotate(
        angle: angle,
        child: const Icon(Icons.navigation, color: Color(0xFFFF3333), size: 12),
      ),
    );
  }
}

class _OverlayChatTab extends StatefulWidget {
  const _OverlayChatTab({
    required this.controller,
    required this.focusNode,
    required this.mode,
    required this.sending,
    required this.onModeChanged,
    required this.onFieldTap,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _OverlayChatMode mode;
  final bool sending;
  final ValueChanged<_OverlayChatMode> onModeChanged;
  final VoidCallback onFieldTap;
  final Future<void> Function() onSend;

  @override
  State<_OverlayChatTab> createState() => _OverlayChatTabState();
}

class _OverlayChatTabState extends State<_OverlayChatTab> {
  static const _chatModeHoldDelay = Duration(milliseconds: 360);

  Timer? _chatModeTimer;

  @override
  void dispose() {
    _chatModeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: !widget.sending,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          keyboardType: TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          enableInteractiveSelection: false,
          decoration: InputDecoration(
            hintText: 'Type a message',
            prefixText: widget.mode.prefix,
            prefixStyle: TextStyle(
              color: widget.mode.role.defaultColor,
              fontWeight: FontWeight.w800,
            ),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.22),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
            isDense: true,
          ),
          onTap: widget.onFieldTap,
          onSubmitted: (_) => widget.onSend(),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    widget.onFieldTap();
    _chatModeTimer?.cancel();
    _chatModeTimer = Timer(_chatModeHoldDelay, () {
      _showModeMenu(event.position);
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    _chatModeTimer?.cancel();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _chatModeTimer?.cancel();
  }

  Future<void> _showModeMenu(Offset globalPosition) async {
    if (!mounted) {
      return;
    }

    widget.onFieldTap();
    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize) {
      return;
    }

    final localPosition = overlayBox.globalToLocal(globalPosition);
    final overlaySize = overlayBox.size;
    final selected = await showMenu<_OverlayChatMode>(
      context: context,
      position: RelativeRect.fromLTRB(
        localPosition.dx,
        localPosition.dy,
        overlaySize.width - localPosition.dx,
        overlaySize.height - localPosition.dy,
      ),
      items: [
        for (final option in _OverlayChatMode.menuOrder)
          PopupMenuItem<_OverlayChatMode>(
            value: option,
            height: 36,
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: option.role.defaultColor,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 8),
                ),
                const SizedBox(width: 9),
                Text(option.label),
                const Spacer(),
                Text(
                  option.shortcut,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: option.role.defaultColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (selected != null) {
      widget.onModeChanged(selected);
    }
  }
}

enum _OverlayChatMode {
  say('Say', '', ChatColorRole.say),
  party('Party', '/p ', ChatColorRole.party),
  linkshell('Linkshell', '/l ', ChatColorRole.linkshell),
  tell('Reply', '/r ', ChatColorRole.tell),
  shout('Shout', '/sh ', ChatColorRole.shout),
  yell('Yell', '/y ', ChatColorRole.yell);

  const _OverlayChatMode(this.label, this.prefix, this.role);

  final String label;
  final String prefix;
  final ChatColorRole role;

  String get shortcut => prefix.isEmpty ? 'Say' : prefix.trim();

  static const menuOrder = [yell, shout, tell, linkshell, party, say];
}

class _OverlayMacroGrid extends StatelessWidget {
  const _OverlayMacroGrid({
    required this.status,
    required this.modifier,
    required this.glowingMacroKey,
    required this.glowPulseId,
    required this.glowColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.onMacroPressed,
  });

  final PlayerStatus status;
  final _OverlayMacroModifier modifier;
  final String? glowingMacroKey;
  final int glowPulseId;
  final Color glowColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final Future<void> Function(BuildContext context, int slot, bool needsTarget)
  onMacroPressed;

  @override
  Widget build(BuildContext context) {
    final slots = const <int?>[7, 8, 9, 4, 5, 6, 1, 2, 3, 0, null, null];

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const rows = 4;
        const gap = 5.0;
        final cellWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        final cellHeight = (constraints.maxHeight - (rows - 1) * gap) / rows;
        final aspectRatio = cellHeight <= 0 ? 1.0 : cellWidth / cellHeight;

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final slot = slots[index];
            if (slot == null) {
              return const SizedBox.shrink();
            }

            final slotIndex = _slotIndex(slot);
            final needsTarget = _macroNeedsTargetForSlot(slotIndex);
            final macroKey = '${modifier.commandValue}:$slot';
            return _OverlayMacroButton(
              modifier: modifier,
              slot: slot,
              name: _macroNameForSlot(slotIndex),
              needsTarget: needsTarget,
              glowing: glowingMacroKey == macroKey,
              glowPulseId: glowPulseId,
              glowColor: glowColor,
              buttonColor: buttonColor,
              buttonTextColor: buttonTextColor,
              onPressed: () {
                unawaited(onMacroPressed(context, slot, needsTarget));
              },
            );
          },
        );
      },
    );
  }

  int _slotIndex(int slot) {
    return slot == 0 ? 9 : slot - 1;
  }

  String _macroNameForSlot(int slotIndex) {
    final offset = modifier == _OverlayMacroModifier.alt ? 10 : 0;
    final index = offset + slotIndex;
    if (index >= 0 && index < status.macroNames.length) {
      final name = status.macroNames[index].trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    return '';
  }

  bool _macroNeedsTargetForSlot(int slotIndex) {
    final offset = modifier == _OverlayMacroModifier.alt ? 10 : 0;
    final index = offset + slotIndex;
    return index >= 0 &&
        index < status.macroNeedsTarget.length &&
        status.macroNeedsTarget[index];
  }
}

class _OverlayMacroButton extends StatelessWidget {
  const _OverlayMacroButton({
    required this.modifier,
    required this.slot,
    required this.name,
    required this.needsTarget,
    required this.glowing,
    required this.glowPulseId,
    required this.glowColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.onPressed,
  });

  final _OverlayMacroModifier modifier;
  final int slot;
  final String name;
  final bool needsTarget;
  final bool glowing;
  final int glowPulseId;
  final Color glowColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shortcut = '${modifier.label} + $slot';
    final title = name.trim();
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        TextButton(
          onPressed: onPressed,
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            ),
            minimumSize: const WidgetStatePropertyAll(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: WidgetStatePropertyAll(buttonTextColor),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              final alpha = states.contains(WidgetState.pressed) ? 0.46 : 0.34;
              return Color.alphaBlend(
                buttonColor.withValues(alpha: alpha),
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
              );
            }),
            side: WidgetStatePropertyAll(
              BorderSide(color: Colors.white.withValues(alpha: 0.16)),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    title.isEmpty ? shortcut : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: buttonTextColor,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              if (title.isNotEmpty || needsTarget)
                SizedBox(
                  height: 13,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Flexible(
                          child: Text(
                            shortcut,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 9,
                                  color: buttonTextColor.withValues(
                                    alpha: 0.78,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                          ),
                        ),
                      if (needsTarget) ...[
                        if (title.isNotEmpty) const SizedBox(width: 3),
                        Icon(
                          Icons.group,
                          size: 11,
                          color: Colors.lightBlueAccent.shade400,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (glowing)
          _OverlayMacroEdgeGlowFeedback(
            key: ValueKey(glowPulseId),
            color: glowColor,
            duration: _OverlayMacroTabState._feedbackDuration,
          ),
      ],
    );
  }
}

class _OverlayMacroEdgeGlowFeedback extends StatelessWidget {
  const _OverlayMacroEdgeGlowFeedback({
    super.key,
    required this.color,
    required this.duration,
  });

  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.linear,
          builder: (context, value, child) {
            return CustomPaint(
              painter: _OverlayMacroEdgeGlowPainter(
                progress: value,
                color: color,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverlayMacroEdgeGlowPainter extends CustomPainter {
  const _OverlayMacroEdgeGlowPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(6),
    );
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: 0.34);
    canvas.drawRRect(rrect, basePaint);

    final glowWidth = size.width * 0.56;
    final centerX = -glowWidth + (size.width + glowWidth * 2) * progress;
    final shaderRect = Rect.fromLTWH(
      centerX - glowWidth,
      0,
      glowWidth * 2,
      size.height,
    );
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 1),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(shaderRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect, glowPaint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.78),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(shaderRect);
    canvas.drawRRect(rrect, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayMacroEdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

enum _OverlayMacroModifier {
  ctrl('Ctrl', 'ctrl'),
  alt('Alt', 'alt');

  const _OverlayMacroModifier(this.label, this.commandValue);

  final String label;
  final String commandValue;
}
