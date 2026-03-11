import 'ir_signal.dart';

// Remote Model - represents a complete remote control
class IRRemote {
  final String id;
  final String name;
  final String type; // TV, AC, Fan, etc.
  final List<IRSignal> signals;
  final DateTime createdAt;
  final DateTime updatedAt;

  IRRemote({
    required this.id,
    required this.name,
    required this.type,
    required this.signals,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'signals': signals.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory IRRemote.fromJson(Map<String, dynamic> json) {
    return IRRemote(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      signals: (json['signals'] as List)
          .map((s) => IRSignal.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // Export to Flipper Zero .ir format
  String toFlipperFile() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Filetype: IR signals file');
    buffer.writeln('Version: 1');
    buffer.writeln('#');

    for (var signal in signals) {
      buffer.writeln(signal.toFlipperFormat());
      buffer.writeln('#');
    }

    return buffer.toString();
  }

  // Copy with updated signals
  IRRemote copyWith({
    String? id,
    String? name,
    String? type,
    List<IRSignal>? signals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IRRemote(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      signals: signals ?? this.signals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Find signal by name
  IRSignal? findSignal(String name) {
    try {
      return signals.firstWhere((s) => s.name == name);
    } catch (e) {
      return null;
    }
  }
}
