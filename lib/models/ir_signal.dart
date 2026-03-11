// IR Signal Model - represents a single IR button/command
class IRSignal {
  final String name;
  final String type; // 'parsed' or 'raw'
  final String? protocol; // For parsed signals (e.g., 'Samsung32', 'NEC')
  final String? address; // For parsed signals
  final String? command; // For parsed signals
  final int? frequency; // For raw signals (e.g., 38000)
  final double? dutyCycle; // For raw signals (e.g., 0.33)
  final String? data; // For raw signals - space-separated timing values
  final String? model; // Model/brand extracted from comment lines

  IRSignal({
    required this.name,
    required this.type,
    this.protocol,
    this.address,
    this.command,
    this.frequency,
    this.dutyCycle,
    this.data,
    this.model,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'protocol': protocol,
      'address': address,
      'command': command,
      'frequency': frequency,
      'dutyCycle': dutyCycle,
      'data': data,
      'model': model,
    };
  }

  // Create from JSON
  factory IRSignal.fromJson(Map<String, dynamic> json) {
    return IRSignal(
      name: json['name'] as String,
      type: json['type'] as String,
      protocol: json['protocol'] as String?,
      address: json['address'] as String?,
      command: json['command'] as String?,
      frequency: json['frequency'] as int?,
      dutyCycle: json['dutyCycle'] as double?,
      data: json['data'] as String?,
      model: json['model'] as String?,
    );
  }

  // Convert to Flipper Zero format string
  String toFlipperFormat() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('name: $name');
    buffer.writeln('type: $type');

    if (type == 'parsed') {
      buffer.writeln('protocol: $protocol');
      buffer.writeln('address: $address');
      buffer.writeln('command: $command');
    } else if (type == 'raw') {
      buffer.writeln('frequency: $frequency');
      buffer.writeln('duty_cycle: ${dutyCycle?.toStringAsFixed(5)}');
      buffer.writeln('data: $data');
    }

    return buffer.toString();
  }

  // Convert to Android IR format (carrier frequency in Hz, pattern in microseconds)
  IRTransmitData toAndroidFormat() {
    if (type == 'parsed') {
      // Convert parsed protocol to raw pattern
      return _convertParsedToRaw();
    } else {
      // Parse raw data
      return _parseRawData();
    }
  }

  IRTransmitData _convertParsedToRaw() {
    // Protocol conversion logic
    List<int> pattern = [];
    int carrierFrequency = 38000; // Default

    final proto = protocol?.toLowerCase() ?? '';

    switch (proto) {
      case 'samsung32':
        pattern = _encodeSamsung32();
        break;
      case 'kaseikyo':
        pattern = _encodeKaseikyo();
        break;
      case 'nec':
      case 'necext':
      case 'nec42':
      case 'nec42ext':
        pattern = _encodeNEC(proto);
        break;
      case 'rc5':
      case 'rc5x':
        carrierFrequency = 36000;
        pattern = _encodeRC5(proto == 'rc5x');
        break;
      case 'rc6':
        pattern = _encodeRC6();
        break;
      case 'rca':
        pattern = _encodeRCA();
        break;
      case 'sony':
      case 'sirc':
      case 'sirc15':
      case 'sirc20':
        carrierFrequency = 40000;
        pattern = _encodeSony(proto);
        break;
      default:
        // Generic encoding
        pattern = _encodeGeneric();
    }

    return IRTransmitData(
      carrierFrequency: carrierFrequency,
      pattern: pattern,
    );
  }

  List<int> _encodeSamsung32() {
    // Samsung32 protocol encoding
    // Header: 4500µs pulse, 4500µs space
    // Logical 0: 560µs pulse, 560µs space
    // Logical 1: 560µs pulse, 1690µs space
    // End: 560µs pulse

    List<int> pattern = [4500, 4500]; // Header

    // Parse address and command (hex strings like "07 00 00 00")
    String addrHex = address?.replaceAll(' ', '') ?? '00000000';
    String cmdHex = command?.replaceAll(' ', '') ?? '00000000';

    // Combine address and command into a 32-bit value (lower 16 bits: address, upper 16 bits: command)
    final int addressValue = int.parse(addrHex, radix: 16);
    final int commandValue = int.parse(cmdHex, radix: 16);
    final int combined = (addressValue & 0xFFFF) | ((commandValue & 0xFFFF) << 16);

    // Encode 32 bits (LSB first from combined value)
    for (int i = 0; i < 32; i++) {
      pattern.add(560); // Pulse
      if (((combined >> i) & 1) == 1) {
        pattern.add(1690); // Logical 1 space
      } else {
        pattern.add(560); // Logical 0 space
      }
    }

    pattern.add(560); // End pulse

    return pattern;
  }

  List<int> _encodeNEC(String variant) {
    // NEC family encoding
    // Base timings
    const int headerPulse = 9000;
    const int headerSpace = 4500;
    const int bitPulse = 560;
    const int bitSpace0 = 560;
    const int bitSpace1 = 1690;

    // Determine bit lengths from variant
    int addrBits;
    int cmdBits;
    switch (variant) {
      case 'necext':
        addrBits = 16; // FF FF 00 00 mask
        cmdBits = 16; // FF FF 00 00 mask
        break;
      case 'nec42':
        addrBits = 13; // FF 1F 00 00 mask
        cmdBits = 8; // FF 00 00 00 mask
        break;
      case 'nec42ext':
        addrBits = 26; // FF FF FF 03 mask
        cmdBits = 16; // FF FF 00 00 mask
        break;
      default:
        // 'nec' base variant
        addrBits = 8; // FF 00 00 00 mask
        cmdBits = 8; // FF 00 00 00 mask
        break;
    }

    List<int> pattern = [headerPulse, headerSpace];

    String addrHex = address?.replaceAll(' ', '') ?? '00000000';
    String cmdHex = command?.replaceAll(' ', '') ?? '00000000';

    int addressValue = int.parse(addrHex, radix: 16);
    int commandValue = int.parse(cmdHex, radix: 16);

    void encodeBits(int value, int bits) {
      for (int i = 0; i < bits; i++) {
        pattern.add(bitPulse);
        final isOne = ((value >> i) & 0x1) == 1;
        pattern.add(isOne ? bitSpace1 : bitSpace0);
      }
    }

    encodeBits(addressValue, addrBits);
    encodeBits(commandValue, cmdBits);

    pattern.add(bitPulse); // End pulse
    return pattern;
  }

  List<int> _encodeRC5(bool isExtended) {
    // RC5 / RC5X protocol (Manchester encoding, 36 kHz)
    // Unit time T ≈ 888 µs, each bit is 2T.
    const int T = 888;

    // Prepare raw address & command
    final addrHex = address?.replaceAll(' ', '') ?? '00000000';
    final cmdHex = command?.replaceAll(' ', '') ?? '00000000';
    int addr = int.parse(addrHex, radix: 16) & 0x1F; // 5 bits
    int cmd = int.parse(cmdHex, radix: 16);

    // Command bits: RC5 uses 6 bits, RC5X uses 7 bits
    final int cmdBits = isExtended ? 7 : 6;
    cmd &= (1 << cmdBits) - 1;

    // Build frame: S1=1, S2=1, Toggle=0, then address (5 bits), command (6/7 bits)
    List<int> bits = [];
    bits.add(1); // S1
    bits.add(1); // S2
    bits.add(0); // toggle

    for (int i = 4; i >= 0; i--) {
      bits.add((addr >> i) & 0x1);
    }
    for (int i = cmdBits - 1; i >= 0; i--) {
      bits.add((cmd >> i) & 0x1);
    }

    // Manchester encode: each bit is 2T, represented as [mark, space] pairs.
    // 1 => mark T, space T; 0 => space T, mark T, but pattern must always start with mark.
    List<int> pattern = [];

    // Start with first half of first bit as mark
    int lastLevel = 1; // 1 = mark, 0 = space
    void appendHalf(int level) {
      if (pattern.isEmpty) {
        // initialize
        pattern.add(level == 1 ? T : 0);
        pattern.add(level == 0 ? T : 0);
      } else {
        // extend last space or mark
        if (level == 1) {
          // mark
          if (lastLevel == 1) {
            pattern[pattern.length - 2] += T;
          } else {
            pattern.add(T);
            pattern.add(0);
          }
        } else {
          // space
          if (lastLevel == 0) {
            pattern[pattern.length - 1] += T;
          } else {
            pattern.add(0);
            pattern.add(T);
          }
        }
      }
      lastLevel = level;
    }

    for (final bit in bits) {
      if (bit == 1) {
        // 1: high then low
        appendHalf(1);
        appendHalf(0);
      } else {
        // 0: low then high
        appendHalf(0);
        appendHalf(1);
      }
    }

    // Clean up any leading zeros
    if (pattern.length >= 2 && pattern[0] == 0) {
      pattern.removeAt(0);
      pattern[0] = T;
    }

    return pattern;
  }

  List<int> _encodeRC6() {
    // RC6 mode 0 (basic) – approximate but structured:
    // Leader: 6T mark (≈2666µs), 2T space (≈889µs), T ≈ 444µs.
    const int T = 444;
    List<int> pattern = [6 * T, 2 * T];

    // RC6 mode 0 uses: start bit (1), 3 mode bits (000), toggle bit, 8-bit address, 8-bit command
    final addrHex = address?.replaceAll(' ', '') ?? '00000000';
    final cmdHex = command?.replaceAll(' ', '') ?? '00000000';
    int addr = int.parse(addrHex, radix: 16) & 0xFF;
    int cmd = int.parse(cmdHex, radix: 16) & 0xFF;

    List<int> bits = [];
    bits.add(1); // start
    bits.add(0);
    bits.add(0);
    bits.add(0); // mode 0
    bits.add(0); // toggle (we keep 0)
    for (int i = 7; i >= 0; i--) {
      bits.add((addr >> i) & 0x1);
    }
    for (int i = 7; i >= 0; i--) {
      bits.add((cmd >> i) & 0x1);
    }

    // RC6 uses bi-phase (Manchester) coding with different timing for the first (start) bit.
    // For simplicity we encode all bits with 2T high / 2T low (1) or 2T low / 2T high (0).
    void appendBit(int bit) {
      if (bit == 1) {
        pattern.add(2 * T);
        pattern.add(2 * T);
      } else {
        pattern.add(2 * T);
        pattern.add(2 * T);
      }
    }

    for (final b in bits) {
      appendBit(b);
    }

    return pattern;
  }

  List<int> _encodeKaseikyo() {
    // Kaseikyo (Panasonic) – leader 3360/1650, then 48 bits (full frame).
    // We respect the address/command bit capacities from the Flipper table.
    const int pulse = 420; // base unit; 8T and 4T approximated by leader
    const int bitPulse = 420;
    const int bitSpace0 = 420;
    const int bitSpace1 = 1260;

    List<int> pattern = [3360, 1650];

    String addrHex = address?.replaceAll(' ', '') ?? '00000000';
    String cmdHex = command?.replaceAll(' ', '') ?? '00000000';
    int addr = int.parse(addrHex, radix: 16);
    int cmd = int.parse(cmdHex, radix: 16);

    // 26-bit address, 10-bit command
    void encodeBits(int value, int bits) {
      for (int i = 0; i < bits; i++) {
        pattern.add(bitPulse);
        final isOne = ((value >> i) & 0x1) == 1;
        pattern.add(isOne ? bitSpace1 : bitSpace0);
      }
    }

    encodeBits(addr, 26);
    encodeBits(cmd, 10);

    return pattern;
  }

  List<int> _encodeRCA() {
    // RCA: 4000/4000 header, 4-bit address + 8-bit command (both LSB first)
    const int headerPulse = 4000;
    const int headerSpace = 4000;
    const int bitPulse = 560;
    const int bitSpace0 = 560;
    const int bitSpace1 = 1690;

    List<int> pattern = [headerPulse, headerSpace];

    String addrHex = address?.replaceAll(' ', '') ?? '00000000';
    String cmdHex = command?.replaceAll(' ', '') ?? '00000000';
    int addr = int.parse(addrHex, radix: 16) & 0x0F; // 4 bits
    int cmd = int.parse(cmdHex, radix: 16) & 0xFF; // 8 bits

    void encodeBits(int value, int bits) {
      for (int i = 0; i < bits; i++) {
        pattern.add(bitPulse);
        final isOne = ((value >> i) & 0x1) == 1;
        pattern.add(isOne ? bitSpace1 : bitSpace0);
      }
    }

    encodeBits(addr, 4);
    encodeBits(cmd, 8);

    pattern.add(bitPulse);
    return pattern;
  }

  List<int> _encodeSony(String variant) {
    // Sony SIRC protocols – header 2400µs pulse, then bits with 600/1200 widths.
    const int headerPulse = 2400;
    const int bitPulse = 600;
    const int bitSpace0 = 600;
    const int bitSpace1 = 1200;

    int addrBits;
    int cmdBits = 7; // max command ~7 bits for all SIRC variants
    switch (variant) {
      case 'sirc15':
        addrBits = 8;
        break;
      case 'sirc20':
        addrBits = 13;
        break;
      default:
        // sirc
        addrBits = 5;
        break;
    }

    List<int> pattern = [headerPulse, bitSpace0];

    String addrHex = address?.replaceAll(' ', '') ?? '00000000';
    String cmdHex = command?.replaceAll(' ', '') ?? '00000000';
    int addr = int.parse(addrHex, radix: 16);
    int cmd = int.parse(cmdHex, radix: 16);

    void encodeBits(int value, int bits) {
      for (int i = 0; i < bits; i++) {
        pattern.add(bitPulse);
        final isOne = ((value >> i) & 0x1) == 1;
        pattern.add(isOne ? bitSpace1 : bitSpace0);
      }
    }

    // SIRC sends command first, then address
    encodeBits(cmd, cmdBits);
    encodeBits(addr, addrBits);

    return pattern;
  }

  List<int> _encodeGeneric() {
    // Generic fallback
    return [9000, 4500, 560, 560, 560];
  }

  IRTransmitData _parseRawData() {
    if (data == null || data!.isEmpty) {
      return IRTransmitData(carrierFrequency: 38000, pattern: []);
    }

    // Parse space-separated timing values
    List<int> pattern = data!
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    return IRTransmitData(
      carrierFrequency: frequency ?? 38000,
      pattern: pattern,
    );
  }
}

// Android IR transmit data
class IRTransmitData {
  final int carrierFrequency;
  final List<int> pattern;

  IRTransmitData({
    required this.carrierFrequency,
    required this.pattern,
  });
}
