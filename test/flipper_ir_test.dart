import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/ir_signal.dart';
import 'package:flutter_application_1/services/flipper_parser.dart';

const String _header = 'Filetype: IR signals file\nVersion: 1\n';

void main() {
  group('hex fields', () {
    test('Samsung32 address is read least significant byte first', () {
      final signal = IRSignal(
        name: 'Power',
        type: 'parsed',
        protocol: 'Samsung32',
        address: '07 00 00 00',
        command: '02 00 00 00',
      );
      final pattern = signal.toAndroidFormat().pattern;

      // Address 7 sends bits 0, 1 and 2 as ones, bit 3 as a zero
      expect(pattern[3], 1690);
      expect(pattern[5], 1690);
      expect(pattern[7], 1690);
      expect(pattern[9], 560);
    });

    test('malformed hex is a typed error', () {
      final signal = IRSignal(
        name: 'Power',
        type: 'parsed',
        protocol: 'NEC',
        address: '0G',
        command: '01',
      );
      expect(() => signal.toAndroidFormat(), throwsA(isA<IRFormatException>()));
    });
  });

  group('encoders', () {
    test('base NEC frame sends address, complement, command and complement', () {
      final pattern = IRSignal(
        name: 'Power',
        type: 'parsed',
        protocol: 'NEC',
        address: '04',
        command: '08',
      ).toAndroidFormat().pattern;

      // Header, 32 data bits, stop pulse
      expect(pattern.length, 2 + 32 * 2 + 1);
      // Address 0x04 has bit 2 set; its complement 0xFB has bit 2 clear
      expect(pattern[3 + 2 * 2], 1690);
      expect(pattern[3 + 2 * (8 + 2)], 560);
    });

    test('RC6 frames differ for different commands', () {
      IRSignal rc6(String command) => IRSignal(
            name: 'Button',
            type: 'parsed',
            protocol: 'RC6',
            address: '00',
            command: command,
          );

      expect(
        rc6('01').toAndroidFormat().pattern,
        isNot(equals(rc6('02').toAndroidFormat().pattern)),
      );
    });

    test('an unsupported protocol is an explicit error, not a fixed frame', () {
      final signal = IRSignal(
        name: 'Button',
        type: 'parsed',
        protocol: 'Foo',
        address: '01',
        command: '02',
      );
      expect(signal.transmitError, isNotNull);
      expect(() => signal.toAndroidFormat(), throwsA(isA<IRFormatException>()));
    });

    test('malformed raw timings are rejected', () {
      final signal = IRSignal(name: 'Raw', type: 'raw', data: '9000 abc 4500');
      expect(() => signal.toAndroidFormat(), throwsA(isA<IRFormatException>()));
    });
  });

  group('parseFlipperFile', () {
    test('an incomplete block does not leak fields into the next block', () {
      const content = '$_header'
          'name: Incomplete\n'
          'data: 1 2 3\n'
          '\n'
          'name: Good\n'
          'type: raw\n'
          'frequency: 38000\n';
      final remote = FlipperZeroParser.parseFlipperFile(content, 'test.ir');

      expect(remote.signals.map((s) => s.name), ['Good']);
      expect(remote.signals.single.data, isNull);
    });

    test('keys and type values are matched without regard to case', () {
      const content = '$_header'
          'Name: Mute\n'
          'Type: Raw\n'
          'Frequency: 38000\n'
          'Data: 100 200\n';

      expect(FlipperZeroParser.isValidFlipperFile(content), isTrue);
      final signal =
          FlipperZeroParser.parseFlipperFile(content, 'test.ir').signals.single;
      expect(signal.type, 'raw');
      expect(signal.data, '100 200');
    });

    test('a block with a malformed timing is dropped and the rest kept', () {
      const content = '$_header'
          'name: Bad\n'
          'type: raw\n'
          'data: 1 x 3\n'
          '\n'
          'name: Good\n'
          'type: raw\n'
          'data: 100 200\n';
      final remote = FlipperZeroParser.parseFlipperFile(content, 'test.ir');

      expect(remote.signals.map((s) => s.name), ['Good']);
    });
  });
}
