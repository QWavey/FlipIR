import 'package:flutter/cupertino.dart';
import '../services/settings_service.dart';
import '../services/universal_remote_service.dart';

class CustomUrlsScreen extends StatefulWidget {
  const CustomUrlsScreen({super.key});

  @override
  State<CustomUrlsScreen> createState() => _CustomUrlsScreenState();
}

class _CustomUrlsScreenState extends State<CustomUrlsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _customUrls = {};

  @override
  void initState() {
    super.initState();
    _loadCustomUrls();
  }

  void _loadCustomUrls() {
    final savedUrls = SettingsService.customRemoteUrls;
    for (final deviceType in UniversalRemoteService.libraryUrls.keys) {
      final controller = TextEditingController(text: savedUrls[deviceType] ?? '');
      _controllers[deviceType] = controller;
      _customUrls[deviceType] = savedUrls[deviceType] ?? '';
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveUrl(String deviceType) async {
    final url = _controllers[deviceType]!.text.trim();
    if (url.isEmpty) {
      await SettingsService.removeCustomRemoteUrl(deviceType);
      _customUrls.remove(deviceType);
    } else {
      // Validate URL format
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        _showError('URL must start with http:// or https://');
        return;
      }
      await SettingsService.setCustomRemoteUrl(deviceType, url);
      _customUrls[deviceType] = url;
    }
    
    if (mounted) {
      SettingsService.lightHaptic();
      setState(() {});
      _showSuccess('URL saved for $deviceType');
    }
  }

  Future<void> _clearUrl(String deviceType) async {
    _controllers[deviceType]!.clear();
    await SettingsService.removeCustomRemoteUrl(deviceType);
    _customUrls.remove(deviceType);
    
    if (mounted) {
      SettingsService.lightHaptic();
      setState(() {});
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        previousPageTitle: 'Settings',
        middle: Text('Custom Remote URLs', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),
            
            CupertinoListSection.insetGrouped(
              header: const Text('BETA FEATURE'),
              footer: const Text(
                'Enter custom GitHub raw URLs for universal remote libraries. These will be used instead of the default URLs when downloading remotes. Leave empty to use defaults.',
              ),
              children: UniversalRemoteService.libraryUrls.keys.map((deviceType) {
                final hasCustomUrl = _customUrls.containsKey(deviceType) && 
                                    _customUrls[deviceType]!.isNotEmpty;
                return CupertinoListTile(
                  title: Text(deviceType),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _controllers[deviceType],
                        placeholder: 'https://raw.githubusercontent.com/...',
                        style: const TextStyle(fontSize: 14),
                        padding: const EdgeInsets.all(12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasCustomUrl)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _clearUrl(deviceType),
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: CupertinoColors.systemRed),
                              ),
                            ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _saveUrl(deviceType),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
