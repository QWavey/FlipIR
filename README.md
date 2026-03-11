# OnePlus IR Remote

A professional infrared remote control application for Android devices featuring iOS-style design and Flipper Zero file compatibility.

VERIFIED AND TESTED ON THE ONEPLUS 15/ EU MODEL.

DOWNLOAD("https://github.com/QWavey/FlipIR/releases/tag/beta-release")

## Overview

OnePlus IR Remote provides a comprehensive solution for controlling IR-enabled devices through your OnePlus smartphone. The application supports multiple device types including TVs, air conditioners, fans, audio systems, and more, with an intuitive Cupertino-style interface.

## Key Features

### Universal Remote Library
- Pre-configured remote databases for TV, AC, Fan, LED, Projector, Audio, and Cable Box
- Automatic download from curated device libraries
- Brand and model-specific configurations
- Custom remote URL support for advanced users

### File Import Capabilities
- Flipper Zero `.ir` file format support
- ZIP archive bulk import
- Custom IR signal creation
- File format validation and error handling

### Chain Codes (Automation)
- Create multi-step automation sequences
- Support for delays between commands
- Loop functionality (finite and infinite)
- Play, edit, and manage saved sequences
- Search and filter capabilities

### Advanced Features
- Real-time IR signal transmission
- Multiple protocol support (NEC, Samsung32, RC5, RC6, Sony SIRC)
- Raw signal handling with custom frequencies
- Button size customization
- Haptic and sound feedback
- Comprehensive settings management

### User Interface
- Native iOS Cupertino design system
- Dark and light mode support
- Intuitive navigation patterns
- Search and filter functionality
- Selection mode for batch operations
- Beta features toggle for advanced users

## Requirements

- **Platform:** Android device with IR blaster (OnePlus 6, 6T, 7, 7 Pro, 7T, 7T Pro, 8, 8 Pro, etc.)
- **Flutter:** 3.33 or higher
- **Dart:** 3.0 or higher
- **Minimum Android API:** 21 (Android 5.0)

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/oneplus-ir-remote.git
cd oneplus-ir-remote
```

2. Install dependencies:
```bash
flutter pub get
```

3. Build and run:
```bash
flutter run
```

### Build APK

```bash
flutter build apk --release
```

The APK will be available in `build/app/outputs/flutter-apk/app-release.apk`

## Usage

### Basic Operation

1. **Import a Remote:**
   - Tap the "Add New Remote" button
   - Choose "Pre-configured Library" for universal remotes
   - Or select "Import from File" for custom `.ir` files

2. **Control Devices:**
   - Select a remote from the home screen
   - Use the virtual buttons to send IR commands
   - Adjust button size in settings if needed

3. **Create Chain Codes:**
   - Navigate to a remote control screen
   - Tap the chain link icon in the toolbar
   - Add commands and delays to create automation sequences
   - Save and execute from the chain codes list

### Advanced Features

**Custom Remote URLs (Beta):**
- Enable beta features in Settings
- Navigate to Custom Remote URLs
- Enter alternative GitHub raw URLs for device libraries
- Useful for custom or updated remote databases

**Search and Filter:**
- Use the search bar on home screen to find remotes quickly
- Filter by device type (TV, AC, Fan, etc.)
- Search chain codes by name

## Project Structure

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

## Technologies

- **Framework:** Flutter 3.33+
- **UI Library:** Cupertino (iOS-style widgets)
- **State Management:** Provider 6.x
- **Storage:** SharedPreferences
- **File Handling:** file_picker, archive
- **HTTP:** http package for remote downloads
- **Permissions:** permission_handler

## Supported IR Protocols

- NEC (Common consumer electronics)
- Samsung32 (Samsung devices)
- RC5 / RC6 (Philips devices)
- Sony SIRC (Sony devices)
- Raw signals with custom carrier frequencies

## Configuration

### Settings Options

- **Feedback:** Haptics and sound effects toggle
- **Button Behavior:** Repeat delay adjustment
- **Display:** Button labels and size customization
- **General:** Delete confirmation, bulk operations
- **Beta Features:** Advanced customization options

## Contributing

Contributions are welcome. Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Create a Pull Request

## Troubleshooting

**IR Commands Not Working:**
- Verify your device has an IR blaster
- Check the remote is correctly imported
- Ensure proper line of sight to the target device
- Try adjusting carrier frequency for raw signals

**Import Failures:**
- Validate the `.ir` file format
- Check file permissions
- Ensure sufficient storage space
- Review error messages in debug console

**App Crashes:**
- Clear app cache in Settings
- Reinstall the application
- Check Android version compatibility

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments

- Flipper Zero community for IR file format documentation
- Universal remote control database contributors
- Flutter and Dart teams for the excellent framework

## Version

Current Version: 2.0.0

## Contact

For bug reports and feature requests, please use the GitHub Issues page.

---

Built with Flutter for OnePlus devices with IR capabilities.
