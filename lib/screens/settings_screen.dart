import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../providers/remote_provider.dart';
import 'custom_urls_screen.dart';
import 'converter_screen.dart';
import 'ir_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hapticsEnabled = SettingsService.hapticsEnabled;
  bool _soundEffectsEnabled = SettingsService.soundEffectsEnabled;
  bool _showButtonLabels = SettingsService.showButtonLabels;
  bool _confirmBeforeDelete = SettingsService.confirmBeforeDelete;
  bool _betaFeaturesEnabled = SettingsService.betaFeaturesEnabled;
  int _buttonRepeatDelay = SettingsService.buttonRepeatDelay;
  double _buttonSize = SettingsService.buttonSize;
  bool _developerModeEnabled = SettingsService.developerModeEnabled;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        previousPageTitle: 'Back',
        middle: Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),

            // Feedback Section
            CupertinoListSection.insetGrouped(
              header: const Text('FEEDBACK'),
              children: [
                CupertinoListTile(
                  title: const Text('Haptic Feedback'),
                  subtitle: const Text('Vibrate on button press'),
                  trailing: CupertinoSwitch(
                    value: _hapticsEnabled,
                    onChanged: (value) async {
                      setState(() => _hapticsEnabled = value);
                      await SettingsService.setHapticsEnabled(value);
                      if (value) {
                        SettingsService.mediumHaptic();
                      }
                    },
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Sound Effects'),
                  subtitle: const Text('Play sounds on button press'),
                  trailing: CupertinoSwitch(
                    value: _soundEffectsEnabled,
                    onChanged: (value) async {
                      setState(() => _soundEffectsEnabled = value);
                      await SettingsService.setSoundEffectsEnabled(value);
                    },
                  ),
                ),
              ],
            ),

            // Button Behavior Section
            CupertinoListSection.insetGrouped(
              header: const Text('BUTTON BEHAVIOR'),
              footer: const Text(
                'Hold-to-repeat only works for non-universal remotes',
              ),
              children: [
                CupertinoListTile(
                  title: const Text('Button Repeat Delay'),
                  subtitle: Text('${_buttonRepeatDelay}ms between repeats'),
                  trailing: SizedBox(
                    width: 120,
                    child: CupertinoSlider(
                      value: _buttonRepeatDelay.toDouble(),
                      min: 100,
                      max: 500,
                      divisions: 8,
                      onChanged: (value) {
                        setState(() => _buttonRepeatDelay = value.toInt());
                      },
                      onChangeEnd: (value) async {
                        await SettingsService.setButtonRepeatDelay(
                          value.toInt(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Display Section
            CupertinoListSection.insetGrouped(
              header: const Text('DISPLAY'),
              children: [
                CupertinoListTile(
                  title: const Text('Show Button Labels'),
                  subtitle: const Text('Display text on remote buttons'),
                  trailing: CupertinoSwitch(
                    value: _showButtonLabels,
                    onChanged: (value) async {
                      setState(() => _showButtonLabels = value);
                      await SettingsService.setShowButtonLabels(value);
                    },
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Button Size'),
                  subtitle: Text('Current: ${_buttonSize.toInt()}px'),
                  trailing: SizedBox(
                    width: 120,
                    child: CupertinoSlider(
                      value: _buttonSize,
                      min: 50,
                      max: 100,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() => _buttonSize = value);
                      },
                      onChangeEnd: (value) async {
                        await SettingsService.setButtonSize(value);
                      },
                    ),
                  ),
                ),
              ],
            ),

            // General Section
            CupertinoListSection.insetGrouped(
              header: const Text('GENERAL'),
              children: [
                CupertinoListTile(
                  title: const Text('Confirm Before Delete'),
                  subtitle: const Text('Show confirmation dialog'),
                  trailing: CupertinoSwitch(
                    value: _confirmBeforeDelete,
                    onChanged: (value) async {
                      setState(() => _confirmBeforeDelete = value);
                      await SettingsService.setConfirmBeforeDelete(value);
                    },
                  ),
                ),
                CupertinoListTile(
                  title: const Text(
                    'Delete All Remotes',
                    style: TextStyle(color: CupertinoColors.systemRed),
                  ),
                  subtitle: const Text('Remove all imported remotes'),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _deleteAllRemotes,
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ),
                ),
              ],
            ),

            // Beta Features Section
            CupertinoListSection.insetGrouped(
              header: const Text('BETA FEATURES'),
              footer: const Text(
                'Enable experimental features like custom remote URLs. These features may be unstable.',
              ),
              children: [
                CupertinoListTile(
                  title: const Text('Beta Features'),
                  subtitle: const Text('Enable experimental features'),
                  trailing: CupertinoSwitch(
                    value: _betaFeaturesEnabled,
                    onChanged: (value) async {
                      setState(() => _betaFeaturesEnabled = value);
                      await SettingsService.setBetaFeaturesEnabled(value);
                    },
                  ),
                ),
                if (_betaFeaturesEnabled)
                  CupertinoListTile(
                    title: const Text('Custom Remote URLs'),
                    subtitle: const Text('Set custom download URLs'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      color: CupertinoColors.systemGrey,
                    ),
                    onTap: () {
                      SettingsService.lightHaptic();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const CustomUrlsScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ),

            // Developer Section
            CupertinoListSection.insetGrouped(
              header: const Text('DEVELOPER'),
              footer: const Text(
                'Developer mode enables the converter and .ir tooling. Use with caution.',
              ),
              children: [
                CupertinoListTile(
                  title: const Text('Developer Mode'),
                  subtitle: const Text('Enable in-app .ir tools & converter'),
                  trailing: CupertinoSwitch(
                    value: _developerModeEnabled,
                    onChanged: (value) async {
                      setState(() => _developerModeEnabled = value);
                      await SettingsService.setDeveloperModeEnabled(value);
                    },
                  ),
                ),
                if (_developerModeEnabled)
                  CupertinoListTile(
                    title: const Text('IR File Editor'),
                    subtitle: const Text('Edit raw Flipper .ir text per remote'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      color: CupertinoColors.systemGrey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const IrEditorScreen(),
                        ),
                      );
                    },
                  ),
                if (_developerModeEnabled)
                  CupertinoListTile(
                    title: const Text('Converter'),
                    subtitle:
                        const Text('Preview parsed vs raw representations'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      color: CupertinoColors.systemGrey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const ConverterScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ),

            // About Section
            CupertinoListSection.insetGrouped(
              header: const Text('ABOUT'),
              children: [
                CupertinoListTile(
                  title: const Text('Version'),
                  trailing: Text(
                    '2.0.0',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('OnePlus IR Remote'),
                  subtitle: const Text('Universal infrared remote control'),
                ),
                CupertinoListTile(
                  title: const Text('Developer'),
                  trailing: Text(
                    'Florian',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAllRemotes() async {
    final provider = Provider.of<RemoteProvider>(context, listen: false);

    if (provider.remotes.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('No Remotes'),
          content: const Text('There are no remotes to delete.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete All Remotes?'),
        content: Text(
          'This will permanently delete all ${provider.remotes.length} remote${provider.remotes.length > 1 ? "s" : ""}. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (result == true) {
      final remoteIds = provider.remotes.map((r) => r.id).toList();
      for (final id in remoteIds) {
        await provider.deleteRemote(id);
      }

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text('All remotes have been deleted'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
