class Macro {
  const Macro({
    required this.id,
    required this.slot,
    required this.name,
    required this.icon,
    required this.commands,
  });

  final String id;
  final int slot; // 1-100 within a book
  final String name;
  final String icon;
  final List<String> commands;

  Macro copyWith({String? name, String? icon, List<String>? commands}) {
    return Macro(
      id: id,
      slot: slot,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      commands: commands ?? this.commands,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slot': slot,
      'name': name,
      'icon': icon,
      'commands': commands,
    };
  }

  static Macro fromJson(Map<String, dynamic> json) {
    return Macro(
      id: json['id'] as String? ?? '',
      slot: (json['slot'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      commands:
          (json['commands'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
    );
  }
}
