import 'dart:convert';

import 'package:flutter/services.dart';

/// Converts FFXI world coordinates into normalized image coordinates.
class MapCoordinateCalibration {
  const MapCoordinateCalibration({
    this.minX = -1024.0,
    this.maxX = 1024.0,
    this.minZ = -1024.0,
    this.maxZ = 1024.0,
    this.scaleX = 2.0,
    this.scaleY = 2.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.mapSize = 2048,
  });

  final double minX;
  final double maxX;
  final double minZ;
  final double maxZ;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;
  final int mapSize;

  double normalizeX(double worldX) {
    final raw = (worldX - minX) / (maxX - minX);
    return (0.5 + ((raw - 0.5) * scaleX) + offsetX).clamp(0.0, 1.0);
  }

  double normalizeY(double worldZ) {
    final raw = (maxZ - worldZ) / (maxZ - minZ);
    return (0.5 + ((raw - 0.5) * scaleY) + offsetY).clamp(0.0, 1.0);
  }

  Map<String, Object> toJson() {
    return {
      'minX': minX,
      'maxX': maxX,
      'minZ': minZ,
      'maxZ': maxZ,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'mapSize': mapSize,
    };
  }

  static MapCoordinateCalibration fromJson(Map<String, dynamic> json) {
    return MapCoordinateCalibration(
      minX: (json['minX'] as num?)?.toDouble() ?? -1024.0,
      maxX: (json['maxX'] as num?)?.toDouble() ?? 1024.0,
      minZ: (json['minZ'] as num?)?.toDouble() ?? -1024.0,
      maxZ: (json['maxZ'] as num?)?.toDouble() ?? 1024.0,
      scaleX: (json['scaleX'] as num?)?.toDouble() ?? 2.0,
      scaleY: (json['scaleY'] as num?)?.toDouble() ?? 2.0,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
      mapSize: (json['mapSize'] as num?)?.toInt() ?? 2048,
    );
  }
}

class MappyMapEntry {
  const MappyMapEntry({
    required this.zoneName,
    required this.zoneId,
    required this.mapId,
    required this.mapNumber,
    required this.imageUri,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.bounds,
  });

  final String zoneName;
  final int zoneId;
  final String mapId;
  final int mapNumber;
  final String imageUri;
  final double a;
  final double b;
  final double c;
  final double d;
  final List<MappyMapBounds> bounds;

  bool contains({double? worldX, double? worldY, double? worldZ}) {
    if (bounds.isEmpty || worldX == null || worldY == null || worldZ == null) {
      return true;
    }

    return bounds.any((bound) {
      return bound.contains(worldX: worldX, worldY: worldY, worldZ: worldZ);
    });
  }

  ({double x, double y}) worldToMap({
    required double worldX,
    required double worldMapY,
  }) {
    // Mappy map.ini transforms world coordinates into its 256x256 map space.
    // The image assets may be 512, 1024, or 2048px, but the normalized point
    // still comes from dividing the transformed coordinate by 256.
    return (
      x: ((worldX * a + b) / 256.0).clamp(0.0, 1.0),
      y: ((worldMapY * c + d) / 256.0).clamp(0.0, 1.0),
    );
  }
}

class MappyMapBounds {
  const MappyMapBounds({
    required this.minX,
    required this.minY,
    required this.minZ,
    required this.maxX,
    required this.maxY,
    required this.maxZ,
  });

  final double minX;
  final double minY;
  final double minZ;
  final double maxX;
  final double maxY;
  final double maxZ;

  bool contains({
    required double worldX,
    required double worldY,
    required double worldZ,
  }) {
    return worldX >= minX &&
        worldX <= maxX &&
        worldY >= minY &&
        worldY <= maxY &&
        worldZ >= minZ &&
        worldZ <= maxZ;
  }
}

/// Map service that manages FFXI zone information and map file lookups.
class MapService {
  static const MethodChannel _mapsChannel = MethodChannel('vanadeck/maps');
  static const MapCoordinateCalibration defaultCalibration =
      MapCoordinateCalibration();

  /// Per-zone calibration overrides for maps that do not line up with the
  /// default -1024..1024 world-space bounds.
  static final Map<String, MapCoordinateCalibration> zoneCalibrations = {};
  static final Map<String, List<MappyMapEntry>> _mappyMapsByZone = {};
  static final Map<int, List<MappyMapEntry>> _mappyMapsByZoneId = {};
  static Future<void>? _mappyLoadFuture;
  static String? _mapsFolderName;

  static void setCalibrations(
    Map<String, MapCoordinateCalibration> calibrations,
  ) {
    zoneCalibrations
      ..clear()
      ..addAll(calibrations);
  }

  static void setCalibration(
    String zoneName,
    MapCoordinateCalibration calibration,
  ) {
    zoneCalibrations[zoneName] = calibration;
  }

  static void clearCalibration(String zoneName) {
    zoneCalibrations.remove(zoneName);
  }

  /// Get the map file path for a given zone name.
  /// Returns null if zone is not found.
  static String? getMapPath(
    String zoneName, {
    int? zoneId,
    int? subMapNum,
    double? worldX,
    double? worldY,
    double? worldZ,
  }) {
    return getMappyMapEntry(
      zoneName,
      zoneId: zoneId,
      subMapNum: subMapNum,
      worldX: worldX,
      worldY: worldY,
      worldZ: worldZ,
    )?.imageUri;
  }

  static bool get hasMappyMaps => _mappyMapsByZoneId.isNotEmpty;

  static String? get mapsFolderName => _mapsFolderName;

  static Future<bool> pickMapsFolder() async {
    try {
      final selected = await _mapsChannel.invokeMethod<bool>('pickMapsFolder');
      if (selected ?? false) {
        _mappyLoadFuture = null;
        await loadMappyMaps();
        return true;
      }
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }

    return false;
  }

  static Future<Uint8List?> loadMappyMapBytes(String imageUri) async {
    try {
      return await _mapsChannel.invokeMethod<Uint8List>(
        'loadMapImage',
        imageUri,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static MappyMapEntry? getMappyMapEntry(
    String zoneName, {
    int? zoneId,
    int? subMapNum,
    double? worldX,
    double? worldY,
    double? worldZ,
  }) {
    final maps = zoneId == null
        ? _mappyMapsByZone[zoneName]
        : _mappyMapsByZoneId[zoneId] ?? _mappyMapsByZone[zoneName];
    if (maps == null || maps.isEmpty) {
      return null;
    }

    MappyMapEntry? firstBoundedEntry;
    MappyMapEntry? firstSubMapEntry;
    if (subMapNum != null) {
      for (final entry in maps) {
        final subMapMatches =
            entry.mapNumber == subMapNum || entry.mapNumber == subMapNum - 1;
        final containsPoint = entry.contains(
          worldX: worldX,
          worldY: worldY,
          worldZ: worldZ,
        );

        if (containsPoint) {
          firstBoundedEntry ??= entry;
          if (subMapMatches) {
            return entry;
          }
        }

        if (subMapMatches) {
          firstSubMapEntry ??= entry;
        }
      }
    } else {
      for (final entry in maps) {
        if (entry.contains(worldX: worldX, worldY: worldY, worldZ: worldZ)) {
          return entry;
        }
      }
    }

    return firstBoundedEntry ?? firstSubMapEntry ?? maps.first;
  }

  static Future<void> loadMappyMaps() {
    return _mappyLoadFuture ??= _loadMappyMaps();
  }

  static MapCoordinateCalibration getCalibration(String zoneName) {
    return zoneCalibrations[zoneName] ?? defaultCalibration;
  }

  static ({double x, double y}) worldToMap({
    required String zoneName,
    int? zoneId,
    int? subMapNum,
    required double worldX,
    double? worldY,
    double? worldZ,
  }) {
    final worldMapY = worldY ?? worldZ;
    if (worldMapY == null) {
      final calibration = getCalibration(zoneName);
      return (x: calibration.normalizeX(worldX), y: 0.5);
    }

    final mappyEntry = getMappyMapEntry(
      zoneName,
      zoneId: zoneId,
      subMapNum: subMapNum,
      worldX: worldX,
      worldY: worldY,
      worldZ: worldZ,
    );
    if (mappyEntry != null) {
      return mappyEntry.worldToMap(worldX: worldX, worldMapY: worldMapY);
    }

    final calibration = getCalibration(zoneName);
    return (
      x: calibration.normalizeX(worldX),
      y: calibration.normalizeY(worldMapY),
    );
  }

  static Future<void> _loadMappyMaps() async {
    final imagesByName = await _loadMappyImagesByName();
    final zoneNamesById = <String, String>{};
    final entriesByZone = <String, List<MappyMapEntry>>{};
    final entriesByZoneId = <int, List<MappyMapEntry>>{};
    final mapIni = await _loadMapIni();
    if (mapIni == null || mapIni.trim().isEmpty) {
      _mappyMapsByZone.clear();
      _mappyMapsByZoneId.clear();
      return;
    }

    final lines = const LineSplitter().convert(mapIni);

    for (final rawLine in lines) {
      final line = rawLine.trim().replaceFirst('\uFEFF', '');
      if (line.isEmpty || line.startsWith(';') || !line.contains('=')) {
        continue;
      }

      final separator = line.indexOf('=');
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      final enameMatch = RegExp(r'^([0-9a-fA-F]+)_ename$').firstMatch(key);
      if (enameMatch != null) {
        zoneNamesById[enameMatch.group(1)!.toLowerCase()] = value;
        continue;
      }

      final mapMatch = RegExp(r'^([0-9a-fA-F]+)_([0-9]+)$').firstMatch(key);
      if (mapMatch == null) {
        continue;
      }

      final zoneId = mapMatch.group(1)!.toLowerCase();
      final zoneName = zoneNamesById[zoneId];
      final numericZoneId = int.tryParse(zoneId, radix: 16);
      if (zoneName == null || zoneName.isEmpty) {
        continue;
      }
      if (numericZoneId == null) {
        continue;
      }

      final mapNumber = int.parse(mapMatch.group(2)!);
      final mapId = '${zoneId}_$mapNumber';
      final imageUri = _findMappyImageUri(imagesByName, mapId);
      if (imageUri == null) {
        continue;
      }

      final values = value
          .split(',')
          .map((part) => double.tryParse(part.trim()))
          .whereType<double>()
          .toList();
      if (values.length < 4) {
        continue;
      }

      final bounds = <MappyMapBounds>[];
      for (var index = 4; index + 5 < values.length; index += 6) {
        bounds.add(
          MappyMapBounds(
            minX: values[index],
            minY: values[index + 1],
            minZ: values[index + 2],
            maxX: values[index + 3],
            maxY: values[index + 4],
            maxZ: values[index + 5],
          ),
        );
      }

      final entry = MappyMapEntry(
        zoneName: zoneName,
        zoneId: numericZoneId,
        mapId: mapId,
        mapNumber: mapNumber,
        imageUri: imageUri,
        a: values[0],
        b: values[1],
        c: values[2],
        d: values[3],
        bounds: bounds,
      );
      entriesByZone.putIfAbsent(zoneName, () => []).add(entry);
      entriesByZoneId.putIfAbsent(numericZoneId, () => []).add(entry);
    }

    _mappyMapsByZone
      ..clear()
      ..addAll(entriesByZone);
    _mappyMapsByZoneId
      ..clear()
      ..addAll(entriesByZoneId);
  }

  static Future<String?> _loadMapIni() async {
    try {
      _mapsFolderName = await _mapsChannel.invokeMethod<String>(
        'getMapsFolderName',
      );
      return await _mapsChannel.invokeMethod<String>('loadMapIni');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<Map<String, String>> _loadMappyImagesByName() async {
    try {
      final rawImages = await _mapsChannel.invokeMethod<List<dynamic>>(
        'listMapImages',
      );
      final imagesByName = <String, String>{};
      for (final rawImage in rawImages ?? const <dynamic>[]) {
        final image = Map<String, dynamic>.from(rawImage as Map);
        final name = image['name'] as String?;
        final uri = image['uri'] as String?;
        if (name == null || uri == null) {
          continue;
        }
        imagesByName[name.toLowerCase()] = uri;
      }
      return imagesByName;
    } on MissingPluginException {
      return {};
    } on PlatformException {
      return {};
    }
  }

  static String? _findMappyImageUri(
    Map<String, String> imagesByName,
    String mapId,
  ) {
    final mapIdPrefix = '$mapId.'.toLowerCase();
    for (final entry in imagesByName.entries) {
      if (entry.key.startsWith(mapIdPrefix)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Normalize game coordinates (0-2048) to widget coordinates (0-1).
  static double normalizeCoordinate(double gameCoord) {
    return (gameCoord / 2048.0).clamp(0.0, 1.0);
  }

  /// Denormalize widget coordinates (0-1) to game coordinates (0-2048).
  static double denormalizeCoordinate(double normalizedCoord) {
    return normalizedCoord * 2048.0;
  }
}
