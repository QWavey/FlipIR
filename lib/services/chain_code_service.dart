import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chain_code.dart';
import '../models/ir_remote.dart';
import '../models/ir_signal.dart';
import 'ir_transmitter_service.dart';

class ChainCodeService {
  static const String _chainCodesKey = 'chain_codes';

  /// Save all chain codes
  static Future<bool> saveChainCodes(List<ChainCode> chainCodes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = chainCodes.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      final success = await prefs.setString(_chainCodesKey, jsonString);
      
      if (success) {
        // Verify the save
        final verification = prefs.getString(_chainCodesKey);
        if (verification == null) {
          return false;
        }
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Load all chain codes
  static Future<List<ChainCode>> loadChainCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_chainCodesKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final jsonList = jsonDecode(jsonString) as List;
      final chainCodes = jsonList
          .map((json) => ChainCode.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return chainCodes;
    } catch (e) {
      return [];
    }
  }

  /// Save a single chain code
  static Future<bool> saveChainCode(ChainCode chainCode) async {
    try {
      final chainCodes = await loadChainCodes();
      
      // Remove existing chain code with same ID
      chainCodes.removeWhere((c) => c.id == chainCode.id);
      
      // Add updated chain code
      chainCodes.add(chainCode);
      
      final success = await saveChainCodes(chainCodes);
      
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Delete a chain code
  static Future<bool> deleteChainCode(String chainCodeId) async {
    try {
      final chainCodes = await loadChainCodes();
      final initialCount = chainCodes.length;
      
      chainCodes.removeWhere((c) => c.id == chainCodeId);
      
      if (chainCodes.length < initialCount) {
        final success = await saveChainCodes(chainCodes);
        return success;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Execute a chain code with loop support
  static Future<bool> executeChainCode(
    ChainCode chainCode,
    List<IRRemote> remotes,
    Function(String) onProgress,
  ) async {
    try {
      return await _executeSteps(chainCode.steps, remotes, onProgress, 0);
    } catch (e) {
      final errorMsg = 'Execution error: $e';
      onProgress(errorMsg);
      return false;
    }
  }

  /// Internal method to execute steps with loop handling
  static Future<bool> _executeSteps(
    List<ChainStep> steps,
    List<IRRemote> remotes,
    Function(String) onProgress,
    int depth, // To prevent infinite recursion
  ) async {
    if (depth > 100) {
      throw Exception('Maximum loop depth exceeded (100)');
    }

    int i = 0;
    while (i < steps.length) {
      final step = steps[i];
      
      if (step.type == 'loop_begin') {
        // Find matching loop_end
        int loopEndIndex = _findMatchingLoopEnd(steps, i);
        if (loopEndIndex == -1) {
          throw Exception('No matching loop_end found for loop_begin at step ${i + 1}');
        }

        // Extract steps inside the loop
        final loopSteps = steps.sublist(i + 1, loopEndIndex);
        final loopCount = step.loopCount;

        if (loopCount == null) {
          // Infinite loop - not recommended, but supported
          // We'll limit it to 1000 iterations to prevent hanging
          onProgress('⚠️ Warning: Infinite loop detected! Limiting to 1000 iterations.');
          for (int iteration = 0; iteration < 1000; iteration++) {
            onProgress('Loop iteration ${iteration + 1}/∞...');
            final success = await _executeSteps(loopSteps, remotes, onProgress, depth + 1);
            if (!success) return false;
          }
        } else {
          // Finite loop
          for (int iteration = 0; iteration < loopCount; iteration++) {
            onProgress('Loop iteration ${iteration + 1}/$loopCount...');
            final success = await _executeSteps(loopSteps, remotes, onProgress, depth + 1);
            if (!success) return false;
          }
        }

        // Skip to after the loop_end
        i = loopEndIndex + 1;
      } else if (step.type == 'loop_end') {
        // This should not happen if loops are properly structured
        throw Exception('Unexpected loop_end at step ${i + 1}');
      } else if (step.type == 'delay') {
        onProgress('⏱️ Waiting ${step.delayMs}ms... (${i + 1}/${steps.length})');
        await Future.delayed(Duration(milliseconds: step.delayMs ?? 0));
        i++;
      } else if (step.type == 'command' || step.type == 'hold') {
        // Find the remote
        final remote = remotes.firstWhere(
          (r) => r.id == step.remoteId,
          orElse: () => throw Exception('Remote not found: ${step.remoteId}'),
        );
        
        // Check if user wants specific variation (format: "Power#3")
        final signalName = step.signalName ?? '';
        final parts = signalName.split('#');
        final baseName = parts[0];
        final variationIndex = parts.length > 1 ? int.tryParse(parts[1]) : null;
        
        // Find all signals with matching name
        final matchingSignals = remote.signals
            .where((s) => s.name.toLowerCase() == baseName.toLowerCase())
            .toList();
        
        if (matchingSignals.isEmpty) {
          throw Exception('Signal not found: $baseName');
        }

        // Determine whether this is a simple command or a hold step
        final isHoldStep = step.type == 'hold';

        // Resolve which signal(s) to send
        if (!isHoldStep) {
          // Regular command behaviour (as before)
          if (variationIndex != null) {
            // User wants a SPECIFIC variation
            if (variationIndex < 1 || variationIndex > matchingSignals.length) {
              throw Exception('Variation #$variationIndex not found for $baseName');
            }
            
            final signal = matchingSignals[variationIndex - 1];
            onProgress('📤 Sending $baseName (variation $variationIndex)... (${i + 1}/${steps.length})');
            
            final success = await IRTransmitterService.transmit(signal);
            if (!success) {
              throw Exception('Failed to send $baseName variation $variationIndex');
            }
          } else {
            // No variation specified - send ALL variations
            if (matchingSignals.length == 1) {
              onProgress('📤 Sending $baseName... (${i + 1}/${steps.length})');
              final success = await IRTransmitterService.transmit(matchingSignals[0]);
              if (!success) {
                throw Exception('Failed to send $baseName');
              }
            } else {
              onProgress('📤 Sending $baseName (${matchingSignals.length} variations)... (${i + 1}/${steps.length})');
              for (int v = 0; v < matchingSignals.length; v++) {
                onProgress('  → Variation ${v + 1}/${matchingSignals.length}');
                await IRTransmitterService.transmit(matchingSignals[v]);
                await Future.delayed(const Duration(milliseconds: 400));
              }
            }
          }
        } else {
          // Hold behaviour: repeatedly send a single signal for the configured duration
          final holdDuration = step.holdMs ?? 0;
          if (holdDuration <= 0) {
            i++;
            continue;
          }

          // Choose a specific signal to hold:
          //  - if a variation index is specified, use that variation
          //  - otherwise, use the first matching signal
          IRSignal signalToHold;
          if (variationIndex != null) {
            if (variationIndex < 1 || variationIndex > matchingSignals.length) {
              throw Exception('Variation #$variationIndex not found for $baseName');
            }
            signalToHold = matchingSignals[variationIndex - 1];
          } else {
            signalToHold = matchingSignals.first;
          }

          onProgress('✋ Holding $baseName for ${holdDuration}ms... (${i + 1}/${steps.length})');

          const repeatGapMs = 250; // Gap between repeats while "holding"
          int elapsed = 0;
          while (elapsed < holdDuration) {
            final success = await IRTransmitterService.transmit(signalToHold);
            if (!success) {
              throw Exception('Failed while holding $baseName');
            }
            await Future.delayed(const Duration(milliseconds: repeatGapMs));
            elapsed += repeatGapMs;
          }
        }

        // Small delay between steps
        await Future.delayed(const Duration(milliseconds: 100));
        i++;
      } else {
        throw Exception('Unknown step type: ${step.type}');
      }
    }
    
    if (depth == 0) {
      onProgress('✅ Chain code completed!');
    }
    return true;
  }

  /// Find the matching loop_end for a loop_begin
  static int _findMatchingLoopEnd(List<ChainStep> steps, int beginIndex) {
    int depth = 1;
    for (int i = beginIndex + 1; i < steps.length; i++) {
      if (steps[i].type == 'loop_begin') {
        depth++;
      } else if (steps[i].type == 'loop_end') {
        depth--;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1; // No matching end found
  }

  /// Validate chain code structure (check for balanced loops)
  static String? validateChainCode(ChainCode chainCode) {
    int loopDepth = 0;
    for (int i = 0; i < chainCode.steps.length; i++) {
      final step = chainCode.steps[i];
      if (step.type == 'loop_begin') {
        loopDepth++;
      } else if (step.type == 'loop_end') {
        loopDepth--;
        if (loopDepth < 0) {
          return 'Unmatched loop_end at step ${i + 1}';
        }
      }
    }
    if (loopDepth != 0) {
      return 'Unclosed loop blocks ($loopDepth remaining)';
    }
    return null; // Valid
  }
}
