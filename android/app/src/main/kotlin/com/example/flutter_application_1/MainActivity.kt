package com.example.flutter_application_1

import android.content.Context
import android.hardware.ConsumerIrManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ir_transmitter"
    private var irManager: ConsumerIrManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize IR Manager
        irManager = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasIREmitter" -> {
                    val hasIR = irManager?.hasIrEmitter() ?: false
                    result.success(hasIR)
                }
                
                "getCarrierFrequencies" -> {
                    val frequencies = irManager?.carrierFrequencies
                    if (frequencies != null && frequencies.isNotEmpty()) {
                        // Convert ConsumerIrManager.CarrierFrequencyRange to List<Int>
                        val freqList = mutableListOf<Int>()
                        for (range in frequencies) {
                            // Add the minimum frequency from each range
                            freqList.add(range.minFrequency)
                        }
                        result.success(freqList)
                    } else {
                        // Return default 38kHz if no frequencies available
                        result.success(listOf(38000))
                    }
                }
                
                "transmit" -> {
                    try {
                        val carrierFrequency = call.argument<Int>("carrierFrequency") ?: 38000
                        val pattern = call.argument<List<Int>>("pattern")
                        
                        if (pattern == null || pattern.isEmpty()) {
                            result.error("INVALID_PATTERN", "Pattern is null or empty", null)
                            return@setMethodCallHandler
                        }

                        if (irManager?.hasIrEmitter() != true) {
                            result.error("NO_IR_EMITTER", "Device does not have IR emitter", null)
                            return@setMethodCallHandler
                        }

                        // Convert List<Int> to IntArray for IR transmission
                        val patternArray = pattern.toIntArray()
                        
                        // Transmit the IR signal
                        irManager?.transmit(carrierFrequency, patternArray)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TRANSMIT_ERROR", "Failed to transmit: ${e.message}", null)
                    }
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
