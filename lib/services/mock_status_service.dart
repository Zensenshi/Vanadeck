import '../models/party_member.dart';
import '../models/player_status.dart';

class MockStatusService {
  const MockStatusService();

  PlayerStatus getPlayerStatus() {
    return const PlayerStatus(
      name: 'Aldwyn',
      job: 'WAR',
      subjob: 'NIN',
      currentHp: 1284,
      maxHp: 1540,
      currentMp: 436,
      maxMp: 612,
      tp: 1247,
      level: 75,
      currentExp: 32650,
      expToNextLevel: 4850,
      activeBuffs: [
        PlayerBuff(id: 33, iconId: 33, name: 'Haste'),
        PlayerBuff(id: 40, iconId: 40, name: 'Protect'),
        PlayerBuff(id: 41, iconId: 41, name: 'Shell'),
        PlayerBuff(id: 43, iconId: 43, name: 'Refresh'),
      ],
      activeMacroBook: 2,
      activeMacroSet: 4,
      partyMembers: [
        PartyMember(
          name: 'Lyra',
          job: 'WHM',
          subjob: 'RDM',
          location: 'Upper Jeuno',
          locationX: 0.25,
          locationY: 0.33,
          level: 75,
          currentHp: 982,
          maxHp: 1044,
          currentMp: 512,
          maxMp: 622,
          activeBuffs: [
            PlayerBuff(id: 33, iconId: 33, name: 'Haste', remainingSeconds: 92),
            PlayerBuff(id: 43, iconId: 43, name: 'Refresh'),
          ],
        ),
        PartyMember(
          name: 'Bram',
          job: 'PLD',
          subjob: 'MNK',
          location: 'Ruined Gardens',
          locationX: 0.57,
          locationY: 0.48,
          level: 75,
          currentHp: 1688,
          maxHp: 1762,
          currentMp: 198,
          maxMp: 212,
          activeBuffs: [
            PlayerBuff(id: 40, iconId: 40, name: 'Protect'),
            PlayerBuff(id: 41, iconId: 41, name: 'Shell'),
          ],
        ),
        PartyMember(
          name: 'Sera',
          job: 'BLM',
          subjob: 'BLU',
          location: 'West Ronfaure',
          locationX: 0.17,
          locationY: 0.68,
          level: 75,
          currentHp: 734,
          maxHp: 914,
          currentMp: 683,
          maxMp: 742,
        ),
        PartyMember(
          name: 'Tavian',
          job: 'BRD',
          subjob: 'DNC',
          location: 'North Gustaberg',
          locationX: 0.68,
          locationY: 0.62,
          level: 75,
          currentHp: 1196,
          maxHp: 1288,
          currentMp: 274,
          maxMp: 312,
        ),
      ],
    );
  }
}
