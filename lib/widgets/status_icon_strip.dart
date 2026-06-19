import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/status_effect.dart';
import '../services/app_settings_controller.dart';

class StatusIconStrip extends StatelessWidget {
  const StatusIconStrip({
    super.key,
    required this.buffs,
    required this.settings,
    this.compact = false,
  });

  final List<PlayerBuff> buffs;
  final AppSettingsController settings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (buffs.isEmpty) {
      return const SizedBox.shrink();
    }

    final dimension = compact ? 28.0 : 34.0;
    return SizedBox(
      height: dimension,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: buffs.length,
        separatorBuilder: (context, index) => SizedBox(width: compact ? 5 : 8),
        itemBuilder: (context, index) => StatusIcon(
          buff: buffs[index],
          settings: settings,
          dimension: dimension,
          imageSize: compact ? 22 : 24,
        ),
      ),
    );
  }
}

class StatusIcon extends StatelessWidget {
  const StatusIcon({
    super.key,
    required this.buff,
    required this.settings,
    this.dimension = 34,
    this.imageSize = 24,
  });

  final PlayerBuff buff;
  final AppSettingsController settings;
  final double dimension;
  final double imageSize;

  static const _palettes = [
    _BuffColors(
      background: Color(0xFF23362F),
      border: Color(0xFF69B58F),
      icon: Color(0xFF9BE4BD),
    ),
    _BuffColors(
      background: Color(0xFF342C20),
      border: Color(0xFFD6A753),
      icon: Color(0xFFFFD479),
    ),
    _BuffColors(
      background: Color(0xFF2A2F42),
      border: Color(0xFF7E9DEB),
      icon: Color(0xFFAFC3FF),
    ),
    _BuffColors(
      background: Color(0xFF3A2530),
      border: Color(0xFFD47799),
      icon: Color(0xFFFFA6C0),
    ),
    _BuffColors(
      background: Color(0xFF24343B),
      border: Color(0xFF62B7C9),
      icon: Color(0xFF9DE8F4),
    ),
  ];

  static const _icons = [
    Icons.auto_awesome,
    Icons.shield_outlined,
    Icons.flash_on_outlined,
    Icons.local_fire_department_outlined,
    Icons.water_drop_outlined,
    Icons.air_outlined,
    Icons.favorite_border,
    Icons.visibility_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final iconId = buff.displayIconId;
    final colors = _buffColors(iconId);

    return Tooltip(
      message: buff.tooltipText,
      triggerMode: TooltipTriggerMode.longPress,
      child: Semantics(
        label: buff.tooltipText,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox.square(
            dimension: dimension,
            child: Center(
              child: _StatusIconImage(
                id: iconId,
                settings: settings,
                size: imageSize,
                fallback: Icon(
                  _fallbackIcon(iconId),
                  color: colors.icon,
                  size: 19,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _BuffColors _buffColors(int id) {
    return _palettes[id % _palettes.length];
  }

  IconData _fallbackIcon(int id) {
    return _icons[id % _icons.length];
  }
}

class _StatusIconImage extends StatelessWidget {
  const _StatusIconImage({
    required this.id,
    required this.settings,
    required this.size,
    required this.fallback,
  });

  final int id;
  final AppSettingsController settings;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: settings.loadStatusIconBytes(id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
          );
        }

        return Image.asset(
          'assets/status_icons/$id.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
    );
  }
}

class _BuffColors {
  const _BuffColors({
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color icon;
}
