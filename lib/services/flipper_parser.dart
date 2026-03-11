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
    
    String? currentName;
    String? currentType;
    String? currentProtocol;
    String? currentAddress;
    String? currentCommand;
    int? currentFrequency;
    double? currentDutyCycle;
    String? currentData;
    String? currentModel; // Store model/brand from comment lines

    for (var line in lines) {
      line = line.trim();
      
      // Check for model information in comments (# Model: xxx or # Compatible brands: xxx)
      if (line.startsWith('#')) {
        // Extract model information from comment lines
        if (line.length > 1 && line.substring(1).trim().isNotEmpty) {
          final commentText = line.substring(1).trim();
          if (commentText.toLowerCase().startsWith('model:')) {
            currentModel = commentText.substring(6).trim();
          } else if (commentText.toLowerCase().startsWith('compatible brands:')) {
            // If we already have a model, append compatible brands
            if (currentModel != null) {
              currentModel = '$currentModel (${commentText.substring(18).trim()})';
            } else {
              currentModel = commentText.substring(18).trim();
            }
          } else if (!commentText.toLowerCase().startsWith('last updated') && 
                     !commentText.toLowerCase().startsWith('last checked') &&
                     !commentText.toLowerCase().startsWith('filetype') &&
                     !commentText.toLowerCase().startsWith('version')) {
            // Use the comment as model/section name if it's not a metadata line
            // This catches lines like "# Brand ModelName" used as section headers
            currentModel = commentText;
          }
        }
        
        // If we have a complete signal, save it
        if (currentName != null && currentType != null) {
          signals.add(_createSignal(
            currentName,
            currentType,
            currentProtocol,
            currentAddress,
            currentCommand,
            currentFrequency,
            currentDutyCycle,
            currentData,
            currentModel,
            convertParsedToRaw,
          ));
          
          // Reset signal fields but keep model for next signals
          currentName = null;
          currentType = null;
          currentProtocol = null;
          currentAddress = null;
          currentCommand = null;
          currentFrequency = null;
          currentDutyCycle = null;
          currentData = null;
        }
        continue;
      }
      
      // Skip empty lines
      if (line.isEmpty) {
        // If we have a complete signal, save it
        if (currentName != null && currentType != null) {
          signals.add(_createSignal(
            currentName,
            currentType,
            currentProtocol,
            currentAddress,
            currentCommand,
            currentFrequency,
            currentDutyCycle,
            currentData,
            currentModel,
            convertParsedToRaw,
          ));
          
          // Reset for next signal
          currentName = null;
          currentType = null;
          currentProtocol = null;
          currentAddress = null;
          currentCommand = null;
          currentFrequency = null;
          currentDutyCycle = null;
          currentData = null;
        }
        continue;
      }

      // Parse key-value pairs
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
              currentType = value;
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

    // Add last signal if exists
    if (currentName != null && currentType != null) {
      signals.add(_createSignal(
        currentName,
        currentType,
        currentProtocol,
        currentAddress,
        currentCommand,
        currentFrequency,
        currentDutyCycle,
        currentData,
        currentModel,
        convertParsedToRaw,
      ));
    }

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

  static IRSignal _createSignal(
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
    if (convertParsedToRaw && type.toLowerCase() == 'parsed') {
      final transmitData = baseSignal.toAndroidFormat();
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

    // Already RAW – keep as‑is
    return baseSignal;
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

  /// Validate Flipper Zero file format
  static bool isValidFlipperFile(String content) {
    final lines = content.split('\n');
    
    // Check for file header
    bool hasFileType = false;
    bool hasVersion = false;
    
    for (var line in lines) {
      line = line.trim().toLowerCase();
      if (line.startsWith('filetype:') && line.contains('ir signals')) {
        hasFileType = true;
      }
      if (line.startsWith('version:')) {
        hasVersion = true;
      }
    }
    
    // Must have at least one signal definition
    bool hasSignal = content.contains('name:') && 
                     (content.contains('type: parsed') || 
                      content.contains('type: raw'));
    
    // Require at least one signal and either a file header or a version line
    return hasSignal && (hasFileType || hasVersion);
  }

  /// Get signal count from file content
  static int getSignalCount(String content) {
    return 'name:'.allMatches(content).length;
  }
}
