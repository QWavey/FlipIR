import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ir_remote.dart';

class StorageService {
  static const String _remotesKey = 'ir_remotes';
  // Copy of stored text that could not be read as a remote list at all
  static const String _backupKey = 'ir_remotes_backup';

  // Set when the stored text cannot be read as a whole. Writes are refused
  // while it is set, so the unreadable text is never overwritten.
  static bool _blockWrites = false;

  // Raw entries from the last load that could not be decoded. They are
  // written back unchanged so that a save never drops them.
  static List<dynamic> _preserved = [];

  // Runs read-modify-write cycles one at a time, so two saves cannot
  // overwrite each other's changes.
  static Future<void> _queue = Future.value();

  static Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Save all remotes
  static Future<bool> saveRemotes(List<IRRemote> remotes) =>
      _serialized(() => _write(remotes));

  static Future<bool> _write(List<IRRemote> remotes) async {
    if (_blockWrites) {
      print('Refusing to overwrite unreadable stored remotes');
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = [
        ...remotes.map((r) => r.toJson()),
        ..._preserved,
      ];
      final jsonString = jsonEncode(jsonList);
      return await prefs.setString(_remotesKey, jsonString);
    } catch (e) {
      print('Error saving remotes: $e');
      return false;
    }
  }

  /// Load all remotes. An entry that cannot be read is left out of the result
  /// but kept in the store. If the stored text is unreadable as a whole, it is
  /// copied to a backup key and writes are refused.
  static Future<List<IRRemote>> loadRemotes() async {
    String? jsonString;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      jsonString = prefs.getString(_remotesKey);

      if (jsonString == null || jsonString.isEmpty) {
        _blockWrites = false;
        _preserved = [];
        return [];
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        throw const FormatException('Stored remotes are not a list');
      }

      final remotes = <IRRemote>[];
      final preserved = <dynamic>[];
      for (final entry in decoded) {
        try {
          remotes.add(IRRemote.fromJson(entry as Map<String, dynamic>));
        } catch (e) {
          print('Keeping unreadable remote entry: $e');
          preserved.add(entry);
        }
      }
      _blockWrites = false;
      _preserved = preserved;
      return remotes;
    } catch (e) {
      print('Error loading remotes: $e');
      _blockWrites = true;
      _preserved = [];
      try {
        if (prefs != null &&
            jsonString != null &&
            jsonString.isNotEmpty &&
            prefs.getString(_backupKey) == null) {
          await prefs.setString(_backupKey, jsonString);
        }
      } catch (backupError) {
        print('Error backing up unreadable remotes: $backupError');
      }
      return [];
    }
  }

  /// Save a single remote. A stored remote with the same ID is replaced in
  /// place; a new remote is appended.
  static Future<bool> saveRemote(IRRemote remote) => _serialized(() async {
        try {
          final remotes = await loadRemotes();

          final index = remotes.indexWhere((r) => r.id == remote.id);
          if (index == -1) {
            remotes.add(remote);
          } else {
            remotes[index] = remote;
          }

          return await _write(remotes);
        } catch (e) {
          print('Error saving remote: $e');
          return false;
        }
      });

  /// Delete a remote
  static Future<bool> deleteRemote(String remoteId) => _serialized(() async {
        try {
          final remotes = await loadRemotes();
          remotes.removeWhere((r) => r.id == remoteId);
          return await _write(remotes);
        } catch (e) {
          print('Error deleting remote: $e');
          return false;
        }
      });

  /// Clear all data. The backup of unreadable text is kept.
  static Future<bool> clearAll() => _serialized(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          _blockWrites = false;
          _preserved = [];
          return await prefs.remove(_remotesKey);
        } catch (e) {
          print('Error clearing data: $e');
          return false;
        }
      });
}
