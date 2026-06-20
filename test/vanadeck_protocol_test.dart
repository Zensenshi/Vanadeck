import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanadeck/services/vanadeck_protocol.dart';

void main() {
  group('VanaDeckProtocol', () {
    test('round-trips a nested status payload', () {
      final payload = <String, dynamic>{
        'player': <String, dynamic>{
          'name': 'Aldwyn',
          'level': 99,
          'currentHp': 1284,
          'worldX': -42.5,
          'isSubTargetActive': false,
        },
        'partyMembers': [
          <String, dynamic>{
            'name': 'Aldwyn',
            'job': 'RDM',
            'activeBuffs': [33, 580],
          },
        ],
        'chatMessages': [
          <String, dynamic>{
            'id': 7,
            'text': 'Hello Vana\'diel',
            'color': 0xFF00FFFF,
            'blocked': false,
          },
        ],
        'target': null,
      };

      final encoded = VanaDeckProtocol.encodeFrame(
        VanaDeckMessageType.status,
        payload,
      );
      final decoded = VanaDeckProtocol.decodeFrame(encoded);

      expect(decoded.version, VanaDeckProtocol.version);
      expect(decoded.type, VanaDeckMessageType.status);
      expect(decoded.payload, equals(payload));
    });

    test('round-trips command frames', () {
      final encoded = VanaDeckProtocol.encodeFrame(
        VanaDeckMessageType.command,
        '/ma "Refresh II" <me>',
      );
      final decoded = VanaDeckProtocol.decodeFrame(encoded);

      expect(decoded.type, VanaDeckMessageType.command);
      expect(decoded.payload, '/ma "Refresh II" <me>');
    });

    test('decodes frames split across stream chunks', () {
      final first = VanaDeckProtocol.encodeFrame(VanaDeckMessageType.hello, {
        'protocol': 'vanadeck',
        'version': 1,
      });
      final second = VanaDeckProtocol.encodeFrame(
        VanaDeckMessageType.command,
        '/p Ready',
      );
      final decoder = VanaDeckFrameStreamDecoder();

      expect(decoder.add(first.sublist(0, 4)), isEmpty);

      final frames = decoder.add([...first.sublist(4), ...second]);

      expect(frames, hasLength(2));
      expect(frames[0].type, VanaDeckMessageType.hello);
      expect(frames[1].payload, '/p Ready');
    });

    test('does not classify legacy JSON as a binary frame', () {
      final legacy = utf8.encode('{"player":{"name":"Aldwyn"}}');

      expect(VanaDeckProtocol.startsWithMagic(legacy), isFalse);
      expect(VanaDeckProtocol.matchesMagicPrefix(legacy), isFalse);
    });
  });
}
