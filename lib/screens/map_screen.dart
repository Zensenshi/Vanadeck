import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/party_member.dart';
import '../models/player_status.dart';
import '../services/map_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.statusStream});

  final Stream<PlayerStatus> statusStream;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _firstPacketPending = true;
  Timer? _firstPacketTimer;

  @override
  void initState() {
    super.initState();
    _startFirstPacketTimer();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    await MapService.loadMappyMaps();
    if (!mounted) {
      return;
    }

    setState(() {});
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

  @override
  void dispose() {
    _firstPacketTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<PlayerStatus>(
        stream: widget.statusStream,
        builder: (context, snapshot) {
          if (_isWaitingForFirstPacket(snapshot)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_isWaitingForData(snapshot)) {
            return _MapMessage(
              message:
                  'No game update received yet.\n\nIs the addon running and connected to the game?',
              onRetry: _retryConnection,
            );
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return _MapMessage(
              message: 'Could not load live game data.\n\n${snapshot.error}',
              onRetry: _retryConnection,
            );
          }

          return _MapDisplay(status: snapshot.data!);
        },
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.sync),
              label: const Text('Retry connection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDisplay extends StatefulWidget {
  const _MapDisplay({required this.status});

  final PlayerStatus status;

  @override
  State<_MapDisplay> createState() => _MapDisplayState();
}

class _MapDisplayState extends State<_MapDisplay>
    with SingleTickerProviderStateMixin {
  static const _cameraAnimationDuration = Duration(milliseconds: 700);

  late TransformationController _transformationController;
  late AnimationController _cameraAnimationController;
  Animation<Matrix4>? _cameraAnimation;
  Offset? _lastPlayerPosition;
  String? _lastZone;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _cameraAnimationController =
        AnimationController(vsync: this, duration: _cameraAnimationDuration)
          ..addListener(() {
            final animation = _cameraAnimation;
            if (animation != null) {
              _transformationController.value = animation.value;
            }
          });
  }

  @override
  void dispose() {
    _cameraAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerZone = widget.status.partyMembers.isNotEmpty
        ? widget.status.partyMembers[0].location
        : '';
    final player = widget.status.partyMembers.isNotEmpty
        ? widget.status.partyMembers[0]
        : null;
    final mapPath = MapService.getMapPath(
      playerZone,
      zoneId: player?.zoneId,
      subMapNum: player?.subMapNum,
      worldX: player?.worldX,
      worldY: player?.worldY,
      worldZ: player?.worldZ,
    );
    final mapEntry = player != null
        ? MapService.getMappyMapEntry(
            playerZone,
            zoneId: player.zoneId,
            subMapNum: player.subMapNum,
            worldX: player.worldX,
            worldY: player.worldY,
            worldZ: player.worldZ,
          )
        : MapService.getMappyMapEntry(playerZone);
    final resolvedMapPath = mapEntry?.imageUri ?? mapPath;
    final playerPosition = player != null
        ? _playerMapPosition(player, playerZone)
        : null;
    final entityMarkers = _entityMarkers(
      zone: playerZone,
      zoneId: player?.zoneId,
      mapEntry: mapEntry,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (player != null &&
            playerPosition != null &&
            resolvedMapPath != null) {
          _autoCenterWhenMoving(
            playerPosition: playerPosition,
            zone: playerZone,
            mapSize: size,
            viewportSize: viewportSize,
          );
        }

        return ColoredBox(
          color: const Color(0xFF112022),
          child: resolvedMapPath != null
              ? Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        boundaryMargin: EdgeInsets.zero,
                        minScale: 0.5,
                        maxScale: 5.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: SizedBox.square(
                          dimension: size,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _MappyMapImage(imageUri: resolvedMapPath),
                              if (player != null && playerPosition != null)
                                _MapOverlay(
                                  player: player,
                                  playerPosition: playerPosition,
                                  entityMarkers: entityMarkers,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _missingMapMessage(playerZone),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _missingMapMessage(String playerZone) {
    if (!MapService.hasMappyMaps) {
      return MapService.mapsFolderName == null
          ? 'Select your Mappy Maps folder in Settings to show zone maps.'
          : 'No Mappy maps were found in ${MapService.mapsFolderName}.\n\nOpen Settings and select the folder that contains map.ini and the map images.';
    }

    return playerZone.isNotEmpty
        ? 'Map not available for $playerZone'
        : 'Waiting for location data...';
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

  List<_MapEntityMarkerData> _entityMarkers({
    required String zone,
    required int? zoneId,
    required MappyMapEntry? mapEntry,
  }) {
    final markers = <_MapEntityMarkerData>[];
    for (final entity in widget.status.mapEntities) {
      if (!_isEntityInCurrentZone(entity, zone: zone, zoneId: zoneId)) {
        continue;
      }

      final isMob = entity.isMob;
      if (!entity.isNpc && !isMob) {
        continue;
      }

      final position = _mapEntityPosition(entity, mapEntry);
      if (position == null) {
        continue;
      }

      markers.add(
        _MapEntityMarkerData(
          name: entity.name,
          position: position,
          color: isMob ? const Color(0xFFFF4B4B) : const Color(0xFF35AEE8),
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

  Offset? _mapEntityPosition(
    MapEntityLocation entity,
    MappyMapEntry? mapEntry,
  ) {
    final worldX = entity.worldX;
    final worldMapY = entity.worldY ?? entity.worldZ;

    if (mapEntry != null && worldX != null && worldMapY != null) {
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

  void _autoCenterWhenMoving({
    required Offset playerPosition,
    required String zone,
    required double mapSize,
    required Size viewportSize,
  }) {
    final position = playerPosition;
    final lastPosition = _lastPlayerPosition;
    final zoneChanged = _lastZone != zone;

    _lastPlayerPosition = position;
    _lastZone = zone;

    if (zoneChanged || lastPosition == null) {
      return;
    }

    final moved = (position - lastPosition).distance > 0.0005;
    if (!moved) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final scale = _transformationController.value.getMaxScaleOnAxis();
      final playerOffset = Offset(
        playerPosition.dx * mapSize,
        playerPosition.dy * mapSize,
      );
      final centeredOffset =
          viewportSize.center(Offset.zero) -
          Offset(playerOffset.dx * scale, playerOffset.dy * scale);

      final target = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, centeredOffset.dx)
        ..setEntry(1, 3, centeredOffset.dy);

      _cameraAnimationController.stop();
      _cameraAnimation =
          Matrix4Tween(
            begin: Matrix4.copy(_transformationController.value),
            end: target,
          ).animate(
            CurvedAnimation(
              parent: _cameraAnimationController,
              curve: Curves.easeOutCubic,
            ),
          );
      _cameraAnimationController.forward(from: 0);
    });
  }
}

class _MappyMapImage extends StatelessWidget {
  const _MappyMapImage({required this.imageUri});

  final String imageUri;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: MapService.loadMappyMapBytes(imageUri),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const ColoredBox(
            color: Color(0xFF0B1415),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true);
      },
    );
  }
}

class _MapOverlay extends StatelessWidget {
  const _MapOverlay({
    required this.player,
    required this.playerPosition,
    required this.entityMarkers,
  });

  final PartyMember player;
  final Offset playerPosition;
  final List<_MapEntityMarkerData> entityMarkers;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              for (final marker in entityMarkers)
                Positioned(
                  left: (constraints.maxWidth * marker.position.dx).clamp(
                    0.0,
                    constraints.maxWidth,
                  ),
                  top: (constraints.maxHeight * marker.position.dy).clamp(
                    0.0,
                    constraints.maxHeight,
                  ),
                  child: _MapEntityMarker(marker: marker),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 850),
                curve: Curves.linear,
                left: (constraints.maxWidth * playerPosition.dx).clamp(
                  0.0,
                  constraints.maxWidth,
                ),
                top: (constraints.maxHeight * playerPosition.dy).clamp(
                  0.0,
                  constraints.maxHeight,
                ),
                child: _PlayerMarker(member: player),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapEntityMarkerData {
  const _MapEntityMarkerData({
    required this.name,
    required this.position,
    required this.color,
    required this.size,
  });

  final String name;
  final Offset position;
  final Color color;
  final double size;
}

class _MapEntityMarker extends StatelessWidget {
  const _MapEntityMarker({required this.marker});

  final _MapEntityMarkerData marker;

  @override
  Widget build(BuildContext context) {
    final dot = Transform.translate(
      offset: Offset(-marker.size / 2, -marker.size / 2),
      child: Container(
        width: marker.size,
        height: marker.size,
        decoration: BoxDecoration(color: marker.color, shape: BoxShape.circle),
      ),
    );

    if (marker.name.isEmpty) {
      return dot;
    }

    return Tooltip(message: marker.name, child: dot);
  }
}

class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker({required this.member});

  static const double _size = 14.45;

  final PartyMember member;

  @override
  Widget build(BuildContext context) {
    final heading = _headingRadians(member.heading);

    return Tooltip(
      message: '${member.name} (You)',
      child: Transform.translate(
        offset: const Offset(-_size / 2, -_size / 2),
        child: Transform.rotate(
          angle: heading,
          child: const SizedBox.square(
            dimension: _size,
            child: CustomPaint(painter: _PlayerArrowPainter()),
          ),
        ),
      ),
    );
  }

  double _headingRadians(double? heading) {
    if (heading == null || !heading.isFinite) {
      return 0;
    }

    const twoPi = math.pi * 2;
    final correctedHeading = heading + (math.pi / 2);
    if (heading.abs() > twoPi * 2) {
      return ((heading / 255.0) * twoPi) + (math.pi / 2);
    }

    return correctedHeading;
  }
}

class _PlayerArrowPainter extends CustomPainter {
  const _PlayerArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final arrow = Path()
      ..moveTo(size.width * 0.50, size.height * 0.04)
      ..lineTo(size.width * 0.84, size.height * 0.82)
      ..lineTo(size.width * 0.50, size.height * 0.66)
      ..lineTo(size.width * 0.16, size.height * 0.82)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrow, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _PlayerArrowPainter oldDelegate) => false;
}
