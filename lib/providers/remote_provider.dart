import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ir_remote.dart';
import '../models/ir_signal.dart';
import '../services/storage_service.dart';
import '../services/flipper_parser.dart';

class RemoteProvider extends ChangeNotifier {
  List<IRRemote> _remotes = [];
  IRRemote? _currentRemote;
  bool _isLoading = false;

  List<IRRemote> get remotes => _remotes;
  IRRemote? get currentRemote => _currentRemote;
  bool get isLoading => _isLoading;

  /// Load remotes from storage
  Future<void> loadRemotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _remotes = await StorageService.loadRemotes();
      
      // Migrate: backfill model info for signals that don't have it
      await _migrateModelInfo();
    } catch (e) {
      print('Error loading remotes: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Backfill model info from cached library data for existing signals
  Future<void> _migrateModelInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final migrationKey = 'model_migration_done_v1';
    
    if (prefs.getBool(migrationKey) == true) return; // Already migrated
    
    bool anyUpdated = false;
    
    for (int remoteIdx = 0; remoteIdx < _remotes.length; remoteIdx++) {
      final remote = _remotes[remoteIdx];
      
      // Check if any signal already has model info
      final hasModel = remote.signals.any((s) => s.model != null && s.model!.isNotEmpty);
      if (hasModel) continue;
      
      // Try to find cached library content for this remote's type
      final cacheKey = 'universal_library_${remote.type}';
      final cachedContent = prefs.getString(cacheKey);
      if (cachedContent == null) continue;
      
      // Re-parse the library to get model info
      final parsedRemote = FlipperZeroParser.parseFlipperFile(cachedContent, '${remote.name}.ir');
      
      // Build a lookup: data hash -> model name from the parsed signals
      final Map<String, String> dataToModel = {};
      for (final signal in parsedRemote.signals) {
        if (signal.model != null && signal.model!.isNotEmpty) {
          // Use the signal data as a fingerprint to match
          final key = '${signal.name}_${signal.data ?? signal.command ?? ''}';
          dataToModel[key] = signal.model!;
        }
      }
      
      if (dataToModel.isEmpty) continue;
      
      // Update signals with model info
      final updatedSignals = <IRSignal>[];
      for (final signal in remote.signals) {
        if (signal.model != null && signal.model!.isNotEmpty) {
          updatedSignals.add(signal);
          continue;
        }
        
        // Try to find matching model by data fingerprint
        String? foundModel;
        for (final parsed in parsedRemote.signals) {
          if (parsed.model != null && parsed.model!.isNotEmpty) {
            // Match by data content
            if (signal.data != null && signal.data == parsed.data) {
              foundModel = parsed.model;
              break;
            }
            // Match by command for parsed signals
            if (signal.command != null && signal.command == parsed.command &&
                signal.address == parsed.address && signal.protocol == parsed.protocol) {
              foundModel = parsed.model;
              break;
            }
          }
        }
        
        updatedSignals.add(IRSignal(
          name: signal.name,
          type: signal.type,
          protocol: signal.protocol,
          address: signal.address,
          command: signal.command,
          frequency: signal.frequency,
          dutyCycle: signal.dutyCycle,
          data: signal.data,
          model: foundModel ?? signal.name,
        ));
        if (foundModel != null) anyUpdated = true;
      }
      
      _remotes[remoteIdx] = IRRemote(
        id: remote.id,
        name: remote.name,
        type: remote.type,
        signals: updatedSignals,
        createdAt: remote.createdAt,
        updatedAt: remote.updatedAt,
      );
      anyUpdated = true;
    }
    
    if (anyUpdated) {
      await StorageService.saveRemotes(_remotes);
    }
    
    await prefs.setBool(migrationKey, true);
  }

  /// Add a new remote
  Future<void> addRemote(IRRemote remote) async {
    _remotes.add(remote);
    await StorageService.saveRemote(remote);
    notifyListeners();
  }

  /// Update existing remote
  Future<void> updateRemote(IRRemote remote) async {
    final index = _remotes.indexWhere((r) => r.id == remote.id);
    if (index != -1) {
      _remotes[index] = remote;
      await StorageService.saveRemote(remote);
      
      // Update current remote if it's the one being updated
      if (_currentRemote?.id == remote.id) {
        _currentRemote = remote;
      }
      
      notifyListeners();
    }
  }

  /// Delete a remote
  Future<void> deleteRemote(String remoteId) async {
    _remotes.removeWhere((r) => r.id == remoteId);
    await StorageService.deleteRemote(remoteId);
    
    // Clear current remote if it was deleted
    if (_currentRemote?.id == remoteId) {
      _currentRemote = null;
    }
    
    notifyListeners();
  }

  /// Set current remote for control
  void setCurrentRemote(IRRemote remote) {
    _currentRemote = remote;
    notifyListeners();
  }

  /// Clear current remote
  void clearCurrentRemote() {
    _currentRemote = null;
    notifyListeners();
  }
}
