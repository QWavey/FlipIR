import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ir_remote.dart';

class StorageService {
  static const String _remotesKey = 'ir_remotes';

  /// Save all remotes
  static Future<bool> saveRemotes(List<IRRemote> remotes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = remotes.map((r) => r.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      return await prefs.setString(_remotesKey, jsonString);
    } catch (e) {
      print('Error saving remotes: $e');
      return false;
    }
  }

  /// Load all remotes
  static Future<List<IRRemote>> loadRemotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_remotesKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => IRRemote.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading remotes: $e');
      return [];
    }
  }

  /// Save a single remote
  static Future<bool> saveRemote(IRRemote remote) async {
    try {
      final remotes = await loadRemotes();
      
      // Remove existing remote with same ID
      remotes.removeWhere((r) => r.id == remote.id);
      
      // Add updated remote
      remotes.add(remote);
      
      return await saveRemotes(remotes);
    } catch (e) {
      print('Error saving remote: $e');
      return false;
    }
  }

  /// Delete a remote
  static Future<bool> deleteRemote(String remoteId) async {
    try {
      final remotes = await loadRemotes();
      remotes.removeWhere((r) => r.id == remoteId);
      return await saveRemotes(remotes);
    } catch (e) {
      print('Error deleting remote: $e');
      return false;
    }
  }

  /// Clear all data
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_remotesKey);
    } catch (e) {
      print('Error clearing data: $e');
      return false;
    }
  }
}
