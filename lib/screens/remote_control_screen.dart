import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/remote_provider.dart';
import '../services/ir_transmitter_service.dart';
import '../services/settings_service.dart';
import '../models/ir_signal.dart';
import '../widgets/remote_button.dart';
import 'all_commands_screen.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  String? _lastPressed;
  
  // Variation sending state
  bool _isSendingVariations = false;
  int _currentVariation = 0;
  int _totalVariations = 0;
  double _variationProgress = 0.0;
  String _currentButtonName = '';

  Future<void> _sendAllVariations(String buttonName, List<IRSignal> allVariations) async {
    if (allVariations.isEmpty) return;

    // Only show progress UI for universal remotes (multiple variations)
    final showProgress = allVariations.length > 1;

    if (showProgress) {
      setState(() {
        _isSendingVariations = true;
        _currentVariation = 0;
        _totalVariations = allVariations.length;
        _variationProgress = 0.0;
        _currentButtonName = buttonName;
        _lastPressed = buttonName;
      });
    }

    // Send each variation
    for (int i = 0; i < allVariations.length; i++) {
      if (showProgress && (!_isSendingVariations || !mounted)) break;

      if (showProgress) {
        setState(() {
          _currentVariation = i + 1;
          _variationProgress = (i + 1) / _totalVariations;
        });
      }

      try {
        await IRTransmitterService.transmit(allVariations[i]);
      } catch (e) {
        // Continue to next variation
      }

      // Delay between signals (only for multiple variations)
      if (allVariations.length > 1) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

    if (showProgress && mounted) {
      setState(() {
        _isSendingVariations = false;
        _variationProgress = 0.0;
        _lastPressed = null;
      });
    }
  }

  void _stopSending() {
    setState(() {
      _isSendingVariations = false;
      _variationProgress = 0.0;
      _lastPressed = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteProvider>(
      builder: (context, provider, child) {
        final remote = provider.currentRemote;

        if (remote == null) {
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Remote Control'),
            ),
            child: const Center(child: Text('No remote selected')),
          );
        }

        return CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
            border: null,
            previousPageTitle: 'Back',
            middle: Text(remote.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (context) => const AllCommandsScreen()),
                );
              },
              child: const Icon(CupertinoIcons.list_bullet, size: 24),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // PERCENTAGE BAR - Shows when sending variations
                if (_isSendingVariations)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CupertinoColors.activeBlue.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trying $_currentButtonName',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Variation $_currentVariation of $_totalVariations',
                                    style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey.darkColor),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.all(10),
                              onPressed: _stopSending,
                              color: CupertinoColors.systemRed,
                              borderRadius: BorderRadius.circular(10), minimumSize: Size(0, 0),
                              child: const Icon(CupertinoIcons.stop_fill, size: 20, color: CupertinoColors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _variationProgress,
                            backgroundColor: CupertinoColors.systemGrey5,
                            valueColor: const AlwaysStoppedAnimation<Color>(CupertinoColors.activeBlue),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(_variationProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 15, color: CupertinoColors.activeBlue, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Testing signals...',
                              style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey2.darkColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Remote Control Buttons
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Power Button
                        if (_hasButton(remote, 'Power'))
                          _buildPowerButton(remote),
                        
                        const SizedBox(height: 24),

                        // Navigation Pad
                        if (_hasAnyNavigationButton(remote))
                          _buildNavigationCard(remote),
                        
                        const SizedBox(height: 20),

                        // Volume & Channel Controls
                        if (_hasAnyVolumeOrChannelButton(remote))
                          _buildControlsRow(remote),

                        const SizedBox(height: 20),

                        // Number Pad
                        if (_hasAnyNumberButton(remote))
                          _buildNumberPad(remote),

                        const SizedBox(height: 20),

                        // All Other Buttons
                        _buildAllButtons(remote),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPowerButton(remote) {
    final variations = _getAllVariations(remote, 'Power');
    return RemoteButton(
      label: 'POWER',
      icon: CupertinoIcons.power,
      onPressed: () => _sendAllVariations('Power', variations),
      allVariations: variations, // For hold-to-repeat
      isPressed: _lastPressed == 'Power',
      color: CupertinoColors.systemRed,
      size: SettingsService.buttonSize + 10,
    );
  }

  Widget _buildNavigationCard(remote) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Up
          if (_hasButton(remote, 'Up'))
            RemoteButton(
              label: '▲',
              onPressed: () => _sendAllVariations('Up', _getAllVariations(remote, 'Up')),
              allVariations: _getAllVariations(remote, 'Up'),
              isPressed: _lastPressed == 'Up',
              size: SettingsService.buttonSize,
            ),
          
          const SizedBox(height: 16),
          
          // Left, OK, Right
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasButton(remote, 'Left'))
                RemoteButton(
                  label: '◄',
                  onPressed: () => _sendAllVariations('Left', _getAllVariations(remote, 'Left')),
                  allVariations: _getAllVariations(remote, 'Left'),
                  isPressed: _lastPressed == 'Left',
                  size: SettingsService.buttonSize,
                ),
              
              const SizedBox(width: 16),
              
              if (_hasButton(remote, 'Ok') || _hasButton(remote, 'OK'))
                RemoteButton(
                  label: 'OK',
                  onPressed: () {
                    final variations = _hasButton(remote, 'Ok')
                        ? _getAllVariations(remote, 'Ok')
                        : _getAllVariations(remote, 'OK');
                    _sendAllVariations('OK', variations);
                  },
                  allVariations: _hasButton(remote, 'Ok') ? _getAllVariations(remote, 'Ok') : _getAllVariations(remote, 'OK'),
                  isPressed: _lastPressed == 'Ok' || _lastPressed == 'OK',
                  size: SettingsService.buttonSize + 20,
                  color: CupertinoColors.activeBlue,
                ),
              
              const SizedBox(width: 16),
              
              if (_hasButton(remote, 'Right'))
                RemoteButton(
                  label: '►',
                  onPressed: () => _sendAllVariations('Right', _getAllVariations(remote, 'Right')),
                  allVariations: _getAllVariations(remote, 'Right'),
                  isPressed: _lastPressed == 'Right',
                  size: SettingsService.buttonSize,
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Down
          if (_hasButton(remote, 'Down'))
            RemoteButton(
              label: '▼',
              onPressed: () => _sendAllVariations('Down', _getAllVariations(remote, 'Down')),
              allVariations: _getAllVariations(remote, 'Down'),
              isPressed: _lastPressed == 'Down',
              size: SettingsService.buttonSize,
            ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(remote) {
    return Row(
      children: [
        if (_hasAnyVolumeButton(remote))
          Expanded(child: _buildVolumeCard(remote)),
        
        if (_hasAnyVolumeButton(remote) && _hasAnyChannelButton(remote))
          const SizedBox(width: 16),
        
        if (_hasAnyChannelButton(remote))
          Expanded(child: _buildChannelCard(remote)),
      ],
    );
  }

  Widget _buildVolumeCard(remote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_hasButton(remote, 'Vol_up'))
            RemoteButton(
              label: 'VOL+',
              icon: CupertinoIcons.volume_up,
              onPressed: () => _sendAllVariations('Vol_up', _getAllVariations(remote, 'Vol_up')),
              allVariations: _getAllVariations(remote, 'Vol_up'),
              isPressed: _lastPressed == 'Vol_up',
              size: SettingsService.buttonSize - 5,
            ),
          
          if (_hasButton(remote, 'Mute'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: RemoteButton(
                label: 'MUTE',
                icon: CupertinoIcons.volume_mute,
                onPressed: () => _sendAllVariations('Mute', _getAllVariations(remote, 'Mute')),
                allVariations: _getAllVariations(remote, 'Mute'),
                isPressed: _lastPressed == 'Mute',
                size: SettingsService.buttonSize - 5,
                color: CupertinoColors.systemGrey,
              ),
            ),
          
          if (_hasButton(remote, 'Vol_down') || _hasButton(remote, 'Vol_dn'))
            RemoteButton(
              label: 'VOL-',
              icon: CupertinoIcons.volume_down,
              onPressed: () {
                final variations = _hasButton(remote, 'Vol_down')
                    ? _getAllVariations(remote, 'Vol_down')
                    : _getAllVariations(remote, 'Vol_dn');
                _sendAllVariations('Vol_down', variations);
              },
              allVariations: _hasButton(remote, 'Vol_down')
                  ? _getAllVariations(remote, 'Vol_down')
                  : _getAllVariations(remote, 'Vol_dn'),
              isPressed: _lastPressed == 'Vol_down' || _lastPressed == 'Vol_dn',
              size: SettingsService.buttonSize - 5,
            ),
        ],
      ),
    );
  }

  Widget _buildChannelCard(remote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_hasButton(remote, 'Ch_next') || _hasButton(remote, 'Ch_up'))
            RemoteButton(
              label: 'CH+',
              icon: CupertinoIcons.chevron_up,
              onPressed: () {
                final variations = _hasButton(remote, 'Ch_next')
                    ? _getAllVariations(remote, 'Ch_next')
                    : _getAllVariations(remote, 'Ch_up');
                _sendAllVariations('Ch_next', variations);
              },
              allVariations: _hasButton(remote, 'Ch_next')
                  ? _getAllVariations(remote, 'Ch_next')
                  : _getAllVariations(remote, 'Ch_up'),
              isPressed: _lastPressed == 'Ch_next' || _lastPressed == 'Ch_up',
              size: SettingsService.buttonSize - 5,
            ),
          
          const SizedBox(height: 40),
          
          if (_hasButton(remote, 'Ch_prev') || _hasButton(remote, 'Ch_down'))
            RemoteButton(
              label: 'CH-',
              icon: CupertinoIcons.chevron_down,
              onPressed: () {
                final variations = _hasButton(remote, 'Ch_prev')
                    ? _getAllVariations(remote, 'Ch_prev')
                    : _getAllVariations(remote, 'Ch_down');
                _sendAllVariations('Ch_prev', variations);
              },
              allVariations: _hasButton(remote, 'Ch_prev')
                  ? _getAllVariations(remote, 'Ch_prev')
                  : _getAllVariations(remote, 'Ch_down'),
              isPressed: _lastPressed == 'Ch_prev' || _lastPressed == 'Ch_down',
              size: SettingsService.buttonSize - 5,
            ),
        ],
      ),
    );
  }

  Widget _buildNumberPad(remote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: List.generate(12, (index) {
          String number;
          if (index < 9) {
            number = '${index + 1}';
          } else if (index == 9) {
            number = '0';
          } else {
            return const SizedBox();
          }

          if (_hasButton(remote, number) || _hasButton(remote, 'Num_$number')) {
            final variations = _hasButton(remote, number)
                ? _getAllVariations(remote, number)
                : _getAllVariations(remote, 'Num_$number');
            return RemoteButton(
              label: number,
              onPressed: () => _sendAllVariations(number, variations),
              allVariations: variations,
              isPressed: _lastPressed == number || _lastPressed == 'Num_$number',
              size: SettingsService.buttonSize - 10,
            );
          }
          
          return const SizedBox();
        }),
      ),
    );
  }

  Widget _buildAllButtons(remote) {
    final standardButtonNames = [
      'power', 'mute',
      'vol_up', 'vol_down', 'vol_dn',
      'ch_up', 'ch_down', 'ch_next', 'ch_prev',
      'up', 'down', 'left', 'right', 'ok',
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
      'num_0', 'num_1', 'num_2', 'num_3', 'num_4',
      'num_5', 'num_6', 'num_7', 'num_8', 'num_9',
    ];
    
    final Set<String> uniqueButtonNames = {};
    for (final signal in remote.signals) {
      if (!standardButtonNames.contains(signal.name.toLowerCase())) {
        uniqueButtonNames.add(signal.name);
      }
    }

    if (uniqueButtonNames.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Additional Controls',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: uniqueButtonNames.map((buttonName) {
              final variations = _getAllVariations(remote, buttonName);
              return RemoteButton(
                label: buttonName.toUpperCase(),
                onPressed: () => _sendAllVariations(buttonName, variations),
                allVariations: variations,
                isPressed: _lastPressed == buttonName,
                size: SettingsService.buttonSize + 20,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Helper methods
  List<IRSignal> _getAllVariations(remote, String name) {
    return remote.signals.where((s) => 
      s.name.toLowerCase() == name.toLowerCase()
    ).toList();
  }

  bool _hasButton(remote, String name) {
    return remote.signals.any((s) => s.name.toLowerCase() == name.toLowerCase());
  }

  bool _hasAnyNavigationButton(remote) {
    return _hasButton(remote, 'Up') || _hasButton(remote, 'Down') ||
           _hasButton(remote, 'Left') || _hasButton(remote, 'Right') ||
           _hasButton(remote, 'Ok') || _hasButton(remote, 'OK');
  }

  bool _hasAnyVolumeButton(remote) {
    return _hasButton(remote, 'Vol_up') || _hasButton(remote, 'Vol_down') ||
           _hasButton(remote, 'Vol_dn') || _hasButton(remote, 'Mute');
  }

  bool _hasAnyChannelButton(remote) {
    return _hasButton(remote, 'Ch_next') || _hasButton(remote, 'Ch_prev') ||
           _hasButton(remote, 'Ch_up') || _hasButton(remote, 'Ch_down');
  }

  bool _hasAnyVolumeOrChannelButton(remote) {
    return _hasAnyVolumeButton(remote) || _hasAnyChannelButton(remote);
  }

  bool _hasAnyNumberButton(remote) {
    for (int i = 0; i <= 9; i++) {
      if (_hasButton(remote, '$i') || _hasButton(remote, 'Num_$i')) {
        return true;
      }
    }
    return false;
  }
}
