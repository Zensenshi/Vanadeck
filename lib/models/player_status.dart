import 'party_member.dart';
import 'status_effect.dart';

export 'status_effect.dart';

class PlayerStatus {
  const PlayerStatus({
    required this.name,
    required this.job,
    required this.subjob,
    required this.currentHp,
    required this.maxHp,
    required this.currentMp,
    required this.maxMp,
    required this.tp,
    required this.partyMembers,
    this.level = 1,
    this.currentExp = 0,
    this.expToNextLevel = 0,
    this.activeBuffs = const [],
    this.activeMacroBook = 1,
    this.activeMacroSet = 1,
    this.macroNames = const [],
    this.macroNeedsTarget = const [],
    this.chatMessages = const [],
    this.mapEntities = const [],
    this.activeTarget,
    this.isSubTargetActive = false,
  });

  final String name;
  final String job;
  final String subjob;
  final int currentHp;
  final int maxHp;
  final int currentMp;
  final int maxMp;
  final int tp;
  final int level;
  final int currentExp;
  final int expToNextLevel;
  final List<PartyMember> partyMembers;
  final List<PlayerBuff> activeBuffs;
  final int activeMacroBook;
  final int activeMacroSet;
  final List<String> macroNames;
  final List<bool> macroNeedsTarget;
  final List<ChatMessage> chatMessages;
  final List<MapEntityLocation> mapEntities;
  final ActiveTarget? activeTarget;
  final bool isSubTargetActive;

  double get hpPercent => maxHp == 0 ? 0 : currentHp / maxHp;

  double get mpPercent => maxMp == 0 ? 0 : currentMp / maxMp;

  double get expPercent {
    final total = currentExp + expToNextLevel;
    return total <= 0 ? 0 : currentExp / total;
  }
}

class ActiveTarget {
  const ActiveTarget({
    required this.name,
    required this.kind,
    this.type,
    this.hpPercent,
    this.currentHp,
    this.maxHp,
    this.currentMp,
    this.maxMp,
    this.isSubTargetActive = false,
  });

  final String name;
  final TargetKind kind;
  final int? type;
  final double? hpPercent;
  final int? currentHp;
  final int? maxHp;
  final int? currentMp;
  final int? maxMp;
  final bool isSubTargetActive;

  bool get isMob => kind == TargetKind.mob;
  bool get isParty => kind == TargetKind.party;
  bool get isNpc => kind == TargetKind.npc;
  double? get partyHpPercent => _percent(currentHp, maxHp);
  double? get partyMpPercent => _percent(currentMp, maxMp);

  double? _percent(int? current, int? max) {
    if (current == null || max == null || max <= 0) {
      return null;
    }
    return (current / max).clamp(0.0, 1.0);
  }
}

enum TargetKind { mob, party, npc, unknown }

class MapEntityLocation {
  const MapEntityLocation({
    required this.name,
    required this.type,
    required this.location,
    required this.locationX,
    required this.locationY,
    this.kind,
    this.hpPercent,
    this.worldX,
    this.worldY,
    this.worldZ,
    this.heading,
    this.zoneId,
    this.subMapNum,
  });

  final String name;
  final int type;
  final String location;
  final double locationX;
  final double locationY;
  final String? kind;
  final double? hpPercent;
  final double? worldX;
  final double? worldY;
  final double? worldZ;
  final double? heading;
  final int? zoneId;
  final int? subMapNum;

  bool get isNpc => !isMob && (type == 1 || type == 2);

  bool get isMob {
    if (type == 2) {
      return !_isTownZone(location);
    }

    final normalizedKind = kind?.toLowerCase();
    if (normalizedKind == 'mob' || normalizedKind == 'monster') {
      return true;
    }
    if (normalizedKind == 'npc') {
      return false;
    }

    return false;
  }

  bool _isTownZone(String zoneName) {
    return _townZones.contains(zoneName.toLowerCase());
  }

  static const Set<String> _townZones = {
    "southern san d'oria",
    "northern san d'oria",
    "port san d'oria",
    "chateau d'oraguille",
    'bastok mines',
    'bastok markets',
    'port bastok',
    'metalworks',
    'windurst waters',
    'windurst walls',
    'port windurst',
    'windurst woods',
    'heavens tower',
    "ru'lude gardens",
    'upper jeuno',
    'lower jeuno',
    'port jeuno',
    'aht urhgan whitegate',
    'al zahbi',
    'nashmau',
    'western adoulin',
    'eastern adoulin',
    'mog garden',
    'leafallia',
    'selbina',
    'mhaura',
    'rabao',
    'norg',
    'kazham',
    'tavnazian safehold',
  };
}

class ChatMessage {
  const ChatMessage({
    this.id,
    required this.text,
    required this.mode,
    required this.receivedAt,
    this.direction = ChatMessageDirection.incoming,
    this.blocked = false,
    this.colorArgb,
  });

  final int? id;
  final String text;
  final int mode;
  final DateTime receivedAt;
  final ChatMessageDirection direction;
  final bool blocked;
  final int? colorArgb;
}

enum ChatMessageDirection { incoming, outgoing }
