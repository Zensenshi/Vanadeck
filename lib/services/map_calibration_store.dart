import 'dart:convert';

import 'package:flutter/services.dart';

import 'map_service.dart';

class MapCalibrationStore {
  const MapCalibrationStore();

  static const _channel = MethodChannel('vanadeck/calibration');

  Future<Map<String, MapCoordinateCalibration>> load() async {
    try {
      final payload = await _channel.invokeMethod<String>('loadCalibrations');
      if (payload == null || payload.isEmpty) {
        return {};
      }

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return decoded.map((zone, value) {
        return MapEntry(
          zone,
          MapCoordinateCalibration.fromJson(value as Map<String, dynamic>),
        );
      });
    } on MissingPluginException {
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, MapCoordinateCalibration> calibrations) async {
    final payload = jsonEncode(
      calibrations.map((zone, calibration) {
        return MapEntry(zone, calibration.toJson());
      }),
    );

    try {
      await _channel.invokeMethod<void>('saveCalibrations', payload);
    } on MissingPluginException {
      return;
    }
  }
}
