import 'dart:async';
import 'package:flutter/material.dart';

import '../models/player_status.dart';
import '../services/app_settings_controller.dart';
import '../widgets/party_member_tile.dart';
import '../widgets/stat_bar.dart';
import '../widgets/status_icon_strip.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({
    super.key,
    required this.statusStream,
    required this.settings,
  });

  final Stream<PlayerStatus> statusStream;
  final AppSettingsController settings;

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  bool _firstPacketPending = true;
  Timer? _firstPacketTimer;

  @override
  void initState() {
    super.initState();
    _startFirstPacketTimer();
  }

  void _startFirstPacketTimer() {
    _firstPacketTimer?.cancel();
    _firstPacketPending = true;
    _firstPacketTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _firstPacketPending = false;
        });
      }
    });
  }

  void _retryConnection() {
    setState(() {
      _startFirstPacketTimer();
    });
  }

  bool _isWaitingForFirstPacket(AsyncSnapshot<PlayerStatus> snapshot) {
    return !snapshot.hasData &&
        !snapshot.hasError &&
        _firstPacketPending &&
        snapshot.connectionState == ConnectionState.waiting;
  }

  bool _isWaitingForData(AsyncSnapshot<PlayerStatus> snapshot) {
    return !snapshot.hasData && !snapshot.hasError && !_firstPacketPending;
  }

  String _connectionLabel(AsyncSnapshot<PlayerStatus> snapshot) {
    if (_isWaitingForFirstPacket(snapshot)) {
      return 'Connecting…';
    }
    if (_isWaitingForData(snapshot)) {
      return 'Waiting for game data';
    }
    if (snapshot.hasError && !snapshot.hasData) {
      return 'Disconnected';
    }
    return 'Connected';
  }

  Color _connectionColor(AsyncSnapshot<PlayerStatus> snapshot) {
    if (_isWaitingForFirstPacket(snapshot)) {
      return Colors.amber;
    }
    if (_isWaitingForData(snapshot)) {
      return Colors.orangeAccent;
    }
    if (snapshot.hasError && !snapshot.hasData) {
      return Colors.redAccent;
    }
    return Colors.greenAccent;
  }

  @override
  void dispose() {
    _firstPacketTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<PlayerStatus>(
          stream: widget.statusStream,
          builder: (context, snapshot) {
            if (_isWaitingForFirstPacket(snapshot)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_isWaitingForData(snapshot)) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No game update received yet.\n\nIs the addon running and connected to the game?',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _retryConnection,
                        icon: const Icon(Icons.sync),
                        label: const Text('Retry connection'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load live game data.\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _retryConnection,
                        icon: const Icon(Icons.sync),
                        label: const Text('Retry connection'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final status = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.name,
                            style: textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${status.job} / ${status.subjob}',
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (status.activeBuffs.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: StatusIconStrip(
                                    buffs: status.activeBuffs,
                                    settings: widget.settings,
                                    compact: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ConnectionIndicator(
                      label: _connectionLabel(snapshot),
                      color: _connectionColor(snapshot),
                      icon: snapshot.hasError && !snapshot.hasData
                          ? Icons.wifi_off
                          : Icons.wifi,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StatBar(
                  label: 'HP',
                  currentValue: status.currentHp,
                  maxValue: status.maxHp,
                  percent: status.hpPercent,
                  color: const Color(0xFFE25C5C),
                ),
                const SizedBox(height: 10),
                StatBar(
                  label: 'MP',
                  currentValue: status.currentMp,
                  maxValue: status.maxMp,
                  percent: status.mpPercent,
                  color: const Color(0xFF5A9BE8),
                ),
                const SizedBox(height: 12),
                _TpPanel(tp: status.tp),
                const SizedBox(height: 12),
                _ExperiencePanel(status: status),
                const SizedBox(height: 20),
                Text(
                  'Party',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final member in status.partyMembers) ...[
                  PartyMemberTile(member: member, settings: widget.settings),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExperiencePanel extends StatelessWidget {
  const _ExperiencePanel({required this.status});

  final PlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final currentExp = status.currentExp;
    final expToNext = status.expToNextLevel;
    final totalForLevel = currentExp + expToNext;
    final progress = status.expPercent.clamp(0.0, 1.0).toDouble();
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Level ${status.level}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '$currentExp EXP',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.black.withValues(alpha: 0.28),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6FAE),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalForLevel <= 0
                        ? 'Experience data unavailable'
                        : '$expToNext until next level',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (totalForLevel > 0)
                  Text(
                    '$currentExp / $totalForLevel',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }
}

class _TpPanel extends StatelessWidget {
  const _TpPanel({required this.tp});

  final int tp;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TP', style: Theme.of(context).textTheme.labelLarge),
            Text(
              '$tp',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE6C65C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
