import 'package:flutter/services.dart';
import '../models/ir_signal.dart';

class IRTransmitterService {
  static const MethodChannel _channel = MethodChannel('ir_transmitter');

  /// Check if device has IR blaster
  static Future<bool> hasIREmitter() async {
    try {
      final bool? result = await _channel.invokeMethod('hasIREmitter');
      return result ?? false;
    } catch (e) {
      print('Error checking IR emitter: $e');
      return false;
    }
  }

  /// Get available carrier frequencies
  static Future<List<int>> getCarrierFrequencies() async {
    try {
      final List<dynamic>? result = 
          await _channel.invokeMethod('getCarrierFrequencies');
      return result?.cast<int>() ?? [38000];
    } catch (e) {
      print('Error getting carrier frequencies: $e');
      return [38000];
    }
  }

  /// Transmit IR signal
  static Future<bool> transmit(IRSignal signal) async {
    try {
      final transmitData = signal.toAndroidFormat();
      
      final bool? result = await _channel.invokeMethod('transmit', {
        'carrierFrequency': transmitData.carrierFrequency,
        'pattern': transmitData.pattern,
      });
      
      return result ?? false;
    } catch (e) {
      print('Error transmitting IR signal: $e');
      return false;
    }
  }

  /// Transmit raw pattern directly
  static Future<bool> transmitRaw({
    required int carrierFrequency,
    required List<int> pattern,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod('transmit', {
        'carrierFrequency': carrierFrequency,
        'pattern': pattern,
      });
      
      return result ?? false;
    } catch (e) {
      print('Error transmitting raw IR: $e');
      return false;
    }
  }
}
