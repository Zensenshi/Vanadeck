import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/party_member.dart';
import '../models/player_status.dart';
import 'map_service.dart';

class GameStatusService {
  const GameStatusService({
    this.host = '127.0.0.1',
    this.port = 8080,
    Duration? timeout,
  }) : timeout = timeout ?? const Duration(seconds: 4);

  final String host;
  final int port;
  final Duration timeout;

  static final _statusController = StreamController<PlayerStatus>.broadcast();
  static Future<void>? _listenerFuture;
  static PlayerStatus? _latestStatus;
  static final Set<Socket> _commandSockets = {};

  Future<PlayerStatus> getPlayerStatus() async {
    return statusStream.first.timeout(timeout);
  }

  Stream<PlayerStatus> get statusStream async* {
    _ensureListening();

    final latestStatus = _latestStatus;
    if (latestStatus != null) {
      yield latestStatus;
    }

    yield* _statusController.stream;
  }

  Future<void> sendCommands(Iterable<String> commands) async {
    final encodedCommands = commands
        .expand((command) => command.split('\n'))
        .map((command) => command.trim())
        .where((command) => command.isNotEmpty)
        .map((command) => utf8.encode('$command\n'))
        .toList();
    if (encodedCommands.isEmpty) {
      return;
    }
    if (_commandSockets.isEmpty) {
      throw StateError('No game connection is available.');
    }

    final sockets = List<Socket>.of(_commandSockets);
    for (final socket in sockets) {
      try {
        for (final command in encodedCommands) {
          socket.add(command);
        }
        await socket.flush();
      } catch (_) {
        _commandSockets.remove(socket);
      }
    }
  }

  Future<void> sendChatMessage(String message) {
    return sendCommands([message]);
  }

  void _ensureListening() {
    _listenerFuture ??= _listenForStatus();
  }

  Future<void> _listenForStatus() async {
    ServerSocket? server;
    RawDatagramSocket? statusSocket;
    StreamSubscription<RawSocketEvent>? statusSubscription;

    try {
      final udpSocket = await RawDatagramSocket.bind(
        host,
        port,
        reuseAddress: true,
      );
      statusSocket = udpSocket;
      statusSubscription = udpSocket.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }

        for (
          var datagram = udpSocket.receive();
          datagram != null;
          datagram = udpSocket.receive()
        ) {
          _handleStatusPayload(datagram.data);
        }
      });

      server = await ServerSocket.bind(host, port, shared: true);
      await for (final socket in server) {
        _readStatusSocket(socket);
      }
    } catch (error, stackTrace) {
      _statusController.addError(error, stackTrace);
      _listenerFuture = null;
    } finally {
      await statusSubscription?.cancel();
      statusSocket?.close();
      await server?.close();
    }
  }

  void _readStatusSocket(Socket socket) {
    unawaited(_handleStatusSocket(socket));
  }

  Future<void> _handleStatusSocket(Socket socket) async {
    _commandSockets.add(socket);
    try {
      await for (final line
          in socket
              .cast<List<int>>()
              .transform(const Utf8Decoder(allowMalformed: true))
              .transform(const LineSplitter())) {
        _handleStatusLine(line);
      }
    } finally {
      _commandSockets.remove(socket);
      await socket.close();
    }
  }

  void _handleStatusPayload(List<int> payload) {
    final text = utf8.decode(payload, allowMalformed: true).trim();
    if (text.isEmpty) {
      return;
    }

    for (final line in const LineSplitter().convert(text)) {
      _handleStatusLine(line);
    }
  }

  void _handleStatusLine(String line) {
    if (line.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return;
      }
      final status = _fromJson(decoded.cast<String, dynamic>());
      if (status == null) {
        return;
      }
      _latestStatus = status;
      _statusController.add(status);
    } catch (_) {
      return;
    }
  }

  PlayerStatus? _fromJson(Map<String, dynamic> json) {
    final playerJson = _nestedMap(json['player']) ?? json;
    final partyJson =
        _listValue(json['partyMembers']) ?? _listValue(json['party']);
    if (!_hasCrediblePlayerPayload(json, playerJson, partyJson)) {
      return null;
    }

    final currentHp =
        _intValue(playerJson['currentHp']) ??
        _intValue(playerJson['hp']) ??
        _intValue(_nestedValue(playerJson['hp'], 'current')) ??
        _intValue(playerJson['hp_current']) ??
        0;
    final currentMp =
        _intValue(playerJson['currentMp']) ??
        _intValue(playerJson['mp']) ??
        _intValue(_nestedValue(playerJson['mp'], 'current')) ??
        _intValue(playerJson['mp_current']) ??
        0;
    final hpPercent =
        _doubleValue(playerJson['hpPercent']) ??
        _doubleValue(playerJson['hp_percent']);
    final mpPercent =
        _doubleValue(playerJson['mpPercent']) ??
        _doubleValue(playerJson['mp_percent']);
    final activeTarget = _activeTarget(json, playerJson);
    final isSubTargetActive =
        _boolValue(playerJson['isSubTargetActive']) ??
        _boolValue(playerJson['is_sub_target_active']) ??
        _boolValue(json['isSubTargetActive']) ??
        _boolValue(json['is_sub_target_active']) ??
        activeTarget?.isSubTargetActive ??
        false;
    final currentExp =
        _intValue(playerJson['currentExp']) ??
        _intValue(playerJson['current_exp']) ??
        _intValue(playerJson['exp']) ??
        _intValue(playerJson['experience']) ??
        _intValue(playerJson['xp']) ??
        _intValue(json['currentExp']) ??
        _intValue(json['current_exp']) ??
        0;
    final expNeeded =
        _intValue(playerJson['expNeeded']) ??
        _intValue(playerJson['exp_needed']) ??
        _intValue(playerJson['expMax']) ??
        _intValue(playerJson['exp_max']) ??
        _intValue(json['expNeeded']) ??
        _intValue(json['exp_needed']);
    final expToNextLevel =
        _intValue(playerJson['expToNextLevel']) ??
        _intValue(playerJson['exp_to_next_level']) ??
        _intValue(playerJson['expToNext']) ??
        _intValue(playerJson['exp_to_next']) ??
        _intValue(playerJson['tnl']) ??
        _intValue(json['expToNextLevel']) ??
        _intValue(json['exp_to_next_level']) ??
        _intValue(json['tnl']) ??
        (expNeeded == null
            ? null
            : (expNeeded - currentExp).clamp(0, expNeeded));

    return PlayerStatus(
      name: playerJson['name'] as String? ?? '',
      job: playerJson['job'] as String? ?? '',
      subjob: playerJson['subjob'] as String? ?? '',
      currentHp: currentHp,
      maxHp:
          _intValue(playerJson['maxHp']) ??
          _intValue(_nestedValue(playerJson['hp'], 'max')) ??
          _intValue(playerJson['hp_max']) ??
          _maxFromPercent(currentHp, hpPercent),
      currentMp: currentMp,
      maxMp:
          _intValue(playerJson['maxMp']) ??
          _intValue(_nestedValue(playerJson['mp'], 'max')) ??
          _intValue(playerJson['mp_max']) ??
          _maxFromPercent(currentMp, mpPercent),
      tp:
          _intValue(playerJson['tp']) ??
          _intValue(playerJson['tp_current']) ??
          0,
      level:
          _intValue(playerJson['level']) ??
          _intValue(playerJson['mainJobLevel']) ??
          _intValue(playerJson['main_job_level']) ??
          _intValue(json['level']) ??
          1,
      currentExp: currentExp,
      expToNextLevel: expToNextLevel ?? 0,
      activeBuffs: _activeBuffs(json, playerJson),
      activeMacroBook: _activeMacroBook(json, playerJson),
      activeMacroSet: _activeMacroSet(json, playerJson),
      macroNames: _macroNames(json, playerJson),
      macroNeedsTarget: _macroNeedsTarget(json, playerJson),
      activeTarget: activeTarget,
      isSubTargetActive: isSubTargetActive,
      chatMessages: _chatMessages(json),
      mapEntities: _mapEntities(json),
      castState: _castState(json, playerJson),
      partyMembers: partyJson == null
          ? const []
          : partyJson
                .map(_nestedMap)
                .nonNulls
                .map(_partyMemberFromJson)
                .toList(),
    );
  }

  bool _hasCrediblePlayerPayload(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
    List<dynamic>? partyJson,
  ) {
    final playerEntityReady =
        _boolValue(rootJson['playerEntityReady']) ??
        _boolValue(playerJson['playerEntityReady']) ??
        _boolValue(playerJson['entityReady']);
    if (playerEntityReady == false) {
      return false;
    }

    final name = (playerJson['name'] as String? ?? '').trim();
    if (name.isEmpty) {
      return false;
    }

    if (partyJson != null) {
      if (partyJson.isEmpty) {
        return false;
      }
      final firstMember = _nestedMap(partyJson.first);
      if (firstMember == null) {
        return false;
      }
      final firstName = (firstMember['name'] as String? ?? '').trim();
      if (firstName.isEmpty) {
        return false;
      }
    }

    return _intValue(playerJson['currentHp']) != null ||
        _intValue(playerJson['hp']) != null ||
        _intValue(_nestedValue(playerJson['hp'], 'current')) != null ||
        _intValue(playerJson['currentMp']) != null ||
        _intValue(playerJson['mp']) != null ||
        _intValue(playerJson['tp']) != null ||
        _intValue(playerJson['level']) != null;
  }

  List<MapEntityLocation> _mapEntities(Map<String, dynamic> rootJson) {
    if (!rootJson.containsKey('npcs') && !rootJson.containsKey('mobs')) {
      return _latestStatus?.mapEntities ?? const [];
    }

    final entities = <MapEntityLocation>[];
    final npcJson = rootJson['npcs'];
    final mobJson = rootJson['mobs'];

    if (npcJson is List) {
      entities.addAll(
        npcJson.map((entityJson) {
          if (entityJson is! Map) {
            return null;
          }
          return _mapEntityFromJson(entityJson.cast<String, dynamic>());
        }).nonNulls,
      );
    }

    if (mobJson is List) {
      entities.addAll(
        mobJson.map((entityJson) {
          if (entityJson is! Map) {
            return null;
          }
          final entityMap = entityJson.cast<String, dynamic>();
          return _mapEntityFromJson(
            entityMap,
            defaultType: 2,
            defaultKind: 'mob',
          );
        }).nonNulls,
      );
    }

    return entities;
  }

  PlayerCastState? _castState(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
  ) {
    final castJson =
        _nestedMap(rootJson['cast']) ??
        _nestedMap(rootJson['castBar']) ??
        _nestedMap(rootJson['cast_bar']) ??
        _nestedMap(rootJson['casting']) ??
        _nestedMap(playerJson['cast']) ??
        _nestedMap(playerJson['castBar']) ??
        _nestedMap(playerJson['cast_bar']) ??
        _nestedMap(playerJson['casting']);
    if (castJson == null) {
      return null;
    }

    final progress = _normalizedProgress(
      castJson['progress'] ??
          castJson['percent'] ??
          castJson['castPercent'] ??
          castJson['cast_percent'],
    );
    final count =
        _doubleValue(castJson['count']) ?? _doubleValue(castJson['remaining']);
    final max =
        _doubleValue(castJson['max']) ??
        _doubleValue(castJson['duration']) ??
        _doubleValue(castJson['total']);
    final isCasting =
        _boolValue(castJson['isCasting']) ??
        _boolValue(castJson['is_casting']) ??
        _boolValue(castJson['active']) ??
        ((count != null && count > 0) ||
            (max != null && max > 0 && progress != null && progress > 0));

    return PlayerCastState(
      isCasting: isCasting,
      progress: progress,
      count: count,
      max: max,
      castType: _intValue(castJson['castType']) ?? _intValue(castJson['type']),
    );
  }

  ActiveTarget? _activeTarget(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
  ) {
    final targetJson =
        _nestedMap(rootJson['target']) ??
        _nestedMap(rootJson['activeTarget']) ??
        _nestedMap(rootJson['active_target']) ??
        _nestedMap(playerJson['target']) ??
        _nestedMap(playerJson['activeTarget']) ??
        _nestedMap(playerJson['active_target']);
    if (targetJson == null) {
      return null;
    }

    final name =
        targetJson['name'] as String? ??
        targetJson['targetName'] as String? ??
        targetJson['target_name'] as String? ??
        '';
    if (name.trim().isEmpty) {
      return null;
    }

    return ActiveTarget(
      name: name.trim(),
      kind: _targetKind(targetJson),
      type: _intValue(targetJson['type']),
      hpPercent:
          _doubleValue(targetJson['hpPercent']) ??
          _doubleValue(targetJson['hp_percent']),
      currentHp:
          _intValue(targetJson['currentHp']) ??
          _intValue(targetJson['hp']) ??
          _intValue(_nestedValue(targetJson['hp'], 'current')) ??
          _intValue(targetJson['hp_current']),
      maxHp:
          _intValue(targetJson['maxHp']) ??
          _intValue(_nestedValue(targetJson['hp'], 'max')) ??
          _intValue(targetJson['hp_max']),
      currentMp:
          _intValue(targetJson['currentMp']) ??
          _intValue(targetJson['mp']) ??
          _intValue(_nestedValue(targetJson['mp'], 'current')) ??
          _intValue(targetJson['mp_current']),
      maxMp:
          _intValue(targetJson['maxMp']) ??
          _intValue(_nestedValue(targetJson['mp'], 'max')) ??
          _intValue(targetJson['mp_max']),
      isSubTargetActive:
          _boolValue(targetJson['isSubTargetActive']) ??
          _boolValue(targetJson['is_sub_target_active']) ??
          false,
    );
  }

  TargetKind _targetKind(Map<String, dynamic> targetJson) {
    final kind = (targetJson['kind'] ?? targetJson['targetKind'])
        ?.toString()
        .toLowerCase();
    switch (kind) {
      case 'mob':
      case 'monster':
        return TargetKind.mob;
      case 'party':
      case 'player':
      case 'pc':
        return TargetKind.party;
      case 'npc':
        return TargetKind.npc;
    }

    final type = _intValue(targetJson['type']);
    if (type == 1) {
      return TargetKind.npc;
    }
    if (type == 2) {
      return TargetKind.mob;
    }
    return TargetKind.unknown;
  }

  List<ChatMessage> _chatMessages(Map<String, dynamic> rootJson) {
    final hasChatMessages =
        rootJson.containsKey('chatMessages') ||
        rootJson.containsKey('chat') ||
        rootJson.containsKey('messages');
    if (!hasChatMessages) {
      return _latestStatus?.chatMessages ?? const [];
    }

    final chatJson =
        rootJson['chatMessages'] ?? rootJson['chat'] ?? rootJson['messages'];
    if (chatJson is! List) {
      return _latestStatus?.chatMessages ?? const [];
    }

    final messages = chatJson
        .map((messageJson) {
          if (messageJson is String) {
            return ChatMessage(
              id: null,
              text: messageJson,
              mode: 0,
              receivedAt: DateTime.now(),
            );
          }
          if (messageJson is! Map) {
            return null;
          }

          final messageMap = messageJson.cast<String, dynamic>();
          final text =
              messageMap['text'] as String? ??
              messageMap['message'] as String? ??
              '';
          if (text.trim().isEmpty) {
            return null;
          }

          final timestamp =
              _doubleValue(messageMap['time']) ??
              _doubleValue(messageMap['timestamp']);
          return ChatMessage(
            id: _intValue(messageMap['id']) ?? _intValue(messageMap['seq']),
            text: text,
            mode:
                _intValue(messageMap['mode']) ??
                _intValue(messageMap['messageMode']) ??
                0,
            colorArgb:
                _colorValue(messageMap['color']) ??
                _colorValue(messageMap['textColor']) ??
                _colorValue(messageMap['text_color']) ??
                _colorValue(messageMap['colorArgb']) ??
                _colorValue(messageMap['color_argb']),
            receivedAt: timestamp == null
                ? DateTime.now()
                : DateTime.fromMillisecondsSinceEpoch(
                    (timestamp * 1000).round(),
                  ),
            direction: _chatMessageDirection(messageMap['direction']),
            blocked: messageMap['blocked'] == true,
          );
        })
        .nonNulls
        .toList();
    final incremental =
        _boolValue(rootJson['chatIncremental']) ??
        _boolValue(rootJson['chat_incremental']) ??
        false;
    final snapshot =
        _boolValue(rootJson['chatSnapshot']) ??
        _boolValue(rootJson['chat_snapshot']) ??
        _boolValue(rootJson['chatReset']) ??
        _boolValue(rootJson['chat_reset']) ??
        false;
    if (!incremental || snapshot) {
      return messages;
    }

    return _mergeChatMessages(
      _latestStatus?.chatMessages ?? const [],
      messages,
    );
  }

  List<ChatMessage> _mergeChatMessages(
    List<ChatMessage> existing,
    List<ChatMessage> updates,
  ) {
    if (existing.isEmpty) {
      return _trimChatMessages(updates);
    }
    if (updates.isEmpty) {
      return existing;
    }

    final merged = List<ChatMessage>.of(existing);
    for (final update in updates) {
      final id = update.id;
      if (id != null) {
        merged.removeWhere((message) => message.id == id);
      }
      merged.add(update);
    }
    merged.sort((a, b) {
      final aId = a.id;
      final bId = b.id;
      if (aId != null && bId != null) {
        return aId.compareTo(bId);
      }
      return a.receivedAt.compareTo(b.receivedAt);
    });
    return _trimChatMessages(merged);
  }

  List<ChatMessage> _trimChatMessages(List<ChatMessage> messages) {
    const maxMessages = 80;
    if (messages.length <= maxMessages) {
      return messages;
    }
    return messages.sublist(messages.length - maxMessages);
  }

  ChatMessageDirection _chatMessageDirection(dynamic value) {
    final direction = value?.toString().toLowerCase();
    if (direction == 'out' ||
        direction == 'outgoing' ||
        direction == 'sent' ||
        direction == 'local') {
      return ChatMessageDirection.outgoing;
    }

    return ChatMessageDirection.incoming;
  }

  List<PlayerBuff> _activeBuffs(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
  ) {
    final buffsJson =
        playerJson['activeBuffs'] ??
        playerJson['buffs'] ??
        playerJson['statuses'] ??
        playerJson['statusEffects'] ??
        playerJson['status_effects'] ??
        playerJson['statusIcons'] ??
        playerJson['status_icons'] ??
        rootJson['activeBuffs'] ??
        rootJson['buffs'] ??
        rootJson['statuses'] ??
        rootJson['statusEffects'] ??
        rootJson['status_effects'] ??
        rootJson['statusIcons'] ??
        rootJson['status_icons'];
    if (buffsJson is! List) {
      return const [];
    }

    return buffsJson.map(_buffFromJson).nonNulls.toList();
  }

  PlayerBuff? _buffFromJson(dynamic buffJson) {
    if (buffJson is Map) {
      final buffMap = buffJson.cast<String, dynamic>();
      final id =
          _intValue(buffMap['id']) ??
          _intValue(buffMap['buffId']) ??
          _intValue(buffMap['buff_id']) ??
          _intValue(buffMap['iconId']) ??
          _intValue(buffMap['icon_id']);
      if (id == null || id <= 0) {
        return null;
      }
      final iconId =
          _intValue(buffMap['iconId']) ??
          _intValue(buffMap['icon_id']) ??
          _intValue(buffMap['icon']);
      return PlayerBuff(
        id: id,
        iconId: iconId,
        name: buffMap['name'] as String?,
        remainingSeconds:
            _intValue(buffMap['remainingSeconds']) ??
            _intValue(buffMap['remaining_seconds']) ??
            _intValue(buffMap['timeRemaining']) ??
            _intValue(buffMap['time_remaining']) ??
            _intValue(buffMap['timer']) ??
            _intValue(buffMap['duration']),
      );
    }

    final id = _intValue(buffJson);
    if (id == null || id <= 0) {
      return null;
    }
    return PlayerBuff(id: id);
  }

  int _activeMacroBook(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
  ) {
    final macroJson =
        _nestedMap(rootJson['macro']) ??
        _nestedMap(rootJson['macros']) ??
        _nestedMap(playerJson['macro']) ??
        _nestedMap(playerJson['macros']);
    final value =
        _intValue(rootJson['activeMacroBook']) ??
        _intValue(rootJson['currentMacroBook']) ??
        _intValue(rootJson['macroBook']) ??
        _intValue(rootJson['active_macro_book']) ??
        _intValue(rootJson['current_macro_book']) ??
        _intValue(rootJson['macro_book']) ??
        _intValue(playerJson['activeMacroBook']) ??
        _intValue(playerJson['currentMacroBook']) ??
        _intValue(playerJson['macroBook']) ??
        _intValue(playerJson['active_macro_book']) ??
        _intValue(playerJson['current_macro_book']) ??
        _intValue(playerJson['macro_book']) ??
        _intValue(macroJson?['activeBook']) ??
        _intValue(macroJson?['currentBook']) ??
        _intValue(macroJson?['book']) ??
        _intValue(macroJson?['active_book']) ??
        _intValue(macroJson?['current_book']);

    return (value ?? 1).clamp(1, 999).toInt();
  }

  int _activeMacroSet(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
  ) {
    final macroJson =
        _nestedMap(rootJson['macro']) ??
        _nestedMap(rootJson['macros']) ??
        _nestedMap(playerJson['macro']) ??
        _nestedMap(playerJson['macros']);
    final value =
        _intValue(rootJson['activeMacroSet']) ??
        _intValue(rootJson['currentMacroSet']) ??
        _intValue(rootJson['macroSet']) ??
        _intValue(rootJson['active_macro_set']) ??
        _intValue(rootJson['current_macro_set']) ??
        _intValue(rootJson['macro_set']) ??
        _intValue(playerJson['activeMacroSet']) ??
        _intValue(playerJson['currentMacroSet']) ??
        _intValue(playerJson['macroSet']) ??
        _intValue(playerJson['active_macro_set']) ??
        _intValue(playerJson['current_macro_set']) ??
        _intValue(playerJson['macro_set']) ??
        _intValue(macroJson?['activeSet']) ??
        _intValue(macroJson?['currentSet']) ??
        _intValue(macroJson?['set']) ??
        _intValue(macroJson?['active_set']) ??
        _intValue(macroJson?['current_set']);

    return (value ?? 1).clamp(1, 999).toInt();
  }

  List<String> _macroNames(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
  ) {
    final macroJson =
        _nestedMap(rootJson['macro']) ??
        _nestedMap(rootJson['macros']) ??
        _nestedMap(playerJson['macro']) ??
        _nestedMap(playerJson['macros']);
    final namesJson =
        rootJson['macroNames'] ??
        rootJson['macro_names'] ??
        playerJson['macroNames'] ??
        playerJson['macro_names'] ??
        macroJson?['names'] ??
        macroJson?['macroNames'] ??
        macroJson?['macro_names'];

    if (namesJson is! List) {
      return _latestStatus?.macroNames ?? const [];
    }

    return namesJson.map((name) => name?.toString().trim() ?? '').toList();
  }

  List<bool> _macroNeedsTarget(
    Map<String, dynamic> rootJson,
    Map<String, dynamic> playerJson,
  ) {
    final macroJson =
        _nestedMap(rootJson['macro']) ??
        _nestedMap(rootJson['macros']) ??
        _nestedMap(playerJson['macro']) ??
        _nestedMap(playerJson['macros']);
    final targetJson =
        rootJson['macroNeedsTarget'] ??
        rootJson['macro_needs_target'] ??
        playerJson['macroNeedsTarget'] ??
        playerJson['macro_needs_target'] ??
        macroJson?['needsTarget'] ??
        macroJson?['needs_target'] ??
        macroJson?['targeted'];

    if (targetJson is! List) {
      return _latestStatus?.macroNeedsTarget ?? const [];
    }

    return targetJson.map((value) => _boolValue(value) ?? false).toList();
  }

  int? _intValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  int? _colorValue(dynamic value) {
    if (value is num) {
      final color = value.toInt();
      return color <= 0xFFFFFF ? 0xFF000000 | color : color;
    }
    if (value is String) {
      final normalized = value.trim().replaceFirst(RegExp('^#'), '');
      final parsed = int.tryParse(normalized, radix: 16) ?? int.tryParse(value);
      if (parsed == null) {
        return null;
      }
      return parsed <= 0xFFFFFF ? 0xFF000000 | parsed : parsed;
    }
    return null;
  }

  bool? _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final text = value.toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') {
        return true;
      }
      if (text == 'false' || text == '0' || text == 'no') {
        return false;
      }
    }
    return null;
  }

  double? _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  double? _normalizedProgress(dynamic value) {
    final progress = _doubleValue(value);
    if (progress == null) {
      return null;
    }
    if (progress > 1) {
      return (progress / 100).clamp(0.0, 1.0).toDouble();
    }
    return progress.clamp(0.0, 1.0).toDouble();
  }

  dynamic _nestedValue(dynamic value, String key) {
    if (value is Map<String, dynamic>) {
      return value[key];
    }
    if (value is Map) {
      return value[key];
    }
    return null;
  }

  Map<String, dynamic>? _nestedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  List<dynamic>? _listValue(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return null;
  }

  int _maxFromPercent(int current, double? percent) {
    if (percent == null || percent <= 0) {
      return current;
    }
    return (current * 100 / percent).round();
  }

  PartyMember _partyMemberFromJson(Map<String, dynamic> json) {
    final currentHp =
        _intValue(json['currentHp']) ??
        _intValue(json['hp']) ??
        _intValue(_nestedValue(json['hp'], 'current')) ??
        _intValue(json['hp_current']) ??
        0;
    final hpPercent =
        _doubleValue(json['hpPercent']) ?? _doubleValue(json['hp_percent']);

    final currentMp =
        _intValue(json['currentMp']) ??
        _intValue(json['mp']) ??
        _intValue(_nestedValue(json['mp'], 'current')) ??
        _intValue(json['mp_current']) ??
        0;
    final mpPercent =
        _doubleValue(json['mpPercent']) ?? _doubleValue(json['mp_percent']);

    return PartyMember(
      name: json['name'] as String? ?? '',
      job: json['job'] as String? ?? '',
      subjob: json['subjob'] as String? ?? '',
      location: json['location'] as String? ?? 'Unknown',
      locationX: _mapX(json),
      locationY: _mapY(json),
      level: (json['level'] as num?)?.toInt() ?? 1,
      currentHp: currentHp,
      maxHp:
          _intValue(json['maxHp']) ??
          _intValue(_nestedValue(json['hp'], 'max')) ??
          _intValue(json['hp_max']) ??
          _maxFromPercent(currentHp, hpPercent),
      currentMp: currentMp,
      maxMp:
          _intValue(json['maxMp']) ??
          _intValue(_nestedValue(json['mp'], 'max')) ??
          _intValue(json['mp_max']) ??
          _maxFromPercent(currentMp, mpPercent),
      worldX: _doubleValue(json['worldX']),
      worldY: _doubleValue(json['worldY']),
      worldZ: _doubleValue(json['worldZ']),
      heading: _doubleValue(json['heading']),
      zoneId: _intValue(json['zoneId']),
      subMapNum: _intValue(json['subMapNum']),
      activeBuffs: _partyMemberBuffs(json),
    );
  }

  MapEntityLocation _mapEntityFromJson(
    Map<String, dynamic> json, {
    int? defaultType,
    String? defaultKind,
  }) {
    return MapEntityLocation(
      name: json['name'] as String? ?? '',
      type: _intValue(json['type']) ?? defaultType ?? 1,
      location: json['location'] as String? ?? 'Unknown',
      locationX: _mapX(json),
      locationY: _mapY(json),
      kind: json['kind'] as String? ?? defaultKind,
      hpPercent:
          _doubleValue(json['hpPercent']) ?? _doubleValue(json['hp_percent']),
      worldX: _doubleValue(json['worldX']),
      worldY: _doubleValue(json['worldY']),
      worldZ: _doubleValue(json['worldZ']),
      heading: _doubleValue(json['heading']),
      zoneId: _intValue(json['zoneId']),
      subMapNum: _intValue(json['subMapNum']),
    );
  }

  List<PlayerBuff> _partyMemberBuffs(Map<String, dynamic> json) {
    final buffsJson =
        json['activeBuffs'] ??
        json['buffs'] ??
        json['statuses'] ??
        json['statusEffects'] ??
        json['status_effects'] ??
        json['statusIcons'] ??
        json['status_icons'];
    if (buffsJson is! List) {
      return const [];
    }

    return buffsJson.map(_buffFromJson).nonNulls.toList();
  }

  double _mapX(Map<String, dynamic> json) {
    final worldX = _doubleValue(json['worldX']);
    if (worldX != null) {
      final zoneName = json['location'] as String? ?? '';
      final worldZ = _doubleValue(json['worldZ']) ?? 0.0;
      return MapService.worldToMap(
        zoneName: zoneName,
        zoneId: _intValue(json['zoneId']),
        subMapNum: _intValue(json['subMapNum']),
        worldX: worldX,
        worldY: _doubleValue(json['worldY']),
        worldZ: worldZ,
      ).x;
    }

    return (json['locationX'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5;
  }

  double _mapY(Map<String, dynamic> json) {
    final worldMapY =
        _doubleValue(json['worldY']) ?? _doubleValue(json['worldZ']);
    if (worldMapY != null) {
      final zoneName = json['location'] as String? ?? '';
      final worldX = _doubleValue(json['worldX']) ?? 0.0;
      return MapService.worldToMap(
        zoneName: zoneName,
        zoneId: _intValue(json['zoneId']),
        subMapNum: _intValue(json['subMapNum']),
        worldX: worldX,
        worldY: _doubleValue(json['worldY']),
        worldZ: _doubleValue(json['worldZ']),
      ).y;
    }

    return (json['locationY'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5;
  }
}
