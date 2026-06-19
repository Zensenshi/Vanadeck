import 'dart:async';

import 'package:flutter/material.dart';

import '../models/party_member.dart';
import '../models/player_status.dart';
import '../services/app_settings_controller.dart';

class MacroScreen extends StatefulWidget {
  const MacroScreen({
    super.key,
    required this.executeCommands,
    this.statusStream,
    this.settings,
  });

  final Future<void> Function(Iterable<String> commands) executeCommands;
  final Stream<PlayerStatus>? statusStream;
  final AppSettingsController? settings;

  @override
  State<MacroScreen> createState() => _MacroScreenState();
}

class _MacroScreenState extends State<MacroScreen> {
  static const _commandPrefix = '__vanadeck_macro_input__:';
  static const _slots = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
  static const _castProgressDuration = Duration(milliseconds: 2200);

  _MacroModifier _modifier = _MacroModifier.ctrl;
  int _pageSlideDirection = 1;
  String? _castingMacroKey;
  Timer? _castTimer;

  @override
  void dispose() {
    _castTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerStatus>(
      stream: widget.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final macroNames = status?.macroNames ?? const [];
        final macroNeedsTarget = status?.macroNeedsTarget ?? const [];
        final castFeedbackStyle =
            widget.settings?.macroCastFeedbackStyle ??
            MacroCastFeedbackStyle.fillBar;
        final castFeedbackColor =
            widget.settings?.macroCastFeedbackColor ??
            AppSettingsController.defaultCastFeedbackColor;
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 36,
            title: Text(
              _titleForStatus(status),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 430;

                      return Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<_MacroModifier>(
                              segments: const [
                                ButtonSegment(
                                  value: _MacroModifier.ctrl,
                                  label: Text('Ctrl'),
                                  icon: Icon(Icons.keyboard_control_key),
                                ),
                                ButtonSegment(
                                  value: _MacroModifier.alt,
                                  label: Text('Alt'),
                                  icon: Icon(Icons.keyboard_option_key),
                                ),
                              ],
                              selected: {_modifier},
                              onSelectionChanged: (selection) {
                                final next = selection.single;
                                if (next == _modifier) {
                                  return;
                                }
                                _setModifier(
                                  next,
                                  slideDirection: next == _MacroModifier.alt
                                      ? 1
                                      : -1,
                                );
                              },
                              showSelectedIcon: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PageStepButton(
                            label: 'Page Up',
                            tooltip: 'Previous in-game macro page',
                            icon: Icons.keyboard_arrow_up,
                            compact: compact,
                            onPressed: () => _sendMacroInput('page_up'),
                          ),
                          const SizedBox(width: 6),
                          _PageStepButton(
                            label: 'Page Down',
                            tooltip: 'Next in-game macro page',
                            icon: Icons.keyboard_arrow_down,
                            compact: compact,
                            onPressed: () => _sendMacroInput('page_down'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: _handlePageSwipe,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = (constraints.maxWidth / 112)
                            .floor()
                            .clamp(2, 5)
                            .toInt();

                        return ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final incoming = child.key == ValueKey(_modifier);
                              final begin = incoming
                                  ? Offset(_pageSlideDirection.toDouble(), 0)
                                  : Offset(-_pageSlideDirection.toDouble(), 0);
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: begin,
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: GridView.builder(
                              key: ValueKey(_modifier),
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisExtent: 72,
                                    mainAxisSpacing: 5,
                                    crossAxisSpacing: 5,
                                  ),
                              itemCount: _slots.length,
                              itemBuilder: (context, index) {
                                final slot = _slots[index];
                                final needsTarget = _macroNeedsTargetForSlot(
                                  macroNeedsTarget,
                                  index,
                                );
                                return _MacroInputTile(
                                  modifier: _modifier,
                                  slot: slot,
                                  name: _macroNameForSlot(macroNames, index),
                                  needsTarget: needsTarget,
                                  casting:
                                      _castingMacroKey ==
                                      _macroKey(_modifier, slot),
                                  castDuration: _castProgressDuration,
                                  castFeedbackStyle: castFeedbackStyle,
                                  castFeedbackColor: castFeedbackColor,
                                  onTap: () => _activateMacroSlot(
                                    slot: slot,
                                    status: status,
                                    needsTarget: needsTarget,
                                  ),
                                  onLongPress: () => _activateMacroSlot(
                                    slot: slot,
                                    status: status,
                                    needsTarget: needsTarget,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                _ActiveTargetPanel(target: status?.activeTarget),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePageSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -220 && _modifier != _MacroModifier.alt) {
      _setModifier(_MacroModifier.alt, slideDirection: 1);
    } else if (velocity > 220 && _modifier != _MacroModifier.ctrl) {
      _setModifier(_MacroModifier.ctrl, slideDirection: -1);
    }
  }

  void _setModifier(_MacroModifier modifier, {required int slideDirection}) {
    setState(() {
      _pageSlideDirection = slideDirection;
      _modifier = modifier;
    });
  }

  Future<void> _sendMacroInput(String action) async {
    try {
      await widget.executeCommands(['$_commandPrefix$action']);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send macro input: $error'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _activateMacroSlot({
    required int slot,
    required PlayerStatus? status,
    required bool needsTarget,
  }) async {
    final action = '${_modifier.commandValue}:$slot';
    if (!needsTarget) {
      await _sendMacroInput(action);
      _startCastProgress(_modifier, slot);
      return;
    }

    final partyMembers = status?.partyMembers ?? const <PartyMember>[];
    if (partyMembers.isEmpty) {
      await _sendMacroInput(action);
      _startCastProgress(_modifier, slot);
      return;
    }

    final targeted = await _showPartyTargetPicker(
      partyMembers,
      modifier: _modifier,
      slot: slot,
    );
    if (targeted == true) {
      _startCastProgress(_modifier, slot);
    }
  }

  Future<bool?> _showPartyTargetPicker(
    List<PartyMember> partyMembers, {
    required _MacroModifier modifier,
    required int slot,
  }) {
    final targets = partyMembers.take(6).toList();

    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _PartyTargetDirectSheet(
          targets: targets,
          modifier: modifier,
          slot: slot,
          sendMacroInput: _sendMacroInput,
        );
      },
    );
  }

  void _startCastProgress(_MacroModifier modifier, int slot) {
    _castTimer?.cancel();
    setState(() {
      _castingMacroKey = _macroKey(modifier, slot);
    });
    _castTimer = Timer(_castProgressDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _castingMacroKey = null;
      });
    });
  }

  String _macroKey(_MacroModifier modifier, int slot) {
    return '${modifier.commandValue}:$slot';
  }

  String _titleForStatus(PlayerStatus? status) {
    if (status == null) {
      return 'Macro Set Book -- #-';
    }

    final book = status.activeMacroBook.clamp(1, 99).toString().padLeft(2, '0');
    final page = status.activeMacroSet.clamp(1, 99);
    return 'Macro Set Book $book #$page';
  }

  String _macroNameForSlot(List<String> macroNames, int slotIndex) {
    final macroIndex = _modifier == _MacroModifier.ctrl
        ? slotIndex
        : slotIndex + _slots.length;
    if (macroIndex >= macroNames.length) {
      return '';
    }

    return macroNames[macroIndex].trim();
  }

  bool _macroNeedsTargetForSlot(List<bool> macroNeedsTarget, int slotIndex) {
    final macroIndex = _modifier == _MacroModifier.ctrl
        ? slotIndex
        : slotIndex + _slots.length;
    return macroIndex < macroNeedsTarget.length && macroNeedsTarget[macroIndex];
  }
}

class _ActiveTargetPanel extends StatelessWidget {
  const _ActiveTargetPanel({required this.target});

  final ActiveTarget? target;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final target = this.target;
    final accent = _accentColor(colorScheme, target);
    final textColor = _onAccentColor(colorScheme, target);
    final label = target == null ? 'No Target' : _kindLabel(target.kind);
    final name = target?.name ?? '--';
    final hpPercent = target?.hpPercent;
    final isParty = target?.isParty ?? false;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        height: isParty ? 58 : 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.18),
          border: Border.all(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isParty && target != null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  children: [
                    Icon(_kindIcon(target.kind), color: textColor, size: 18),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 116,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: textColor.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TargetStatBar(
                            label: 'HP',
                            value: _statText(target.currentHp, target.maxHp),
                            percent: target.partyHpPercent,
                            color: Colors.redAccent.shade400,
                            textColor: textColor,
                          ),
                          const SizedBox(height: 4),
                          _TargetStatBar(
                            label: 'MP',
                            value: _statText(target.currentMp, target.maxMp),
                            percent: target.partyMpPercent,
                            color: Colors.blueAccent.shade200,
                            textColor: textColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (hpPercent != null && hpPercent > 0)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (hpPercent / 100).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          _kindIcon(target?.kind),
                          color: textColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: textColor.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (target?.isMob == true &&
                            hpPercent != null &&
                            hpPercent > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            'HP ${hpPercent.clamp(0, 100).round()}%',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _statText(int? current, int? max) {
    if (current == null || max == null || max <= 0) {
      return '--/--';
    }
    return '$current/$max';
  }

  Color _accentColor(ColorScheme colorScheme, ActiveTarget? target) {
    if (target == null) {
      return colorScheme.outline;
    }
    switch (target.kind) {
      case TargetKind.mob:
        return Colors.redAccent.shade400;
      case TargetKind.party:
        return Colors.lightBlueAccent.shade400;
      case TargetKind.npc:
        return Colors.greenAccent.shade400;
      case TargetKind.unknown:
        return colorScheme.outline;
    }
  }

  Color _onAccentColor(ColorScheme colorScheme, ActiveTarget? target) {
    if (target == null || target.kind == TargetKind.unknown) {
      return colorScheme.onSurface;
    }
    return colorScheme.brightness == Brightness.dark
        ? Colors.white
        : colorScheme.onSurface;
  }

  String _kindLabel(TargetKind kind) {
    switch (kind) {
      case TargetKind.mob:
        return 'MOB';
      case TargetKind.party:
        return 'PARTY';
      case TargetKind.npc:
        return 'NPC';
      case TargetKind.unknown:
        return 'TARGET';
    }
  }

  IconData _kindIcon(TargetKind? kind) {
    switch (kind) {
      case TargetKind.mob:
        return Icons.warning_amber;
      case TargetKind.party:
        return Icons.group;
      case TargetKind.npc:
        return Icons.person_pin_circle;
      case TargetKind.unknown:
      case null:
        return Icons.center_focus_strong;
    }
  }
}

class _TargetStatBar extends StatelessWidget {
  const _TargetStatBar({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String value;
  final double? percent;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 17,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percent ?? 0).clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color.withValues(alpha: 0.66)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyTargetDirectSheet extends StatelessWidget {
  const _PartyTargetDirectSheet({
    required this.targets,
    required this.modifier,
    required this.slot,
    required this.sendMacroInput,
  });

  final List<PartyMember> targets;
  final _MacroModifier modifier;
  final int slot;
  final Future<void> Function(String action) sendMacroInput;

  Future<void> _handleMemberTap(BuildContext context, int index) async {
    await sendMacroInput('targeted:${modifier.commandValue}:$slot:$index');
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: targets.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _PartyTargetRow(
              member: targets[index],
              selectorLabel: '<p$index>',
              selected: false,
              onTap: () => _handleMemberTap(context, index),
            );
          },
        ),
      ),
    );
  }
}

class _PartyTargetRow extends StatelessWidget {
  const _PartyTargetRow({
    required this.member,
    required this.selectorLabel,
    required this.selected,
    required this.onTap,
  });

  final PartyMember member;
  final String selectorLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.20),
                    border: Border.all(color: Colors.lightBlueAccent.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectorLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lv.${member.level} ${member.job}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TargetStatBar(
                        label: 'HP',
                        value: '${member.currentHp}/${member.maxHp}',
                        percent: member.hpPercent,
                        color: Colors.redAccent.shade400,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 4),
                      _TargetStatBar(
                        label: 'MP',
                        value: '${member.currentMp}/${member.maxMp}',
                        percent: member.mpPercent,
                        color: Colors.blueAccent.shade200,
                        textColor: textColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _MacroModifier {
  ctrl('ctrl', 'Ctrl'),
  alt('alt', 'Alt');

  const _MacroModifier(this.commandValue, this.label);

  final String commandValue;
  final String label;
}

class _MacroInputTile extends StatelessWidget {
  const _MacroInputTile({
    required this.modifier,
    required this.slot,
    required this.name,
    required this.needsTarget,
    required this.casting,
    required this.castDuration,
    required this.castFeedbackStyle,
    required this.castFeedbackColor,
    required this.onTap,
    required this.onLongPress,
  });

  final _MacroModifier modifier;
  final int slot;
  final String name;
  final bool needsTarget;
  final bool casting;
  final Duration castDuration;
  final MacroCastFeedbackStyle castFeedbackStyle;
  final Color castFeedbackColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shortcut = '${modifier.label} + $slot';
    final title = name.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.isEmpty ? shortcut : title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              shortcut,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (needsTarget) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.group,
                              size: 13,
                              color: Colors.lightBlueAccent.shade400,
                            ),
                          ],
                        ],
                      ),
                    ] else if (needsTarget) ...[
                      const SizedBox(height: 4),
                      Icon(
                        Icons.group,
                        size: 14,
                        color: Colors.lightBlueAccent.shade400,
                      ),
                    ],
                  ],
                ),
              ),
              if (casting)
                _CastFeedbackOverlay(
                  style: castFeedbackStyle,
                  color: castFeedbackColor,
                  duration: castDuration,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CastFeedbackOverlay extends StatelessWidget {
  const _CastFeedbackOverlay({
    required this.style,
    required this.color,
    required this.duration,
  });

  final MacroCastFeedbackStyle style;
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
            switch (style) {
              case MacroCastFeedbackStyle.fillBar:
                return Align(
                  alignment: Alignment.bottomLeft,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8),
                    ),
                    child: SizedBox(
                      height: 5,
                      width: double.infinity,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: color),
                        ),
                      ),
                    ),
                  ),
                );
              case MacroCastFeedbackStyle.edgeGlow:
                return CustomPaint(
                  painter: _CastEdgeGlowPainter(progress: value, color: color),
                );
            }
          },
        ),
      ),
    );
  }
}

class _CastEdgeGlowPainter extends CustomPainter {
  const _CastEdgeGlowPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    final radius = Radius.circular(8);
    final rrect = RRect.fromRectAndRadius(rect.deflate(2), radius);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color.withValues(alpha: 0.34);
    canvas.drawRRect(rrect, basePaint);

    final glowWidth = size.width * 0.48;
    final centerX = -glowWidth + (size.width + glowWidth * 2) * progress;
    final shaderRect = Rect.fromLTWH(
      centerX - glowWidth,
      0,
      glowWidth * 2,
      size.height,
    );
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 1),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(shaderRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawRRect(rrect, glowPaint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
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
  bool shouldRepaint(covariant _CastEdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _PageStepButton extends StatelessWidget {
  const _PageStepButton({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: tooltip,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            minimumSize: const Size(42, 42),
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
