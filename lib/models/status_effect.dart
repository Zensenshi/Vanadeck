class PlayerBuff {
  const PlayerBuff({
    required this.id,
    this.iconId,
    this.name,
    this.remainingSeconds,
  });

  final int id;
  final int? iconId;
  final String? name;
  final int? remainingSeconds;

  int get displayIconId => iconId ?? id;

  String get displayName {
    final knownName = _knownNames[displayIconId] ?? _knownNames[id];
    if (knownName != null) {
      return knownName;
    }

    final buffName = _cleanName(name);
    if (buffName != null && buffName.isNotEmpty) {
      return buffName;
    }
    return 'Status ${displayIconId == id ? id : '$id/$displayIconId'}';
  }

  String? get timerLabel {
    final seconds = remainingSeconds;
    if (seconds == null || seconds < 0) {
      return null;
    }

    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String get tooltipText {
    final timer = timerLabel;
    if (timer == null) {
      return displayName;
    }
    return '$displayName\nRemaining: $timer';
  }

  String? _cleanName(String? rawName) {
    if (rawName == null) {
      return null;
    }

    final withoutNulls = rawName.split('\u0000').first;
    final cleaned = withoutNulls
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F\uFFFD]'), '')
        .trim();
    if (cleaned.isEmpty) {
      return null;
    }

    final asciiSafeCount = cleaned.runes
        .where(
          (rune) =>
              (rune >= 0x30 && rune <= 0x39) ||
              (rune >= 0x41 && rune <= 0x5A) ||
              (rune >= 0x61 && rune <= 0x7A) ||
              rune == 0x20 ||
              rune == 0x27 ||
              rune == 0x2D ||
              rune == 0x2F,
        )
        .length;
    if (asciiSafeCount < cleaned.runes.length * 0.8) {
      return null;
    }

    return cleaned;
  }

  static const Map<int, String> _knownNames = {
    0: 'Signet',
    33: 'Haste',
    40: 'Protect',
    41: 'Shell',
    42: 'Regen',
    43: 'Refresh',
    253: 'Signet',
    256: 'Sanction',
  };
}
