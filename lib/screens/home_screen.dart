import 'package:flutter/material.dart';

import '../models/player_status.dart';
import '../services/app_settings_controller.dart';
import '../services/game_status_service.dart';
import '../services/overlay_mode_controller.dart';
import 'chat_screen.dart';
import 'macro_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late final GameStatusService _statusService;
  late final Stream<PlayerStatus> _statusStream;
  final _overlayMode = const OverlayModeController();
  OverlayModeStatus _overlayStatus = OverlayModeStatus.unknown;
  bool _overlayBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusService = const GameStatusService();
    _statusStream = _statusService.statusStream.asBroadcastStream();
    _refreshOverlayStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOverlayStatus();
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
  }

  Future<void> _toggleOverlayMode() async {
    if (_overlayBusy) {
      return;
    }

    setState(() {
      _overlayBusy = true;
    });

    try {
      final result = await _overlayMode.toggle(widget.settings);
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
    final screens = [
      StatusScreen(statusStream: _statusStream, settings: widget.settings),
      MapScreen(statusStream: _statusStream),
      MacroScreen(
        executeCommands: _statusService.sendCommands,
        statusStream: _statusStream,
        settings: widget.settings,
      ),
      ChatScreen(
        statusStream: _statusStream,
        sendChatMessage: _statusService.sendChatMessage,
        settings: widget.settings,
      ),
      SettingsScreen(settings: widget.settings),
    ];

    void selectDestination(int index) {
      setState(() {
        _selectedIndex = index;
      });
    }

    return Scaffold(
      body: Row(
        children: [
          _SideNavigation(
            selectedIndex: _selectedIndex,
            isOledBlack: widget.settings.isOledBlack,
            iconBarColors: widget.settings.iconBarColors,
            iconBarColorStyle: widget.settings.iconBarColorStyle,
            buttonColor: widget.settings.buttonColor,
            buttonTextColor: widget.settings.buttonTextColor,
            overlayRunning: _overlayStatus.running,
            overlayBusy: _overlayBusy,
            onOverlayPressed: _toggleOverlayMode,
            onDestinationSelected: selectDestination,
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: screens),
          ),
        ],
      ),
    );
  }
}

const _navigationItems = [
  _NavigationItem(
    label: 'Status',
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
  ),
  _NavigationItem(
    label: 'Map',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  _NavigationItem(
    label: 'Macros',
    icon: Icons.keyboard_command_key_outlined,
    selectedIcon: Icons.keyboard_command_key,
  ),
  _NavigationItem(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
  ),
  _NavigationItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selectedIndex,
    required this.isOledBlack,
    required this.iconBarColors,
    required this.iconBarColorStyle,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.overlayRunning,
    required this.overlayBusy,
    required this.onOverlayPressed,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool isOledBlack;
  final SurfaceGradientColors iconBarColors;
  final ColorFillStyle iconBarColorStyle;
  final Color buttonColor;
  final Color buttonTextColor;
  final bool overlayRunning;
  final bool overlayBusy;
  final VoidCallback onOverlayPressed;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navigationScheme =
        ColorScheme.fromSeed(
          seedColor: buttonColor,
          brightness: Theme.of(context).brightness,
        ).copyWith(
          primary: buttonColor,
          onPrimary: buttonTextColor,
          primaryContainer: buttonColor,
          onPrimaryContainer: buttonTextColor,
        );
    final oledBlack =
        Theme.of(context).brightness == Brightness.dark && isOledBlack;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final railTintAlpha = dark ? 0.16 : 0.30;
    final railColor = oledBlack
        ? Colors.black
        : iconBarColors.iconBarColor(
            style: iconBarColorStyle,
            baseColor: Color.alphaBlend(
              iconBarColors.start.withValues(alpha: railTintAlpha),
              colorScheme.surface,
            ),
          );
    final railGradient = oledBlack
        ? null
        : iconBarColors.iconBarGradient(
            style: iconBarColorStyle,
            baseColor: railColor,
            vertical: true,
          );

    return SafeArea(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: railColor,
          gradient: railGradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: oledBlack ? 0.42 : 0.18),
              blurRadius: 18,
              offset: const Offset(4, 0),
            ),
          ],
          border: Border(
            right: BorderSide(
              color: oledBlack
                  ? const Color(0xFF2D363B)
                  : Color.alphaBlend(
                      iconBarColors.start.withValues(alpha: dark ? 0.16 : 0.28),
                      colorScheme.outlineVariant,
                    ),
            ),
          ),
        ),
        child: SizedBox(
          width: 78,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 520.0;
              final keyboardVisible =
                  MediaQuery.of(context).viewInsets.bottom > 0;
              final compact = keyboardVisible && availableHeight < 500;
              final iconOnly = keyboardVisible && availableHeight < 300;
              final verticalPadding = compact
                  ? iconOnly
                        ? 3.0
                        : 6.0
                  : 18.0;
              final maxButtonHeight = compact ? 52.0 : 68.0;
              final minButtonHeight = compact
                  ? iconOnly
                        ? 28.0
                        : 44.0
                  : 64.0;
              final overlayButtonHeight = compact
                  ? iconOnly
                        ? 30.0
                        : 44.0
                  : 54.0;
              final buttonHeight = compact
                  ? ((availableHeight - verticalPadding * 2) /
                            _navigationItems.length)
                        .clamp(minButtonHeight, maxButtonHeight)
                        .toDouble()
                  : 68.0;
              final horizontalPadding = iconOnly ? 5.0 : 6.0;
              final contentHeight =
                  buttonHeight * _navigationItems.length +
                  overlayButtonHeight +
                  8 +
                  verticalPadding * 2;

              Widget buildNavigationContent({required bool fillHeight}) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: verticalPadding,
                    horizontal: horizontalPadding,
                  ),
                  child: Column(
                    mainAxisSize: fillHeight
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    children: [
                      if (fillHeight)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _navigationButtons(
                              navigationScheme: navigationScheme,
                              buttonTextColor: buttonTextColor,
                              buttonHeight: buttonHeight,
                              compact: compact,
                              iconOnly: iconOnly,
                            ),
                          ),
                        )
                      else
                        ..._navigationButtons(
                          navigationScheme: navigationScheme,
                          buttonTextColor: buttonTextColor,
                          buttonHeight: buttonHeight,
                          compact: compact,
                          iconOnly: iconOnly,
                        ),
                      const SizedBox(height: 8),
                      _NavigationButton(
                        item: _NavigationItem(
                          label: overlayRunning ? 'Stop' : 'Overlay',
                          icon: overlayRunning
                              ? Icons.close_fullscreen
                              : Icons.picture_in_picture_alt_outlined,
                          selectedIcon: overlayRunning
                              ? Icons.close_fullscreen
                              : Icons.picture_in_picture_alt,
                        ),
                        selected: overlayRunning,
                        navigationScheme: navigationScheme,
                        buttonTextColor: buttonTextColor,
                        height: overlayButtonHeight,
                        compact: compact,
                        iconOnly: iconOnly,
                        horizontal: false,
                        busy: overlayBusy,
                        onTap: onOverlayPressed,
                      ),
                    ],
                  ),
                );
              }

              if (contentHeight <= availableHeight) {
                return buildNavigationContent(fillHeight: true);
              }

              return SingleChildScrollView(
                child: buildNavigationContent(fillHeight: false),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _navigationButtons({
    required ColorScheme navigationScheme,
    required Color buttonTextColor,
    required double buttonHeight,
    required bool compact,
    required bool iconOnly,
  }) {
    return [
      for (var index = 0; index < _navigationItems.length; index++)
        _NavigationButton(
          item: _navigationItems[index],
          selected: selectedIndex == index,
          navigationScheme: navigationScheme,
          buttonTextColor: buttonTextColor,
          height: buttonHeight,
          compact: compact,
          iconOnly: iconOnly,
          horizontal: false,
          onTap: () => onDestinationSelected(index),
        ),
    ];
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.selected,
    required this.navigationScheme,
    required this.buttonTextColor,
    this.height,
    this.compact = false,
    this.iconOnly = false,
    this.busy = false,
    required this.horizontal,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final ColorScheme navigationScheme;
  final Color buttonTextColor;
  final double? height;
  final bool compact;
  final bool iconOnly;
  final bool busy;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? navigationScheme.onPrimaryContainer
        : buttonTextColor.withValues(alpha: 0.82);

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: selected ? navigationScheme.primaryContainer : null,
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      navigationScheme.primaryContainer,
                      Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.10),
                        navigationScheme.primaryContainer,
                      ),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: iconOnly
              ? _iconOnlyContent(foreground)
              : horizontal
              ? _horizontalContent(context, foreground)
              : _verticalContent(context, foreground),
        ),
      ),
    );
  }

  Widget _iconOnlyContent(Color foreground) {
    return Center(
      child: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : Icon(
              selected ? item.selectedIcon : item.icon,
              color: foreground,
              size: 21,
            ),
    );
  }

  Widget _horizontalContent(BuildContext context, Color foreground) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        busy
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(
                selected ? item.selectedIcon : item.icon,
                color: foreground,
                size: 22,
              ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _verticalContent(BuildContext context, Color foreground) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        busy
            ? SizedBox.square(
                dimension: compact ? 17 : 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(
                selected ? item.selectedIcon : item.icon,
                color: foreground,
                size: compact ? 21 : 23,
              ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontSize: compact ? 10 : null,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
