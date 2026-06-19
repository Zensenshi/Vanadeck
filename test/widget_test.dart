import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vanadeck/main.dart';
import 'package:vanadeck/models/party_member.dart';
import 'package:vanadeck/models/player_status.dart';
import 'package:vanadeck/screens/chat_screen.dart';
import 'package:vanadeck/screens/macro_screen.dart';
import 'package:vanadeck/screens/settings_screen.dart';
import 'package:vanadeck/screens/status_screen.dart';
import 'package:vanadeck/services/app_settings_controller.dart';

void main() {
  testWidgets('shows the primary navigation tabs', (tester) async {
    await tester.pumpWidget(const VanaDeckApp());

    expect(find.text('Status'), findsWidgets);
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Macros'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
  });

  testWidgets('navigation rail fits when keyboard shrinks the viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const VanaDeckApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('chat tab sends text from the composer', (tester) async {
    var sentMessage = '';

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: const Stream.empty(),
          settings: AppSettingsController(),
          sendChatMessage: (message) async {
            sentMessage = message;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hello Vana\'diel');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(sentMessage, 'Hello Vana\'diel');
    expect(
      find.textContaining('Hello Vana\'diel', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('chat tab sends slash commands without echoing them', (
    tester,
  ) async {
    var sentMessage = '';

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: const Stream.empty(),
          settings: AppSettingsController(),
          sendChatMessage: (message) async {
            sentMessage = message;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '/servmes');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(sentMessage, '/servmes');
    expect(find.textContaining('/servmes', findRichText: true), findsNothing);
  });

  testWidgets('chat tab throttles rapid sends', (tester) async {
    final sentMessages = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: const Stream.empty(),
          settings: AppSettingsController(),
          sendChatMessage: (message) async {
            sentMessages.add(message);
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'First');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Too fast');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(sentMessages, ['First']);
    expect(find.text('Ready in 2s'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2250));
    await tester.enterText(find.byType(TextField), 'Second');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(sentMessages, ['First', 'Second']);
  });

  testWidgets('chat tab uses game-provided message colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: Stream.value(
            PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: const [],
              chatMessages: [
                ChatMessage(
                  text: 'Testing game color',
                  mode: 0,
                  colorArgb: 0xFF00FFFF,
                  receivedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          settings: AppSettingsController(),
          sendChatMessage: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.textContaining('Testing game color'));
    final span = text.textSpan!;
    expect(span.style?.color, const Color(0xFF00FFFF));
  });

  testWidgets(
    'chat tab prefers known FFXI mode colors over white event color',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            statusStream: Stream.value(
              PlayerStatus(
                name: 'Aldwyn',
                job: 'RDM',
                subjob: 'THF',
                currentHp: 1284,
                maxHp: 1540,
                currentMp: 436,
                maxMp: 612,
                tp: 1247,
                partyMembers: const [],
                chatMessages: [
                  ChatMessage(
                    text: 'Party should be blue',
                    mode: 4,
                    colorArgb: 0xFFFFFFFF,
                    receivedAt: DateTime(2026),
                  ),
                ],
              ),
            ),
            settings: AppSettingsController(),
            sendChatMessage: (_) async {},
          ),
        ),
      );
      await tester.pump();

      final text = tester.widget<Text>(
        find.textContaining('Party should be blue'),
      );
      final span = text.textSpan!;
      expect(span.style?.color, ChatColorRole.party.defaultColor);
    },
  );

  testWidgets('chat tab recognizes Ashita party mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: Stream.value(
            PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: const [],
              chatMessages: [
                ChatMessage(
                  text: 'Ashita party mode should be blue',
                  mode: 13,
                  colorArgb: 0xFFFFFFFF,
                  receivedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          settings: AppSettingsController(),
          sendChatMessage: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(
      find.textContaining('Ashita party mode should be blue'),
    );
    final span = text.textSpan!;
    expect(span.style?.color, ChatColorRole.party.defaultColor);
  });

  testWidgets('chat tab uses custom chat role colors from settings', (
    tester,
  ) async {
    final settings = AppSettingsController(
      service: const _NoopSettingsService(),
    );
    await settings.setChatColor(ChatColorRole.party, const Color(0xFF4DA3FF));

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: Stream.value(
            PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: const [],
              chatMessages: [
                ChatMessage(
                  text: 'Custom party color',
                  mode: 13,
                  colorArgb: 0xFFFFFFFF,
                  receivedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          settings: settings,
          sendChatMessage: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.textContaining('Custom party color'));
    final span = text.textSpan!;
    expect(span.style?.color, const Color(0xFF4DA3FF));
  });

  testWidgets('chat tab treats mode 1 as say for custom colors', (
    tester,
  ) async {
    final settings = AppSettingsController(
      service: const _NoopSettingsService(),
    );
    await settings.setChatColor(ChatColorRole.say, Colors.white);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: Stream.value(
            PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: const [],
              chatMessages: [
                ChatMessage(
                  text: 'Mode 1 say color',
                  mode: 1,
                  colorArgb: 0xFFFF9C57,
                  receivedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          settings: settings,
          sendChatMessage: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.textContaining('Mode 1 say color'));
    expect(text.textSpan!.style?.color, Colors.white);
  });

  testWidgets('chat tab treats mode 5 as party for custom colors', (
    tester,
  ) async {
    final settings = AppSettingsController(
      service: const _NoopSettingsService(),
    );
    await settings.setChatColor(ChatColorRole.party, const Color(0xFF4DA3FF));
    await settings.setChatColor(
      ChatColorRole.linkshell,
      const Color(0xFF86F67C),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: Stream.value(
            PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: const [],
              chatMessages: [
                ChatMessage(
                  text: 'Mode 5 party color',
                  mode: 5,
                  colorArgb: 0xFFFFFFFF,
                  receivedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          settings: settings,
          sendChatMessage: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.textContaining('Mode 5 party color'));
    expect(text.textSpan!.style?.color, const Color(0xFF4DA3FF));
  });

  testWidgets('chat tab keeps mode 14 as linkshell for custom colors', (
    tester,
  ) async {
    final settings = AppSettingsController(
      service: const _NoopSettingsService(),
    );
    await settings.setChatColor(
      ChatColorRole.linkshell,
      const Color(0xFF40FF80),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: Stream.value(
            PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: const [],
              chatMessages: [
                ChatMessage(
                  text: 'Mode 14 linkshell color',
                  mode: 14,
                  colorArgb: 0xFFFFFFFF,
                  receivedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          settings: settings,
          sendChatMessage: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(
      find.textContaining('Mode 14 linkshell color'),
    );
    expect(text.textSpan!.style?.color, const Color(0xFF40FF80));
  });

  testWidgets('chat tab repaints when custom chat colors change', (
    tester,
  ) async {
    final settings = AppSettingsController(
      service: const _NoopSettingsService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          statusStream: Stream.value(
            PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: const [],
              chatMessages: [
                ChatMessage(
                  text: 'Live party color',
                  mode: 13,
                  colorArgb: 0xFFFFFFFF,
                  receivedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          settings: settings,
          sendChatMessage: (_) async {},
        ),
      ),
    );
    await tester.pump();

    Text text = tester.widget<Text>(find.textContaining('Live party color'));
    expect(text.textSpan!.style?.color, ChatColorRole.party.defaultColor);

    await settings.setChatColor(ChatColorRole.party, const Color(0xFF4DA3FF));
    await tester.pump();

    text = tester.widget<Text>(find.textContaining('Live party color'));
    expect(text.textSpan!.style?.color, const Color(0xFF4DA3FF));
  });

  test('requested chat color roles are exposed', () {
    expect(
      ChatColorRole.values.map((role) => role.label),
      unorderedEquals(const [
        'Say',
        'Shout',
        'Yell',
        'Tell',
        'Party',
        'Linkshell',
        'Linkshell 2',
        'Assist J',
        'Assist E',
        'Unity',
        'Emotes',
        'Messages',
        'NPC conversation',
      ]),
    );
  });

  test('invalid saved chat font falls back to Japanese Sans', () {
    expect(
      AppSettingsController.normalizeChatFontFamily('Libre Franklin'),
      AppSettingsController.defaultChatFontFamily,
    );
  });

  testWidgets('macros tab sends ctrl macro input slots', (tester) async {
    final executedCommands = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          executeCommands: (commands) async {
            executedCommands.addAll(commands);
          },
        ),
      ),
    );

    await tester.tap(find.text('Ctrl + 1'));
    await tester.pump();

    expect(executedCommands, ['__vanadeck_macro_input__:ctrl:1']);
  });

  testWidgets('macros tab labels buttons from game macro names', (
    tester,
  ) async {
    final executedCommands = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          statusStream: Stream.value(
            const PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: [],
              macroNames: [
                'Provoke',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                '',
                'Sneak',
              ],
            ),
          ),
          executeCommands: (commands) async {
            executedCommands.addAll(commands);
          },
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Macro Set Book 01 #1'), findsOneWidget);
    expect(find.text('Provoke'), findsOneWidget);
    expect(find.text('Ctrl + 1'), findsOneWidget);

    await tester.tap(find.text('Provoke'));
    await tester.pump();
    expect(executedCommands, ['__vanadeck_macro_input__:ctrl:1']);

    await tester.tap(find.text('Alt').first);
    await tester.pumpAndSettle();
    expect(find.text('Sneak'), findsOneWidget);
  });

  testWidgets('macros tab switches to alt page with segmented control', (
    tester,
  ) async {
    final executedCommands = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          executeCommands: (commands) async {
            executedCommands.addAll(commands);
          },
        ),
      ),
    );

    await tester.tap(find.text('Alt').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alt + 1'));
    await tester.pump();

    expect(executedCommands, ['__vanadeck_macro_input__:alt:1']);
  });

  testWidgets('macros tab changes ctrl and alt pages with horizontal swipes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MacroScreen(executeCommands: (_) async {})),
    );

    await tester.fling(find.text('Ctrl + 1'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Alt + 1'), findsOneWidget);

    await tester.fling(find.text('Alt + 1'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Ctrl + 1'), findsOneWidget);
  });

  testWidgets('macros tab sends in-game page cycle inputs', (tester) async {
    final executedCommands = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          executeCommands: (commands) async {
            executedCommands.addAll(commands);
          },
        ),
      ),
    );

    await tester.tap(find.text('Page Up'));
    await tester.pump();
    await tester.tap(find.text('Page Down'));
    await tester.pump();

    expect(executedCommands, [
      '__vanadeck_macro_input__:page_up',
      '__vanadeck_macro_input__:page_down',
    ]);
  });

  testWidgets('targeted macro party list queues selected party token', (
    tester,
  ) async {
    final executedCommands = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          statusStream: Stream.value(
            const PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              macroNeedsTarget: [true],
              partyMembers: [
                PartyMember(
                  name: 'Aldwyn',
                  job: 'RDM',
                  subjob: 'THF',
                  location: 'Bastok Markets',
                  locationX: 0.5,
                  locationY: 0.5,
                  level: 75,
                  currentHp: 1284,
                  maxHp: 1540,
                  currentMp: 436,
                  maxMp: 612,
                ),
                PartyMember(
                  name: 'Curilla',
                  job: 'PLD',
                  subjob: 'WAR',
                  location: 'Bastok Markets',
                  locationX: 0.5,
                  locationY: 0.5,
                  level: 75,
                  currentHp: 1500,
                  maxHp: 1700,
                  currentMp: 200,
                  maxMp: 350,
                ),
              ],
            ),
          ),
          executeCommands: (commands) async {
            executedCommands.addAll(commands);
          },
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Ctrl + 1'));
    await tester.pumpAndSettle();

    expect(executedCommands, isEmpty);
    expect(find.text('<p1>'), findsOneWidget);

    await tester.tap(find.text('Curilla'));
    await tester.pumpAndSettle();

    expect(executedCommands, ['__vanadeck_macro_input__:targeted:ctrl:1:1']);
    expect(find.text('Curilla'), findsNothing);
  });

  testWidgets('non-target macro long press stays key-bound', (tester) async {
    final executedCommands = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          statusStream: Stream.value(
            const PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              macroNeedsTarget: [false],
              partyMembers: [
                PartyMember(
                  name: 'Aldwyn',
                  job: 'RDM',
                  subjob: 'THF',
                  location: 'Bastok Markets',
                  locationX: 0.5,
                  locationY: 0.5,
                  level: 75,
                  currentHp: 1284,
                  maxHp: 1540,
                  currentMp: 436,
                  maxMp: 612,
                ),
              ],
            ),
          ),
          executeCommands: (commands) async {
            executedCommands.addAll(commands);
          },
        ),
      ),
    );

    await tester.pump();
    await tester.longPress(find.text('Ctrl + 1'));
    await tester.pumpAndSettle();

    expect(executedCommands, ['__vanadeck_macro_input__:ctrl:1']);
    expect(find.text('<p0>'), findsNothing);
  });

  testWidgets('macros tab shows active target status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          statusStream: Stream.value(
            const PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: [],
              activeTarget: ActiveTarget(
                name: 'Curilla',
                kind: TargetKind.party,
                currentHp: 1284,
                maxHp: 1540,
                currentMp: 436,
                maxMp: 612,
              ),
            ),
          ),
          executeCommands: (_) async {},
        ),
      ),
    );

    await tester.pump();

    expect(find.text('PARTY'), findsOneWidget);
    expect(find.text('Curilla'), findsOneWidget);
    expect(find.text('1284/1540'), findsOneWidget);
    expect(find.text('436/612'), findsOneWidget);
  });

  testWidgets('macros tab shows mob target hp percent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MacroScreen(
          statusStream: Stream.value(
            const PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: [],
              activeTarget: ActiveTarget(
                name: 'Tunnel Worm',
                kind: TargetKind.mob,
                hpPercent: 43,
              ),
            ),
          ),
          executeCommands: (_) async {},
        ),
      ),
    );

    await tester.pump();

    expect(find.text('MOB'), findsOneWidget);
    expect(find.text('Tunnel Worm'), findsOneWidget);
    expect(find.text('HP 43%'), findsOneWidget);
  });

  testWidgets('theme color picker fits on compact screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: AppSettingsController())),
    );

    await tester.tap(find.text('Choose color').first);
    await tester.pumpAndSettle();

    expect(find.text('Choose App color'), findsOneWidget);
    await tester.tap(find.byTooltip('#1C7C82'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings about section shows credits', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: AppSettingsController())),
    );

    await tester.dragUntilVisible(
      find.text('Credits'),
      find.byType(ListView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credits'));
    await tester.pumpAndSettle();

    expect(find.text('Acknowledgements'), findsOneWidget);
    expect(find.textContaining('atom0s'), findsOneWidget);
    expect(find.textContaining('Square Enix'), findsWidgets);
  });

  testWidgets('status tab shows active buffs above HP', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatusScreen(
          statusStream: Stream.value(
            const PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              partyMembers: [],
              activeBuffs: [
                PlayerBuff(id: 33, iconId: 33, name: 'Haste'),
                PlayerBuff(id: 43, iconId: 43, name: 'Refresh'),
              ],
            ),
          ),
          settings: AppSettingsController(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Haste'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets('status tab shows experience progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatusScreen(
          statusStream: Stream.value(
            const PlayerStatus(
              name: 'Aldwyn',
              job: 'RDM',
              subjob: 'THF',
              currentHp: 1284,
              maxHp: 1540,
              currentMp: 436,
              maxMp: 612,
              tp: 1247,
              level: 42,
              currentExp: 12345,
              expToNextLevel: 6789,
              partyMembers: [],
            ),
          ),
          settings: AppSettingsController(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Level 42'), findsOneWidget);
    expect(find.text('12345 EXP'), findsOneWidget);
    expect(find.text('6789 until next level'), findsOneWidget);
    expect(find.text('12345 / 19134'), findsOneWidget);
    expect(find.text('Stats & Equipment'), findsNothing);
  });
}

class _NoopSettingsService extends AppSettingsService {
  const _NoopSettingsService();

  @override
  Future<void> saveChatColors(Map<ChatColorRole, Color> colors) async {}
}
