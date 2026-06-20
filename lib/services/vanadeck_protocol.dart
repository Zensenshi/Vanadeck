import 'dart:convert';
import 'dart:typed_data';

enum VanaDeckMessageType {
  status(1),
  command(2),
  hello(3);

  const VanaDeckMessageType(this.id);

  final int id;

  static VanaDeckMessageType? fromId(int id) {
    for (final type in values) {
      if (type.id == id) {
        return type;
      }
    }
    return null;
  }
}

class VanaDeckFrame {
  const VanaDeckFrame({
    required this.version,
    required this.type,
    required this.payload,
  });

  final int version;
  final VanaDeckMessageType type;
  final Object? payload;
}

class VanaDeckProtocol {
  const VanaDeckProtocol._();

  static const version = 1;
  static const headerLength = 10;
  static const maxPayloadLength = 1024 * 1024;

  static const _magic = [0x56, 0x44, 0x4B]; // VDK
  static const _typeNull = 0;
  static const _typeFalse = 1;
  static const _typeTrue = 2;
  static const _typePositiveInt = 3;
  static const _typeNegativeInt = 4;
  static const _typeFloat = 5;
  static const _typeString = 6;
  static const _typeList = 7;
  static const _typeMap = 8;

  static Uint8List encodeFrame(VanaDeckMessageType type, Object? payload) {
    final payloadBuilder = BytesBuilder(copy: false);
    _writeValue(payloadBuilder, payload);
    final payloadBytes = payloadBuilder.takeBytes();
    if (payloadBytes.length > maxPayloadLength) {
      throw FormatException('VanaDeck frame payload is too large.');
    }

    final frame = Uint8List(headerLength + payloadBytes.length);
    frame.setRange(0, _magic.length, _magic);
    frame[3] = version;
    frame[4] = type.id;
    frame[5] = 0;
    _writeUint32(frame, 6, payloadBytes.length);
    frame.setRange(headerLength, frame.length, payloadBytes);
    return frame;
  }

  static VanaDeckFrame decodeFrame(List<int> bytes) {
    if (bytes.length < headerLength) {
      throw const FormatException('VanaDeck frame header is incomplete.');
    }
    if (!startsWithMagic(bytes)) {
      throw const FormatException('VanaDeck frame magic is invalid.');
    }

    final frameVersion = bytes[3];
    if (frameVersion != version) {
      throw FormatException(
        'Unsupported VanaDeck protocol version $frameVersion.',
      );
    }

    final type = VanaDeckMessageType.fromId(bytes[4]);
    if (type == null) {
      throw FormatException('Unknown VanaDeck message type ${bytes[4]}.');
    }

    final payloadLength = payloadLengthFromHeader(bytes);
    final expectedLength = headerLength + payloadLength;
    if (bytes.length != expectedLength) {
      throw FormatException(
        'VanaDeck frame length mismatch: got ${bytes.length}, '
        'expected $expectedLength.',
      );
    }

    final reader = _ValueReader(bytes, headerLength, expectedLength);
    final payload = reader.readValue();
    reader.expectDone();
    return VanaDeckFrame(version: frameVersion, type: type, payload: payload);
  }

  static bool startsWithMagic(List<int> bytes) {
    if (bytes.length < _magic.length) {
      return false;
    }
    for (var index = 0; index < _magic.length; index += 1) {
      if (bytes[index] != _magic[index]) {
        return false;
      }
    }
    return true;
  }

  static bool matchesMagicPrefix(List<int> bytes) {
    if (bytes.isEmpty) {
      return false;
    }
    final length = bytes.length < _magic.length ? bytes.length : _magic.length;
    for (var index = 0; index < length; index += 1) {
      if (bytes[index] != _magic[index]) {
        return false;
      }
    }
    return true;
  }

  static int? frameLengthFromHeader(List<int> bytes) {
    if (bytes.length < headerLength || !startsWithMagic(bytes)) {
      return null;
    }
    final payloadLength = payloadLengthFromHeader(bytes);
    if (payloadLength > maxPayloadLength) {
      throw FormatException(
        'VanaDeck frame payload is too large: $payloadLength bytes.',
      );
    }
    return headerLength + payloadLength;
  }

  static int payloadLengthFromHeader(List<int> bytes) {
    if (bytes.length < headerLength) {
      throw const FormatException('VanaDeck frame header is incomplete.');
    }
    return (bytes[6] << 24) | (bytes[7] << 16) | (bytes[8] << 8) | bytes[9];
  }

  static void _writeUint32(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }

  static void _writeValue(BytesBuilder builder, Object? value) {
    if (value == null) {
      builder.addByte(_typeNull);
      return;
    }
    if (value is bool) {
      builder.addByte(value ? _typeTrue : _typeFalse);
      return;
    }
    if (value is int) {
      if (value < 0) {
        builder.addByte(_typeNegativeInt);
        _writeVarUint(builder, -value);
      } else {
        builder.addByte(_typePositiveInt);
        _writeVarUint(builder, value);
      }
      return;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw FormatException('Cannot encode non-finite number $value.');
      }
      builder.addByte(_typeFloat);
      _writeStringPayload(builder, value.toString());
      return;
    }
    if (value is num) {
      _writeValue(builder, value.toDouble());
      return;
    }
    if (value is String) {
      builder.addByte(_typeString);
      _writeStringPayload(builder, value);
      return;
    }
    if (value is Iterable) {
      final values = value.toList(growable: false);
      builder.addByte(_typeList);
      _writeVarUint(builder, values.length);
      for (final item in values) {
        _writeValue(builder, item);
      }
      return;
    }
    if (value is Map) {
      final entries = value.entries.toList(growable: false);
      builder.addByte(_typeMap);
      _writeVarUint(builder, entries.length);
      for (final entry in entries) {
        _writeStringPayload(builder, entry.key.toString());
        _writeValue(builder, entry.value);
      }
      return;
    }

    throw FormatException('Cannot encode ${value.runtimeType}.');
  }

  static void _writeStringPayload(BytesBuilder builder, String value) {
    final bytes = utf8.encode(value);
    _writeVarUint(builder, bytes.length);
    builder.add(bytes);
  }

  static void _writeVarUint(BytesBuilder builder, int value) {
    if (value < 0) {
      throw FormatException('Cannot encode negative varuint $value.');
    }

    var remaining = value;
    while (remaining >= 0x80) {
      builder.addByte((remaining & 0x7F) | 0x80);
      remaining >>= 7;
    }
    builder.addByte(remaining);
  }
}

class VanaDeckFrameStreamDecoder {
  final List<int> _buffer = <int>[];

  List<VanaDeckFrame> add(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <VanaDeckFrame>[];

    while (_buffer.isNotEmpty) {
      final frameLength = VanaDeckProtocol.frameLengthFromHeader(_buffer);
      if (frameLength == null || _buffer.length < frameLength) {
        break;
      }

      final frameBytes = _buffer.sublist(0, frameLength);
      _buffer.removeRange(0, frameLength);
      frames.add(VanaDeckProtocol.decodeFrame(frameBytes));
    }

    return frames;
  }

  bool get hasBufferedData => _buffer.isNotEmpty;
}

class _ValueReader {
  _ValueReader(this._bytes, [this._offset = 0, int? end])
    : _end = end ?? _bytes.length;

  final List<int> _bytes;
  final int _end;
  int _offset;

  Object? readValue() {
    final type = _readByte();
    switch (type) {
      case VanaDeckProtocol._typeNull:
        return null;
      case VanaDeckProtocol._typeFalse:
        return false;
      case VanaDeckProtocol._typeTrue:
        return true;
      case VanaDeckProtocol._typePositiveInt:
        return _readVarUint();
      case VanaDeckProtocol._typeNegativeInt:
        return -_readVarUint();
      case VanaDeckProtocol._typeFloat:
        return double.parse(_readStringPayload());
      case VanaDeckProtocol._typeString:
        return _readStringPayload();
      case VanaDeckProtocol._typeList:
        final length = _readVarUint();
        return List<Object?>.generate(length, (_) => readValue());
      case VanaDeckProtocol._typeMap:
        final length = _readVarUint();
        final map = <String, dynamic>{};
        for (var index = 0; index < length; index += 1) {
          map[_readStringPayload()] = readValue();
        }
        return map;
      default:
        throw FormatException('Unknown VanaDeck value type $type.');
    }
  }

  void expectDone() {
    if (_offset != _end) {
      throw FormatException(
        'VanaDeck payload has ${_end - _offset} trailing bytes.',
      );
    }
  }

  int _readByte() {
    if (_offset >= _end) {
      throw const FormatException('Unexpected end of VanaDeck payload.');
    }
    return _bytes[_offset++];
  }

  int _readVarUint() {
    var value = 0;
    var shift = 0;

    while (true) {
      final byte = _readByte();
      value |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) {
        return value;
      }
      shift += 7;
      if (shift > 63) {
        throw const FormatException('VanaDeck varuint is too large.');
      }
    }
  }

  String _readStringPayload() {
    final length = _readVarUint();
    final end = _offset + length;
    if (end > _end) {
      throw const FormatException('VanaDeck string payload is truncated.');
    }
    final value = utf8.decode(
      _bytes.sublist(_offset, end),
      allowMalformed: true,
    );
    _offset = end;
    return value;
  }
}
