import '../models/macro.dart';

class MockMacroService {
  const MockMacroService();

  static const int macroBookCount = 20;
  static const int macroSetCount = 10;

  List<Macro> getMacrosForBook(int bookNumber, {int setNumber = 1}) {
    assert(bookNumber >= 1 && bookNumber <= macroBookCount);
    assert(setNumber >= 1 && setNumber <= macroSetCount);

    final baseSlot = (setNumber - 1) * 10;

    return [
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_1',
        slot: baseSlot + 1,
        name: 'Attack',
        icon: '⚔',
        commands: ['/attack <t>', '/equipset 1'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_2',
        slot: baseSlot + 2,
        name: 'Heal',
        icon: '✚',
        commands: ['/ma "Cure" <t>', '/wait 2', '/jobability'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_3',
        slot: baseSlot + 3,
        name: 'Buff',
        icon: '★',
        commands: ['/ma "Haste" <t>', '/ma "Protect" <t>'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_4',
        slot: baseSlot + 4,
        name: 'Weapon Skill',
        icon: '◆',
        commands: ['/weaponskill <t>'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_5',
        slot: baseSlot + 5,
        name: 'Ability',
        icon: '●',
        commands: ['/jobability <t>', '/wait 1'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_6',
        slot: baseSlot + 6,
        name: 'Support',
        icon: '◇',
        commands: ['/assist <t>', '/ta'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_7',
        slot: baseSlot + 7,
        name: 'Emergency',
        icon: '⚡',
        commands: ['/ma "Teleport" <me>'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_8',
        slot: baseSlot + 8,
        name: 'Item',
        icon: '⊕',
        commands: ['/item "Potion" <me>'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_9',
        slot: baseSlot + 9,
        name: 'Toggle',
        icon: '↔',
        commands: ['/equip main "Sword"', '/equip sub "Shield"'],
      ),
      Macro(
        id: 'macro_${bookNumber}_${setNumber}_10',
        slot: baseSlot + 10,
        name: 'Party',
        icon: '◉',
        commands: ['/party', '/invite <t>'],
      ),
    ];
  }
}
