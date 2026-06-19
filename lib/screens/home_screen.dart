import 'package:flutter/material.dart';

import '../models/player_status.dart';
import '../services/app_settings_controller.dart';
import '../services/game_status_service.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final GameStatusService _statusService;
  late final Stream<PlayerStatus> _statusStream;

  @override
  void initState() {
    super.initState();
    _statusService = const GameStatusService();
    _statusStream = _statusService.statusStream.asBroadcastStream();
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
            navigationColor: widget.settings.navigationSeedColor,
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
    required this.navigationColor,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool isOledBlack;
  final Color navigationColor;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navigationTextColor = _onColor(navigationColor);
    final navigationScheme =
        ColorScheme.fromSeed(
          seedColor: navigationColor,
          brightness: Theme.of(context).brightness,
        ).copyWith(
          primary: navigationColor,
          onPrimary: navigationTextColor,
          primaryContainer: navigationColor,
          onPrimaryContainer: navigationTextColor,
        );
    final oledBlack =
        Theme.of(context).brightness == Brightness.dark && isOledBlack;
    final railColor = oledBlack
        ? Colors.black
        : Color.alphaBlend(
            navigationScheme.primary.withValues(alpha: 0.16),
            colorScheme.surface,
          );
    final railGradient = oledBlack
        ? null
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                navigationScheme.primary.withValues(alpha: 0.20),
                colorScheme.surface,
              ),
              railColor,
              Color.alphaBlend(
                navigationScheme.primary.withValues(alpha: 0.10),
                colorScheme.surface,
              ),
            ],
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
                  : colorScheme.outlineVariant.withValues(alpha: 0.76),
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
              final buttonHeight = compact
                  ? ((availableHeight - verticalPadding * 2) /
                            _navigationItems.length)
                        .clamp(minButtonHeight, maxButtonHeight)
                        .toDouble()
                  : 68.0;
              final horizontalPadding = iconOnly ? 5.0 : 6.0;
              final contentHeight =
                  buttonHeight * _navigationItems.length + verticalPadding * 2;

              Widget buildNavigationContent({required bool fillHeight}) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: verticalPadding,
                    horizontal: horizontalPadding,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: fillHeight
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < _navigationItems.length;
                        index++
                      )
                        _NavigationButton(
                          item: _navigationItems[index],
                          selected: selectedIndex == index,
                          navigationScheme: navigationScheme,
                          height: buttonHeight,
                          compact: compact,
                          iconOnly: iconOnly,
                          horizontal: false,
                          onTap: () => onDestinationSelected(index),
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

  Color _onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
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
    this.height,
    this.compact = false,
    this.iconOnly = false,
    required this.horizontal,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final ColorScheme navigationScheme;
  final double? height;
  final bool compact;
  final bool iconOnly;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? navigationScheme.onPrimaryContainer
        : colorScheme.onSurface;

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
      child: Icon(
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
        Icon(
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
        Icon(
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
