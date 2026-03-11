// Chain Code Model - for automation sequences
class ChainCode {
  final String id;
  final String name;
  final List<ChainStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChainCode({
    required this.id,
    required this.name,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'steps': steps.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ChainCode.fromJson(Map<String, dynamic> json) {
    return ChainCode(
      id: json['id'] as String,
      name: json['name'] as String,
      steps: (json['steps'] as List)
          .map((s) => ChainStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ChainCode copyWith({
    String? id,
    String? name,
    List<ChainStep>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChainCode(
      id: id ?? this.id,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChainStep {
  final String type; // 'command', 'delay', 'loop_begin', 'loop_end', or 'hold'
  final String? signalName; // For commands
  final String? remoteId; // For commands
  final int? delayMs; // For delays
  final int? loopCount; // For loops (null = infinite)
  final int? holdMs; // For hold steps (duration of press)

  ChainStep({
    required this.type,
    this.signalName,
    this.remoteId,
    this.delayMs,
    this.loopCount,
    this.holdMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'signalName': signalName,
      'remoteId': remoteId,
      'delayMs': delayMs,
      'loopCount': loopCount,
      'holdMs': holdMs,
    };
  }

  factory ChainStep.fromJson(Map<String, dynamic> json) {
    return ChainStep(
      type: json['type'] as String,
      signalName: json['signalName'] as String?,
      remoteId: json['remoteId'] as String?,
      delayMs: json['delayMs'] as int?,
      loopCount: json['loopCount'] as int?,
      holdMs: json['holdMs'] as int?,
    );
  }

  static ChainStep command({
    required String signalName,
    required String remoteId,
  }) {
    return ChainStep(
      type: 'command',
      signalName: signalName,
      remoteId: remoteId,
    );
  }

  static ChainStep hold({
    required String signalName,
    required String remoteId,
    required int holdMs,
  }) {
    return ChainStep(
      type: 'hold',
      signalName: signalName,
      remoteId: remoteId,
      holdMs: holdMs,
    );
  }

  static ChainStep delay(int milliseconds) {
    return ChainStep(
      type: 'delay',
      delayMs: milliseconds,
    );
  }

  static ChainStep loopBegin(int? count) {
    return ChainStep(
      type: 'loop_begin',
      loopCount: count,
    );
  }

  static ChainStep loopEnd() {
    return ChainStep(
      type: 'loop_end',
    );
  }

  String get displayText {
    switch (type) {
      case 'command':
        final name = signalName ?? 'Unknown';
        // Check if it's a specific variation (e.g., "Power#3")
        if (name.contains('#')) {
          final parts = name.split('#');
          return '${parts[0]} (variation #${parts[1]})';
        }
        return name;
      case 'delay':
        return 'Wait ${delayMs}ms';
      case 'loop_begin':
        return loopCount == null ? 'Loop ∞ times' : 'Loop $loopCount times';
      case 'loop_end':
        return 'End Loop';
      case 'hold':
        final name = signalName ?? 'Unknown';
        final duration = holdMs ?? 0;
        return 'Hold $name for ${duration}ms';
      default:
        return 'Unknown';
    }
  }

  String get displayIcon {
    switch (type) {
      case 'command':
        return '📤';
      case 'delay':
        return '⏱️';
      case 'loop_begin':
        return '🔄';
      case 'loop_end':
        return '🏁';
      case 'hold':
        return '✋';
      default:
        return '❓';
    }
  }
}
