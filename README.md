# FlipIR

An Android app that turns the IR blaster on a OnePlus phone into a universal remote. It has an iOS-style interface and can import Flipper Zero `.ir` files. Receiving IR is not supported.

Tested on the OnePlus 15 (EU model).

[Download the beta](https://github.com/QWavey/FlipIR/releases/tag/beta-release)

## Features

**Remote library**
- Preconfigured remote databases for TVs, air conditioners, fans, LEDs, projectors, and audio systems
- Automatic download from curated device libraries
- Brand- and model-specific configurations
- Custom remote URLs for advanced users

**Import**
- Flipper Zero `.ir` files
- Bulk import from ZIP archives
- Custom IR signals
- File validation, with a count of files that could not be imported

**Chain codes (automation)**
- Multi-step sequences with delays between commands
- Finite or infinite loops
- Play, edit, and manage saved sequences
- Search chain codes by name

**Transmission and feedback**
- Real-time IR transmission
- Protocols: NEC, Samsung32, RC5, RC6, Sony SIRC
- Raw signals with custom carrier frequencies
- Adjustable button size, plus haptic and sound feedback

**Interface**
- Light and dark mode
- Search and filter on the home screen
- Selection mode for batch operations
- Beta features toggle

## Requirements

- An Android phone with an IR blaster (OnePlus 6, 6T, 7, 7 Pro, 7T, 7T Pro, 8, 8 Pro, and others)
- Dart 3.10.8 or newer, the minimum set in `pubspec.yaml` (use a Flutter release that includes it)
- Android 5.0 (API 21) or newer

## Install

### From source

```bash
git clone https://github.com/QWavey/FlipIR.git
cd FlipIR
flutter pub get
flutter run
```

### Release APK

```bash
flutter build apk --release
```

The APK ends up in `build/app/outputs/flutter-apk/app-release.apk`.

## Usage

1. **Add a remote:** tap **Add New Remote**, then choose **Pre-configured Library** or **Import from File**.
2. **Control a device:** select a remote on the home screen and press its buttons. If the buttons are hard to hit, change the button size in Settings.
3. **Make a chain code:** open a remote, tap the chain link icon in the toolbar, add commands and delays, then save. Run saved chain codes from the chain codes list.

## Beta features

Turn on beta features in Settings, open **Custom Remote URLs**, and enter alternative GitHub raw URLs for device libraries. This is useful for custom or updated remote databases.

## Project structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   ├── ir_remote.dart
│   ├── ir_signal.dart
│   └── chain_code.dart
├── providers/                # State management
│   └── remote_provider.dart
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── remote_control_screen.dart
│   ├── chain_code_editor_screen.dart
│   ├── chain_codes_list_screen.dart
│   ├── settings_screen.dart
│   └── custom_urls_screen.dart
├── services/                 # Business logic
│   ├── ir_transmitter_service.dart
│   ├── flipper_parser.dart
│   ├── universal_remote_service.dart
│   ├── chain_code_service.dart
│   └── settings_service.dart
└── widgets/                  # Reusable components
    ├── remote_button.dart
    └── device_type_dialog.dart
```

## Built with

- **Framework:** Flutter (with Dart 3.10.8 or newer)
- **UI:** Cupertino (iOS-style) widgets
- **State management:** Provider 6.x
- **Storage:** SharedPreferences
- **File handling:** file_picker, archive
- **HTTP:** the `http` package, for remote downloads
- **Permissions:** permission_handler

## Settings

- **Feedback:** haptics and sound effects on or off
- **Button behavior:** repeat delay
- **Display:** button labels and size
- **General:** delete confirmation and bulk operations
- **Beta features:** advanced customization

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push the branch (`git push origin feature/your-feature`).
5. Open a pull request.

## Troubleshooting

**IR commands don't work**
- Check that your phone has an IR blaster.
- Check that the remote was imported correctly.
- Make sure you have a clear line of sight to the device.
- For raw signals, try adjusting the carrier frequency.

**Imports fail**
- Check that the `.ir` file format is valid.
- Check file permissions and free storage space.
- Check the import message for how many files were not imported.

**The app crashes**
- Clear the app cache in Settings.
- Reinstall the app.
- Check that your Android version is supported.

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgments

- The Flipper Zero community, for IR file format documentation
- Contributors to the universal remote databases
- The Flutter and Dart teams

## Contact

For bug reports and feature requests, use the GitHub Issues page.
