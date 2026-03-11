import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import '../models/ir_remote.dart';
import '../models/ir_signal.dart';
import 'flipper_parser.dart';
import 'settings_service.dart';

class UniversalRemoteService {
  static const String _cachePrefix = 'universal_library_';
  
  // Button templates for each device type
  static const Map<String, List<String>> buttonTemplates = {
    'TV': ['Power', 'Mute', 'Vol_up', 'Vol_down', 'Ch_next', 'Ch_prev'],
    'Audio': ['Power', 'Mute', 'Vol_up', 'Vol_down', 'Next', 'Prev', 'Pause', 'Play'],
    'Projector': ['Power', 'Mute', 'Play', 'Pause', 'Vol_up', 'Vol_down'],
    'LEDs': ['On', 'Off', 'Brightness+', 'Brightness-', 'Red', 'Green', 'Blue', 'White'],
    'Fan': ['Power', 'Mode', 'Rotate', 'Timer', 'Speed+', 'Speed-'],
    'AC': ['Off', 'Dry', 'Cool+', 'Cool-', 'Heat+', 'Heat-'],
  };
  
  // GitHub URLs for universal remotes  
  static const Map<String, String> libraryUrls = {
    'TV': 'https://raw.githubusercontent.com/DarkFlippers/unleashed-firmware/dev/applications/main/infrared/resources/infrared/assets/tv.ir',
    'Audio': 'https://raw.githubusercontent.com/DarkFlippers/unleashed-firmware/dev/applications/main/infrared/resources/infrared/assets/audio.ir',
    'Projector': 'https://raw.githubusercontent.com/DarkFlippers/unleashed-firmware/dev/applications/main/infrared/resources/infrared/assets/projectors.ir',
    'LEDs': 'https://raw.githubusercontent.com/DarkFlippers/unleashed-firmware/dev/applications/main/infrared/resources/infrared/assets/leds.ir',
    'Fan': 'https://raw.githubusercontent.com/DarkFlippers/unleashed-firmware/dev/applications/main/infrared/resources/infrared/assets/fans.ir',
    'AC': 'https://raw.githubusercontent.com/DarkFlippers/unleashed-firmware/dev/applications/main/infrared/resources/infrared/assets/ac.ir',
  };

  /// Match signal name to button template
  static bool _matchesButton(String signalName, String buttonName) {
    final signal = signalName.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    final button = buttonName.toLowerCase().replaceAll('_', '').replaceAll('-', '').replaceAll('+', 'plus').replaceAll('minus', '');
    
    // Direct match
    if (signal.contains(button) || button.contains(signal)) {
      return true;
    }
    
    // Special mappings
    final Map<String, List<String>> aliases = {
      'power': ['pwr', 'power', 'onoff', 'on'],
      'volup': ['volumeup', 'volplus', 'vol+', 'volume+'],
      'voldown': ['volumedown', 'volminus', 'vol-', 'volume-'],
      'chnext': ['chup', 'channelup', 'ch+', 'chplus'],
      'chprev': ['chdown', 'channeldown', 'ch-', 'chminus'],
      'brightnessplus': ['brightup', 'brtup', 'brt+', 'bright+'],
      'brightnessminus': ['brightdown', 'brtdown', 'brt-', 'bright-'],
      'speedplus': ['speedup', 'fanup', 'fanplus'],
      'speedminus': ['speeddown', 'fandown', 'fanminus'],
      'coolplus': ['coolup', 'cool+', 'cooleup'],
      'coolminus': ['cooldown', 'cool-', 'cooldown'],
      'heatplus': ['heatup', 'heat+'],
      'heatminus': ['heatdown', 'heat-'],
    };
    
    for (final entry in aliases.entries) {
      if (button.contains(entry.key)) {
        for (final alias in entry.value) {
          if (signal.contains(alias)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  /// Map signals to template buttons - KEEPS ALL VARIATIONS FOR UNIVERSAL REMOTES
  static List<IRSignal> _mapSignalsToButtons(
    List<IRSignal> allSignals,
    String deviceType,
    Function(int current, int total, String buttonName)? onProgress,
  ) {
    final template = buttonTemplates[deviceType] ?? [];
    if (template.isEmpty) {
      return allSignals; // No mapping for this type
    }
    
    final List<IRSignal> mappedSignals = [];
    
    for (int i = 0; i < template.length; i++) {
      final buttonName = template[i];
      
      // Update progress
      if (onProgress != null) {
        onProgress(i + 1, template.length, buttonName);
      }
      
      // Find ALL matching signals (not just first one) - THIS IS KEY FOR UNIVERSAL REMOTES!
      // Example: "Power" might match 50+ signals (Samsung Power, LG Power, Sony Power, etc.)
      for (final signal in allSignals) {
        if (_matchesButton(signal.name, buttonName)) {
          // Rename signal to match template but KEEP ALL VARIATIONS
          // Use model if available, otherwise use original signal name as context
          final modelInfo = signal.model ?? signal.name;
          mappedSignals.add(IRSignal(
            name: buttonName, // Standardize name (e.g., all become "Power")
            type: signal.type,
            protocol: signal.protocol,
            address: signal.address,
            command: signal.command,
            frequency: signal.frequency,
            dutyCycle: signal.dutyCycle,
            data: signal.data,
            model: modelInfo,
          ));
        }
      }
    }
    
    return mappedSignals;
  }

  /// Download and cache library
  static Future<String?> downloadLibrary(String deviceType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$deviceType';
      final cached = prefs.getString(cacheKey);
      
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      // Check for custom URL if beta features are enabled
      String? url;
      if (SettingsService.betaFeaturesEnabled) {
        url = SettingsService.getCustomRemoteUrl(deviceType);
      }
      // Fall back to default URL
      url ??= libraryUrls[deviceType];
      if (url == null) return null;

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'text/plain, application/octet-stream, */*',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (content.isNotEmpty) {
          await prefs.setString(cacheKey, content);
          return content;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Import ZIP as merged universal remote (all files → 1 remote with all variations)
  static Future<IRRemote?> importZipAsMergedUniversal({
    Function(int current, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return null;
      }

      final zipPath = result.files.single.path!;
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final irFiles = archive.where((file) => 
        file.isFile && (file.name.endsWith('.ir') || file.name.endsWith('.txt'))
      ).toList();

      if (irFiles.length > 1) {
        // Warn user about merge
        // Note: Can't show dialog here, but we'll handle it
      }

      List<IRSignal> allSignals = [];
      int processedCount = 0;

      for (final file in irFiles) {
        if (shouldCancel != null && shouldCancel()) break;

        processedCount++;
        final fileName = file.name.split('/').last;
        
        if (onProgress != null) {
          onProgress(processedCount, irFiles.length, fileName);
        }
        
        try {
          final content = utf8.decode(file.content as List<int>);
          
          if (FlipperZeroParser.isValidFlipperFile(content)) {
            final remote = FlipperZeroParser.parseFlipperFile(content, fileName);
            // Add ALL signals (keep variations)
            allSignals.addAll(remote.signals);
          }
        } catch (e) {
          // Skip invalid files
        }

        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (allSignals.isEmpty) return null;

      // Create merged universal remote
      return IRRemote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Universal Remote (Merged)',
        type: 'Universal',
        signals: allSignals,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Import ZIP as multiple universal remotes (each file → 1 universal remote)
  static Future<List<IRRemote>> importZipAsMultipleUniversal({
    Function(int current, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return [];
      }

      final zipPath = result.files.single.path!;
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final irFiles = archive.where((file) => 
        file.isFile && (file.name.endsWith('.ir') || file.name.endsWith('.txt'))
      ).toList();

      List<IRRemote> remotes = [];
      int processedCount = 0;

      for (final file in irFiles) {
        if (shouldCancel != null && shouldCancel()) break;

        processedCount++;
        final fileName = file.name.split('/').last;
        
        if (onProgress != null) {
          onProgress(processedCount, irFiles.length, fileName);
        }
        
        try {
          final content = utf8.decode(file.content as List<int>);
          
          if (FlipperZeroParser.isValidFlipperFile(content)) {
            final remote = FlipperZeroParser.parseFlipperFile(content, fileName);
            
            if (remote.signals.isNotEmpty) {
              // Make it a universal remote (keeps all signal variations)
              remotes.add(remote.copyWith(type: 'Universal'));
            }
          }
        } catch (e) {
          // Skip invalid files
        }

        await Future.delayed(const Duration(milliseconds: 10));
      }

      return remotes;
    } catch (e) {
      return [];
    }
  }

  /// Import from ZIP (regular mode - each file separate)
  static Future<List<IRRemote>> importFromZip({
    Function(int current, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return [];
      }

      final zipPath = result.files.single.path!;
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final irFiles = archive.where((file) => 
        file.isFile && (file.name.endsWith('.ir') || file.name.endsWith('.txt'))
      ).toList();

      List<IRRemote> remotes = [];
      int processedCount = 0;

      for (final file in irFiles) {
        if (shouldCancel != null && shouldCancel()) break;

        processedCount++;
        final fileName = file.name.split('/').last;
        
        if (onProgress != null) {
          onProgress(processedCount, irFiles.length, fileName);
        }
        
        try {
          final content = utf8.decode(file.content as List<int>);
          
          if (FlipperZeroParser.isValidFlipperFile(content)) {
            final remote = FlipperZeroParser.parseFlipperFile(
              content,
              fileName,
            );
            
            if (remote.signals.isNotEmpty) {
              remotes.add(remote);
            }
          }
        } catch (e) {
          // Skip invalid files
        }

        await Future.delayed(const Duration(milliseconds: 10));
      }

      return remotes;
    } catch (e) {
      return [];
    }
  }

  /// Create universal remote with button mapping
  static Future<IRRemote?> createUniversalRemote(
    String deviceType,
    String customName, {
    Function(int current, int total, String buttonName)? onMappingProgress,
  }) async {
    try {
      final content = await downloadLibrary(deviceType);
      if (content == null) return null;

      final remote = FlipperZeroParser.parseFlipperFile(
        content,
        '$customName.ir',
        // For universal libraries we keep parsed signals; conversion to RAW
        // can be done later via the converter.
        convertParsedToRaw: false,
      );

      // Map signals to template buttons
      final mappedSignals = _mapSignalsToButtons(
        remote.signals,
        deviceType,
        onMappingProgress,
      );

      if (mappedSignals.isEmpty) {
        return null; // No matches found
      }

      return IRRemote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: customName,
        type: deviceType,
        signals: mappedSignals,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final type in libraryUrls.keys) {
        await prefs.remove('$_cachePrefix$type');
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Check if cached
  static Future<bool> isCached(String deviceType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('$_cachePrefix$deviceType');
    } catch (e) {
      return false;
    }
  }

  /// Preload all libraries
  static Future<void> preloadAllLibraries() async {
    for (final type in libraryUrls.keys) {
      try {
        await downloadLibrary(type);
      } catch (e) {
        // Continue on error
      }
    }
  }
}
