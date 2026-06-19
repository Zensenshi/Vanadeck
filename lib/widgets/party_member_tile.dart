import 'package:flutter/material.dart';

import '../models/party_member.dart';
import '../services/app_settings_controller.dart';
import 'stat_bar.dart';
import 'status_icon_strip.dart';

class PartyMemberTile extends StatelessWidget {
  const PartyMemberTile({
    super.key,
    required this.member,
    required this.settings,
  });

  final PartyMember member;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    member.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (member.activeBuffs.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 4,
                    child: StatusIconStrip(
                      buffs: member.activeBuffs,
                      settings: settings,
                      compact: true,
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Flexible(
                  flex: 3,
                  child: Text(
                    '${member.job}/${member.subjob} Lv.${member.level}',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            StatBar(
              label: 'HP',
              currentValue: member.currentHp,
              maxValue: member.maxHp,
              percent: member.hpPercent,
              color: const Color(0xFFE25C5C),
              compact: true,
            ),
            const SizedBox(height: 6),
            StatBar(
              label: 'MP',
              currentValue: member.currentMp,
              maxValue: member.maxMp,
              percent: member.mpPercent,
              color: const Color(0xFF5A9BE8),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
