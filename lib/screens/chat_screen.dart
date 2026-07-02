import 'dart:async';

import 'package:flutter/material.dart';

import '../models/player_status.dart';
import '../services/app_settings_controller.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.statusStream,
    required this.sendChatMessage,
    required this.settings,
  });

  final Stream<PlayerStatus> statusStream;
  final Future<void> Function(String message) sendChatMessage;
  final AppSettingsController settings;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _sendCooldown = Duration(seconds: 2);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_LocalChatMessage> _localMessages = [];
  bool _isSending = false;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _cooldownTimer;

  List<ChatMessage>? _lastRemoteMessages;
  List<ChatMessage> _sortedRemoteMessages = const [];

  bool get _isCoolingDown => _cooldownRemaining > Duration.zero;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        final font = _ChatFontSpec.fromKey(widget.settings.chatFontFamily);
        final colors = _ChatSurfaceColors.forSettings(context, widget.settings);
        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focusComposer,
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<PlayerStatus>(
                      stream: widget.statusStream,
                      builder: (context, snapshot) {
                        final remoteMessages =
                            snapshot.data?.chatMessages
                                .where(
                                  (message) =>
                                      message.direction !=
                                      ChatMessageDirection.outgoing,
                                )
                                .toList() ??
                            const <ChatMessage>[];
                        if (!identical(remoteMessages, _lastRemoteMessages)) {
                          _lastRemoteMessages = remoteMessages;
                          _sortedRemoteMessages = List.of(remoteMessages)
                            ..sort((a, b) {
                              final compared = a.receivedAt.compareTo(
                                b.receivedAt,
                              );
                              if (compared != 0) {
                                return compared;
                              }
                              return (a.id ?? 0).compareTo(b.id ?? 0);
                            });
                        }
                        final messages = [
                          ..._sortedRemoteMessages,
                          ..._localMessages.map(
                            (message) => ChatMessage(
                              text: message.text,
                              mode: -1,
                              receivedAt: message.sentAt,
                            ),
                          ),
                        ];
                        final shouldFollowNewMessages = _isNearBottom();

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_scrollController.hasClients ||
                              !shouldFollowNewMessages) {
                            return;
                          }
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                          );
                        });

                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'No chat yet',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colors.mutedText,
                                    fontFamily: font.family,
                                    fontFamilyFallback: font.fallbacks,
                                    fontSize: widget.settings.chatFontSize,
                                  ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return _ChatMessageRow(
                              message: message,
                              font: font,
                              fontSize: widget.settings.chatFontSize,
                              settings: widget.settings,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _ChatComposer(
                    controller: _controller,
                    focusNode: _focusNode,
                    sendEnabled: !_isSending && !_isCoolingDown,
                    cooldownRemaining: _cooldownRemaining,
                    onSend: _sendMessage,
                    settings: widget.settings,
                    font: font,
                    fontSize: widget.settings.chatFontSize,
                    colors: colors,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isSending || _isCoolingDown) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.sendChatMessage(message);
      if (!mounted) {
        return;
      }
      _controller.clear();
      _startCooldown();
      _focusNode.requestFocus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _localMessages.add(
          _LocalChatMessage(
            text: 'Could not send: $error',
            sentAt: DateTime.now(),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _focusComposer() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownRemaining = _sendCooldown;
    });

    _cooldownTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nextRemaining =
          _cooldownRemaining - const Duration(milliseconds: 250);
      if (nextRemaining <= Duration.zero) {
        timer.cancel();
        setState(() {
          _cooldownRemaining = Duration.zero;
        });
        return;
      }

      setState(() {
        _cooldownRemaining = nextRemaining;
      });
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 48;
  }
}

class _ChatFontSpec {
  const _ChatFontSpec({required this.family, required this.fallbacks});

  final String? family;
  final List<String>? fallbacks;

  static _ChatFontSpec fromKey(String key) {
    return switch (key) {
      'sans-serif-medium' => const _ChatFontSpec(
        family: 'sans-serif-medium',
        fallbacks: _japaneseSansFallbacks,
      ),
      'sans-serif-condensed' => const _ChatFontSpec(
        family: 'sans-serif-condensed',
        fallbacks: _japaneseSansFallbacks,
      ),
      'monospace' => const _ChatFontSpec(
        family: 'monospace',
        fallbacks: _japaneseMonospaceFallbacks,
      ),
      'serif' => const _ChatFontSpec(
        family: 'serif',
        fallbacks: _japaneseSerifFallbacks,
      ),
      'casual' => const _ChatFontSpec(
        family: 'casual',
        fallbacks: _japaneseSansFallbacks,
      ),
      'jp-sans' => const _ChatFontSpec(
        family: 'sans-serif',
        fallbacks: _japaneseSansFallbacks,
      ),
      'jp-gothic' => const _ChatFontSpec(
        family: 'Droid Sans Japanese',
        fallbacks: _japaneseSansFallbacks,
      ),
      'jp-serif' => const _ChatFontSpec(
        family: 'Noto Serif CJK JP',
        fallbacks: _japaneseSerifFallbacks,
      ),
      'jp-mincho' => const _ChatFontSpec(
        family: 'Noto Serif JP',
        fallbacks: _japaneseSerifFallbacks,
      ),
      _ => const _ChatFontSpec(
        family: 'sans-serif',
        fallbacks: _japaneseSansFallbacks,
      ),
    };
  }

  static const _japaneseSansFallbacks = [
    'NotoSansCJKjp',
    'Noto Sans CJK JP',
    'Noto Sans CJK JP Regular',
    'Noto Sans JP',
    'MotoyaLMaru',
    'Droid Sans Japanese',
    'sans-serif',
  ];

  static const _japaneseSerifFallbacks = [
    'Noto Serif CJK JP',
    'Noto Serif JP',
    'serif',
  ];

  static const _japaneseMonospaceFallbacks = [
    'Noto Sans Mono CJK JP',
    'Noto Sans Mono',
    'monospace',
    'Noto Sans CJK JP',
  ];
}

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.sendEnabled,
    required this.cooldownRemaining,
    required this.onSend,
    required this.settings,
    required this.font,
    required this.fontSize,
    required this.colors,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sendEnabled;
  final Duration cooldownRemaining;
  final VoidCallback onSend;
  final AppSettingsController settings;
  final _ChatFontSpec font;
  final double fontSize;
  final _ChatSurfaceColors colors;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  static const _chatModeHoldDelay = Duration(milliseconds: 360);
  static const _chatModeMenuItemHeight = 44.0;
  static const _chatModeMenuPadding = 6.0;
  static const _chatModeMenuGap = 10.0;
  static const _chatModeMenuWidth = 220.0;
  static const _chatModeOptions = [
    _ChatModeOption(label: 'Yell', prefix: '/y ', role: ChatColorRole.yell),
    _ChatModeOption(label: 'Shout', prefix: '/sh ', role: ChatColorRole.shout),
    _ChatModeOption(label: 'Reply', prefix: '/r ', role: ChatColorRole.tell),
    _ChatModeOption(
      label: 'Linkshell',
      prefix: '/l ',
      role: ChatColorRole.linkshell,
    ),
    _ChatModeOption(label: 'Party', prefix: '/p ', role: ChatColorRole.party),
    _ChatModeOption(label: 'Say', prefix: '', role: ChatColorRole.say),
  ];

  Timer? _chatModeTimer;
  OverlayEntry? _chatModeOverlay;
  Rect? _chatModeMenuRect;
  Offset? _chatModePointer;
  int? _hoveredChatModeIndex;

  @override
  void dispose() {
    _chatModeTimer?.cancel();
    _removeChatModeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cooldownSeconds = (widget.cooldownRemaining.inMilliseconds / 1000)
        .ceil();

    void backspace() {
      final text = widget.controller.text;
      if (text.isEmpty) {
        widget.focusNode.requestFocus();
        return;
      }

      final selection = widget.controller.selection;
      final start = selection.start;
      final end = selection.end;
      if (selection.isValid && !selection.isCollapsed) {
        widget.controller.value = TextEditingValue(
          text: text.replaceRange(start, end, ''),
          selection: TextSelection.collapsed(offset: start),
        );
        widget.focusNode.requestFocus();
        return;
      }

      final cursor = selection.isValid ? selection.baseOffset : text.length;
      final safeCursor = cursor.clamp(0, text.length).toInt();
      if (safeCursor <= 0) {
        widget.focusNode.requestFocus();
        return;
      }

      widget.controller.value = TextEditingValue(
        text: text.replaceRange(safeCursor - 1, safeCursor, ''),
        selection: TextSelection.collapsed(offset: safeCursor - 1),
      );
      widget.focusNode.requestFocus();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: widget.colors.composer,
        border: Border(top: BorderSide(color: widget.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: Listener(
                  onPointerDown: _handleChatModePointerDown,
                  onPointerMove: _handleChatModePointerMove,
                  onPointerUp: _handleChatModePointerUp,
                  onPointerCancel: _handleChatModePointerCancel,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 3,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableInteractiveSelection: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: TextStyle(
                      fontFamily: widget.font.family,
                      fontFamilyFallback: widget.font.fallbacks,
                      fontSize: widget.fontSize,
                      height: 1.25,
                      color: widget.colors.inputText,
                    ),
                    strutStyle: StrutStyle(
                      fontFamily: widget.font.family,
                      fontFamilyFallback: widget.font.fallbacks,
                      fontSize: widget.fontSize,
                      height: 1.25,
                      forceStrutHeight: true,
                    ),
                    cursorColor: widget.colors.inputText,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      hintStyle: TextStyle(color: widget.colors.hintText),
                      filled: true,
                      fillColor: widget.colors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      constraints: const BoxConstraints(minHeight: 48),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: widget.colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: widget.colors.focusBorder,
                        ),
                      ),
                      isDense: false,
                    ),
                    onTap: () => widget.focusNode.requestFocus(),
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Backspace',
                onPressed: backspace,
                icon: const Icon(Icons.backspace_outlined),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: widget.sendEnabled ? widget.onSend : null,
                icon: widget.sendEnabled
                    ? const Icon(Icons.send)
                    : const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
            ],
          ),
          if (cooldownSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 4),
              child: Text(
                'Ready in ${cooldownSeconds}s',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: widget.colors.mutedText,
                  fontFamily: widget.font.family,
                  fontFamilyFallback: widget.font.fallbacks,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleChatModePointerDown(PointerDownEvent event) {
    _chatModeTimer?.cancel();
    _chatModePointer = event.position;
    _chatModeTimer = Timer(_chatModeHoldDelay, () {
      final pointer = _chatModePointer ?? event.position;
      _showChatModeMenu(pointer);
    });
  }

  void _handleChatModePointerMove(PointerMoveEvent event) {
    _chatModePointer = event.position;
    if (_chatModeOverlay != null) {
      _updateHoveredChatMode(event.position);
    }
  }

  void _handleChatModePointerUp(PointerUpEvent event) {
    _chatModeTimer?.cancel();
    if (_chatModeOverlay == null) {
      return;
    }

    _updateHoveredChatMode(event.position);
    final selectedIndex = _hoveredChatModeIndex;
    final selectedOption = selectedIndex == null
        ? null
        : _chatModeOptions[selectedIndex];
    _removeChatModeMenu();
    if (selectedOption != null) {
      _applyChatMode(selectedOption);
    }
  }

  void _handleChatModePointerCancel(PointerCancelEvent event) {
    _chatModeTimer?.cancel();
    _removeChatModeMenu();
  }

  void _showChatModeMenu(Offset pointer) {
    if (!mounted || _chatModeOverlay != null) {
      return;
    }

    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null || overlayBox == null || !overlayBox.hasSize) {
      return;
    }

    final overlaySize = overlayBox.size;
    final menuHeight =
        (_chatModeOptions.length * _chatModeMenuItemHeight) +
        (_chatModeMenuPadding * 2);
    final menuWidth = overlaySize.width < (_chatModeMenuWidth + 16)
        ? overlaySize.width - 16
        : _chatModeMenuWidth;
    final left = (pointer.dx - (menuWidth / 2))
        .clamp(8.0, overlaySize.width - menuWidth - 8)
        .toDouble();
    final top = (pointer.dy - menuHeight - _chatModeMenuGap)
        .clamp(8.0, overlaySize.height - menuHeight - 8)
        .toDouble();

    _chatModeMenuRect = Rect.fromLTWH(left, top, menuWidth, menuHeight);
    _updateHoveredChatMode(_chatModePointer ?? pointer);
    _chatModeOverlay = OverlayEntry(
      builder: (context) {
        final rect = _chatModeMenuRect;
        if (rect == null) {
          return const SizedBox.shrink();
        }

        return _ChatModeMenu(
          rect: rect,
          options: _chatModeOptions,
          highlightedIndex: _hoveredChatModeIndex,
          settings: widget.settings,
          colors: widget.colors,
          font: widget.font,
        );
      },
    );
    overlay.insert(_chatModeOverlay!);
  }

  void _updateHoveredChatMode(Offset pointer) {
    final nextIndex = _chatModeIndexForPointer(pointer);
    if (nextIndex == _hoveredChatModeIndex) {
      return;
    }

    _hoveredChatModeIndex = nextIndex;
    _chatModeOverlay?.markNeedsBuild();
  }

  int? _chatModeIndexForPointer(Offset pointer) {
    final rect = _chatModeMenuRect;
    if (rect == null || !rect.contains(pointer)) {
      return null;
    }

    final localY = pointer.dy - rect.top - _chatModeMenuPadding;
    if (localY < 0 ||
        localY >= _chatModeOptions.length * _chatModeMenuItemHeight) {
      return null;
    }
    return (localY / _chatModeMenuItemHeight).floor();
  }

  void _applyChatMode(_ChatModeOption option) {
    final body = _stripChatModePrefix(widget.controller.text).trimLeft();
    final nextText = '${option.prefix}$body';
    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    widget.focusNode.requestFocus();
  }

  String _stripChatModePrefix(String text) {
    final normalized = text.toLowerCase();
    for (final option in _chatModeOptions) {
      final prefix = option.prefix;
      if (prefix.isNotEmpty && normalized.startsWith(prefix)) {
        return text.substring(prefix.length);
      }
    }
    return text;
  }

  void _removeChatModeMenu() {
    _chatModeOverlay?.remove();
    _chatModeOverlay = null;
    _chatModeMenuRect = null;
    _hoveredChatModeIndex = null;
  }
}

class _ChatModeOption {
  const _ChatModeOption({
    required this.label,
    required this.prefix,
    required this.role,
  });

  final String label;
  final String prefix;
  final ChatColorRole role;

  String get shortcut => prefix.isEmpty ? 'Say' : prefix.trim();
}

class _ChatModeMenu extends StatelessWidget {
  const _ChatModeMenu({
    required this.rect,
    required this.options,
    required this.highlightedIndex,
    required this.settings,
    required this.colors,
    required this.font,
  });

  final Rect rect;
  final List<_ChatModeOption> options;
  final int? highlightedIndex;
  final AppSettingsController settings;
  final _ChatSurfaceColors colors;
  final _ChatFontSpec font;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.inputFill.withValues(alpha: 0.96),
            border: Border.all(color: colors.focusBorder),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _ChatComposerState._chatModeMenuPadding,
            ),
            child: Column(
              children: [
                for (var index = 0; index < options.length; index += 1)
                  _ChatModeMenuItem(
                    option: options[index],
                    color: settings.chatColor(options[index].role),
                    highlighted: index == highlightedIndex,
                    font: font,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatModeMenuItem extends StatelessWidget {
  const _ChatModeMenuItem({
    required this.option,
    required this.color,
    required this.highlighted,
    required this.font,
  });

  final _ChatModeOption option;
  final Color color;
  final bool highlighted;
  final _ChatFontSpec font;

  @override
  Widget build(BuildContext context) {
    final labelColor = _FfxiChatStyle.contrastLabelColor(color);
    final backgroundColor = highlighted
        ? color.withValues(alpha: 0.22)
        : Colors.transparent;

    return Container(
      height: _ChatComposerState._chatModeMenuItemHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: backgroundColor,
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              option.shortcut,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontFamily: font.family,
                fontFamilyFallback: font.fallbacks,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              option.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                fontFamily: font.family,
                fontFamilyFallback: font.fallbacks,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageRow extends StatelessWidget {
  const _ChatMessageRow({
    required this.message,
    required this.font,
    required this.fontSize,
    required this.settings,
  });

  final ChatMessage message;
  final _ChatFontSpec font;
  final double fontSize;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final isError = message.mode < 0;
    final style = _FfxiChatStyle.fromMessage(message, settings);
    final channel = isError ? 'Error' : null;
    final messageColor = message.blocked
        ? style.color.withValues(alpha: 0.58)
        : style.color;
    final textStyle =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: messageColor,
          fontFamily: font.family,
          fontFamilyFallback: font.fallbacks,
          fontSize: fontSize,
        );
    final labelStyle =
        (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: style.labelColor.withValues(
            alpha: message.blocked ? 0.58 : 0.9,
          ),
          fontWeight: FontWeight.w700,
          fontFamily: font.family,
          fontFamilyFallback: font.fallbacks,
          fontSize: (fontSize - 2).clamp(9, 20).toDouble(),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text.rich(
        TextSpan(
          style: textStyle,
          children: [
            if (channel != null)
              TextSpan(text: '[$channel] ', style: labelStyle),
            TextSpan(text: message.text),
          ],
        ),
        locale: const Locale.fromSubtags(
          languageCode: 'ja',
          scriptCode: 'Jpan',
          countryCode: 'JP',
        ),
      ),
    );
  }
}

class _ChatSurfaceColors {
  const _ChatSurfaceColors({
    required this.background,
    required this.composer,
    required this.inputFill,
    required this.border,
    required this.focusBorder,
    required this.inputText,
    required this.hintText,
    required this.mutedText,
  });

  final Color background;
  final Color composer;
  final Color inputFill;
  final Color border;
  final Color focusBorder;
  final Color inputText;
  final Color hintText;
  final Color mutedText;

  static const standard = _ChatSurfaceColors(
    background: Color(0xFF101614),
    composer: Color(0xFF151D1A),
    inputFill: Color(0xFF0C1110),
    border: Color(0xFF33423D),
    focusBorder: Color(0xFF7EA797),
    inputText: Color(0xFFEDE8D8),
    hintText: Color(0xFF87938E),
    mutedText: Color(0xFF9CA8A3),
  );

  static const oledBlack = _ChatSurfaceColors(
    background: Colors.black,
    composer: Colors.black,
    inputFill: Colors.black,
    border: Color(0xFF2D363B),
    focusBorder: Color(0xFFA7B2B7),
    inputText: Color(0xFFEDE8D8),
    hintText: Color(0xFF87938E),
    mutedText: Color(0xFF9CA8A3),
  );

  static _ChatSurfaceColors forSettings(
    BuildContext context,
    AppSettingsController settings,
  ) {
    final oled =
        Theme.of(context).brightness == Brightness.dark && settings.isOledBlack;
    return oled ? oledBlack : standard;
  }
}

class _FfxiChatStyle {
  const _FfxiChatStyle({
    required this.color,
    required this.labelColor,
    this.label,
  });

  final Color color;
  final Color labelColor;
  final String? label;

  static _FfxiChatStyle fromMessage(
    ChatMessage message,
    AppSettingsController settings,
  ) {
    if (message.mode < 0) {
      return const _FfxiChatStyle(
        label: 'Error',
        color: Color(0xFFFF8A80),
        labelColor: Color(0xFFFF8A80),
      );
    }

    _FfxiChatStyle channel(String label, ChatColorRole role) {
      final color = settings.chatColor(role);
      return _FfxiChatStyle(
        label: label,
        color: color,
        labelColor: contrastLabelColor(color),
      );
    }

    final role = _roleForMode(message.mode);
    if (role != null) {
      return channel(role.label, role);
    }

    final textRole = _roleForText(message.text);
    if (textRole != null) {
      return channel(textRole.label, textRole);
    }

    final gameColor = _eventColor(message.colorArgb);
    if (gameColor != null) {
      return _FfxiChatStyle(
        color: gameColor,
        labelColor: contrastLabelColor(gameColor),
      );
    }

    return channel(ChatColorRole.message.label, ChatColorRole.message);
  }

  static Color? _eventColor(int? colorArgb) {
    if (colorArgb == null || colorArgb == 0) {
      return null;
    }
    return Color(colorArgb.toUnsigned(32));
  }

  static ChatColorRole? _roleForMode(int mode) {
    return switch (mode) {
      1 || 9 => ChatColorRole.say,
      10 => ChatColorRole.shout,
      11 => ChatColorRole.yell,
      3 || 12 => ChatColorRole.tell,
      4 || 5 || 13 => ChatColorRole.party,
      14 => ChatColorRole.linkshell,
      6 || 15 => ChatColorRole.emote,
      36 ||
      37 ||
      44 ||
      121 ||
      122 ||
      142 ||
      144 ||
      146 ||
      148 ||
      151 ||
      152 => ChatColorRole.message,
      150 => ChatColorRole.npc,
      212 => ChatColorRole.unity,
      214 => ChatColorRole.linkshellTwo,
      220 => ChatColorRole.assistJ,
      222 => ChatColorRole.assistE,
      _ => null,
    };
  }

  static ChatColorRole? _roleForText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('>>') || normalized.contains('<<')) {
      return ChatColorRole.tell;
    }
    if (normalized.startsWith('(party)') || normalized.startsWith('[party]')) {
      return ChatColorRole.party;
    }
    if (normalized.startsWith('(linkshell2)') ||
        normalized.startsWith('[linkshell2]') ||
        normalized.startsWith('(ls2)') ||
        normalized.startsWith('[ls2]')) {
      return ChatColorRole.linkshellTwo;
    }
    if (normalized.startsWith('(linkshell)') ||
        normalized.startsWith('[linkshell]') ||
        normalized.startsWith('(ls)') ||
        normalized.startsWith('[ls]')) {
      return ChatColorRole.linkshell;
    }
    if (normalized.startsWith('(unity)') || normalized.startsWith('[unity]')) {
      return ChatColorRole.unity;
    }
    if (normalized.startsWith('(assistj)') ||
        normalized.startsWith('[assistj]') ||
        normalized.startsWith('(assist j)') ||
        normalized.startsWith('[assist j]')) {
      return ChatColorRole.assistJ;
    }
    if (normalized.startsWith('(assiste)') ||
        normalized.startsWith('[assiste]') ||
        normalized.startsWith('(assist e)') ||
        normalized.startsWith('[assist e]')) {
      return ChatColorRole.assistE;
    }
    if (normalized.startsWith('*') || normalized.startsWith('/em ')) {
      return ChatColorRole.emote;
    }
    if (normalized.contains(' shouts')) {
      return ChatColorRole.shout;
    }
    if (normalized.contains(' yells')) {
      return ChatColorRole.yell;
    }
    if (normalized.contains(' says')) {
      return ChatColorRole.say;
    }
    return null;
  }

  static Color contrastLabelColor(Color color) {
    final target =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Color.lerp(color, target, 0.22) ?? color;
  }
}

class _LocalChatMessage {
  const _LocalChatMessage({required this.text, required this.sentAt});

  final String text;
  final DateTime sentAt;
}
