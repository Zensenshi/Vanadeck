import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanadeck/services/map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mapsChannel = MethodChannel('vanadeck/maps');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mapsChannel, null);
    MapService.clearMappyMapImageCache();
  });

  test('caches mappy map image loads by URI', () async {
    var loadCalls = 0;
    final imageBytes = Uint8List.fromList([1, 2, 3, 4]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mapsChannel, (call) async {
          if (call.method == 'loadMapImage') {
            loadCalls += 1;
            return imageBytes;
          }
          return null;
        });

    final firstLoad = MapService.loadMappyMapBytes('map://bastok');
    final secondLoad = MapService.loadMappyMapBytes('map://bastok');

    expect(secondLoad, same(firstLoad));
    expect(await firstLoad, orderedEquals(imageBytes));
    expect(await secondLoad, orderedEquals(imageBytes));
    expect(loadCalls, 1);
  });
}
