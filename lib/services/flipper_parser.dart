import '../models/ir_signal.dart';
import '../models/ir_remote.dart';

class FlipperZeroParser {
  /// Parse Flipper Zero .ir or .txt file content
  static IRRemote parseFlipperFile(
    String content,
    String fileName, {
    bool convertParsedToRaw = false,
  }) {
    final lines = content.split('\n');
    final signals = <IRSignal>[];

    // Fields of the block being read. Every block boundary clears them all.
    String? currentName;
    String? currentType;
    String? currentProtocol;
    String? currentAddress;
    String? currentCommand;
    int? currentFrequency;
    double? currentDutyCycle;
    String? currentData;
    String? currentModel; // Model/brand from comment lines, kept across blocks

    // Saves the block read so far if it is complete, then clears all of its
    // fields. An incomplete block is discarded, so its fields cannot leak into
    // the next block.
    void endBlock() {
      final name = currentName;
      final type = currentType;
      if (name != null && type != null) {
        final signal = _createSignal(
          name,
          type,
          currentProtocol,
          currentAddress,
          currentCommand,
          currentFrequency,
          currentDutyCycle,
          currentData,
          currentModel,
          convertParsedToRaw,
        );
        if (signal != null) {
          signals.add(signal);
        }
      }

      currentName = null;
      currentType = null;
      currentProtocol = null;
      currentAddress = null;
      currentCommand = null;
      currentFrequency = null;
      currentDutyCycle = null;
      currentData = null;
    }

    for (var line in lines) {
      line = line.trim();

      // Comment lines can name a model or brand, and they end the current block
      if (line.startsWith('#')) {
        final commentText = line.substring(1).trim();
        if (commentText.isNotEmpty) {
          final lower = commentText.toLowerCase();
          if (lower.startsWith('model:')) {
            currentModel = commentText.substring(6).trim();
          } else if (lower.startsWith('compatible brands:')) {
            // If we already have a model, append compatible brands
            if (currentModel != null) {
              currentModel = '$currentModel (${commentText.substring(18).trim()})';
            } else {
              currentModel = commentText.substring(18).trim();
            }
          } else if (!lower.startsWith('last updated') &&
              !lower.startsWith('last checked') &&
              !lower.startsWith('filetype') &&
              !lower.startsWith('version')) {
            // Use the comment as model/section name if it's not a metadata line.
            // This catches lines like "# Brand ModelName" used as section headers
            currentModel = commentText;
          }
        }
        endBlock();
        continue;
      }

      // A blank line also ends the current block
      if (line.isEmpty) {
        endBlock();
        continue;
      }

      // Parse key-value pairs. Keys are matched in lower case.
      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim().toLowerCase();
          final value = parts.sublist(1).join(':').trim();

          switch (key) {
            case 'name':
              currentName = value;
              break;
            case 'type':
              currentType = value.toLowerCase();
              break;
            case 'protocol':
              currentProtocol = value;
              break;
            case 'address':
              currentAddress = value;
              break;
            case 'command':
              currentCommand = value;
              break;
            case 'frequency':
              currentFrequency = int.tryParse(value);
              break;
            case 'duty_cycle':
              currentDutyCycle = double.tryParse(value);
              break;
            case 'data':
              currentData = value;
              break;
          }
        }
      }
    }

    // Add the last block if it is complete
    endBlock();

    // Extract remote name from filename
    String remoteName = fileName
        .replaceAll('.ir', '')
        .replaceAll('.txt', '')
        .replaceAll('_', ' ');

    return IRRemote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: remoteName,
      type: _guessRemoteType(remoteName, signals),
      signals: signals,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Builds a signal from one block of the file. Returns null when the block
  /// cannot be encoded, so only that signal is dropped.
  static IRSignal? _createSignal(
    String name,
    String type,
    String? protocol,
    String? address,
    String? command,
    int? frequency,
    double? dutyCycle,
    String? data,
    String? model,
    bool convertParsedToRaw,
  ) {
    // First create the signal as described in the file
    final baseSignal = IRSignal(
      name: name,
      type: type,
      protocol: protocol,
      address: address,
      command: command,
      frequency: frequency,
      dutyCycle: dutyCycle,
      data: data,
      model: model,
    );

    // If requested and this is a parsed (protocol-based) signal, convert it
    // into a RAW timing pattern at parse time.
    if (convertParsedToRaw && type == 'parsed') {
      // A protocol that cannot be converted stays parsed, so that transmitting
      // it reports the error instead of dropping the button
      if (!IRSignal.isSupportedProtocol(protocol)) return baseSignal;
      final transmitData = _tryConvert(baseSignal);
      if (transmitData == null) return null;
      final rawData = transmitData.pattern.join(' ');

      return IRSignal(
        name: name,
        type: 'raw',
        protocol: protocol,
        address: address,
        command: command,
        frequency: frequency ?? transmitData.carrierFrequency,
        dutyCycle: dutyCycle ?? 0.33,
        data: rawData,
        model: model,
      );
    }

    // Raw timings are checked now, so a bad value never reaches transmission
    if (type == 'raw' && _tryConvert(baseSignal) == null) return null;

    return baseSignal;
  }

  /// Converts a signal to transmit data, or returns null if its fields are malformed.
  static IRTransmitData? _tryConvert(IRSignal signal) {
    try {
      return signal.toAndroidFormat();
    } on IRFormatException {
      return null;
    }
  }

  static String _guessRemoteType(String name, List<IRSignal> signals) {
    final lowerName = name.toLowerCase();
    
    if (lowerName.contains('tv')) return 'TV';
    if (lowerName.contains('ac') || lowerName.contains('air')) return 'AC';
    if (lowerName.contains('fan')) return 'Fan';
    if (lowerName.contains('projector')) return 'Projector';
    if (lowerName.contains('soundbar') || lowerName.contains('audio')) {
      return 'Audio';
    }
    if (lowerName.contains('cable') || lowerName.contains('satellite')) {
      return 'Cable Box';
    }
    
    // Guess from signal names
    final signalNames = signals.map((s) => s.name.toLowerCase()).toList();
    if (signalNames.any((s) => 
        s.contains('channel') || s.contains('volume') || s.contains('input'))) {
      return 'TV';
    }
    
    return 'Generic';
  }

  /// Validate Flipper Zero file format. Keys and type values are matched
  /// without regard to case or to spaces around the colon.
  static bool isValidFlipperFile(String content) {
    bool hasFileType = false;
    bool hasVersion = false;
    bool hasName = false;
    bool hasSignalType = false;

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('#') || !line.contains(':')) continue;

      final parts = line.split(':');
      final key = parts[0].trim().toLowerCase();
      final value = parts.sublist(1).join(':').trim().toLowerCase();
      switch (key) {
        case 'filetype':
          if (value.contains('ir signals')) hasFileType = true;
          break;
        case 'version':
          hasVersion = true;
          break;
        case 'name':
          hasName = true;
          break;
        case 'type':
          if (value == 'parsed' || value == 'raw') hasSignalType = true;
          break;
      }
    }

    // Require at least one signal and either a file header or a version line
    return hasName && hasSignalType && (hasFileType || hasVersion);
  }

  /// Get signal count from file content
  static int getSignalCount(String content) {
    return 'name:'.allMatches(content).length;
  }
}
