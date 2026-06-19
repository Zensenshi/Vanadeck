import 'status_effect.dart';

class PartyMember {
  const PartyMember({
    required this.name,
    required this.job,
    required this.subjob,
    required this.location,
    required this.locationX,
    required this.locationY,
    required this.level,
    required this.currentHp,
    required this.maxHp,
    required this.currentMp,
    required this.maxMp,
    this.worldX,
    this.worldY,
    this.worldZ,
    this.heading,
    this.zoneId,
    this.subMapNum,
    this.activeBuffs = const [],
  });

  final String name;
  final String job;
  final String subjob;
  final String location;
  final double locationX;
  final double locationY;
  final int level;
  final int currentHp;
  final int maxHp;
  final int currentMp;
  final int maxMp;
  final double? worldX;
  final double? worldY;
  final double? worldZ;
  final double? heading;
  final int? zoneId;
  final int? subMapNum;
  final List<PlayerBuff> activeBuffs;

  double get hpPercent => maxHp == 0 ? 0 : currentHp / maxHp;
  double get mpPercent => maxMp == 0 ? 0 : currentMp / maxMp;
}
