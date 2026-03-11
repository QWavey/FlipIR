import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/remote_provider.dart';
import '../services/ir_transmitter_service.dart';
import '../models/ir_signal.dart';

class AllCommandsScreen extends StatefulWidget {
  const AllCommandsScreen({super.key});

  @override
  State<AllCommandsScreen> createState() => _AllCommandsScreenState();
}

class _AllCommandsScreenState extends State<AllCommandsScreen> {
  bool _isSending = false;
  bool _shouldCancel = false;
  int _currentCommand = 0;
  int _totalCommands = 0;
  double _sendProgress = 0.0;
  String _currentCommandName = '';

  Future<void> _sendAllCommands() async {
    final provider = Provider.of<RemoteProvider>(context, listen: false);
    final remote = provider.currentRemote;
    
    if (remote == null) return;

    // Get unique button names
    final Set<String> uniqueButtons = {};
    for (final signal in remote.signals) {
      uniqueButtons.add(signal.name);
    }
    final List<String> buttonNames = uniqueButtons.toList();

    setState(() {
      _isSending = true;
      _shouldCancel = false;
      _currentCommand = 0;
      _totalCommands = buttonNames.length;
      _sendProgress = 0.0;
    });

    for (int i = 0; i < buttonNames.length; i++) {
      if (_shouldCancel) break;

      final buttonName = buttonNames[i];
      setState(() {
        _currentCommand = i + 1;
        _sendProgress = (i + 1) / _totalCommands;
        _currentCommandName = buttonName;
      });

      // Get all variations of this button
      final variations = remote.signals
          .where((s) => s.name.toLowerCase() == buttonName.toLowerCase())
          .toList();

      // Send all variations
      for (final signal in variations) {
        if (_shouldCancel) break;
        try {
          await IRTransmitterService.transmit(signal);
        } catch (e) {
          // Continue
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _isSending = false;
      _sendProgress = 0.0;
    });

    if (mounted && !_shouldCancel) {
      _showMessage('Sent all $_currentCommand commands');
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.checkmark_circle_fill, color: CupertinoColors.systemGreen, size: 24),
            SizedBox(width: 8),
            Text('Complete'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteProvider>(
      builder: (context, provider, child) {
        final remote = provider.currentRemote;

        if (remote == null) {
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('All Commands'),
            ),
            child: const Center(child: Text('No remote selected')),
          );
        }

        // Get unique button names with their variation counts
        final Map<String, int> buttonCounts = {};
        for (final signal in remote.signals) {
          buttonCounts[signal.name] = (buttonCounts[signal.name] ?? 0) + 1;
        }
        final uniqueButtons = buttonCounts.keys.toList()..sort();

        return CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
            border: null,
            previousPageTitle: 'Back',
            middle: Text('All Commands', style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: !_isSending
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _sendAllCommands,
                    child: const Text('Send All', style: TextStyle(fontWeight: FontWeight.w600)),
                  )
                : null,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Send Progress
                if (_isSending)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CupertinoColors.activeBlue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sending $_currentCommandName',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_currentCommand of $_totalCommands commands',
                                    style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey.darkColor),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.all(8),
                              onPressed: () => setState(() => _shouldCancel = true),
                              color: CupertinoColors.systemRed,
                              borderRadius: BorderRadius.circular(10), minimumSize: Size(0, 0),
                              child: const Icon(CupertinoIcons.stop_fill, size: 18, color: CupertinoColors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _sendProgress,
                            backgroundColor: CupertinoColors.systemGrey5,
                            valueColor: const AlwaysStoppedAnimation<Color>(CupertinoColors.activeBlue),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(_sendProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey2.darkColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                
                // Commands List
                Expanded(
                  child: CupertinoListSection.insetGrouped(
                    margin: const EdgeInsets.all(16),
                    backgroundColor: Colors.transparent,
                    header: Text(
                      '${uniqueButtons.length} UNIQUE COMMANDS',
                      style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                    ),
                    children: uniqueButtons.map((buttonName) {
                      final variationCount = buttonCounts[buttonName]!;
                      final isCurrentlySending = _isSending && _currentCommandName == buttonName;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: isCurrentlySending 
                              ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                              : null,
                        ),
                        child: CupertinoListTile(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isCurrentlySending
                                    ? [CupertinoColors.systemGreen.withValues(alpha: 0.8), CupertinoColors.systemGreen]
                                    : [CupertinoColors.activeBlue.withValues(alpha: 0.8), CupertinoColors.activeBlue],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCurrentlySending ? CupertinoColors.systemGreen : CupertinoColors.activeBlue).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isCurrentlySending 
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.antenna_radiowaves_left_right,
                              color: CupertinoColors.white,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            buttonName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          subtitle: variationCount > 1
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '$variationCount variations',
                                    style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                                  ),
                                )
                              : null,
                          trailing: _isSending
                              ? (isCurrentlySending
                                  ? const CupertinoActivityIndicator()
                                  : const SizedBox(width: 20))
                              : const Icon(
                                  CupertinoIcons.chevron_forward,
                                  size: 20,
                                  color: CupertinoColors.systemGrey2,
                                ),
                          onTap: _isSending ? null : () => _sendButton(buttonName, remote),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendButton(String buttonName, remote) async {
    // Get all variations
    final variations = remote.signals
        .where((s) => s.name.toLowerCase() == buttonName.toLowerCase())
        .toList();

    if (variations.isEmpty) return;

    // If only one variation, send it directly
    if (variations.length == 1) {
      try {
        await IRTransmitterService.transmit(variations.first);
        _showQuickFeedback('✓ Sent $buttonName', CupertinoColors.systemGreen);
      } catch (e) {
        _showQuickFeedback('✗ Failed', CupertinoColors.systemRed);
      }
      return;
    }

    // Multiple variations - show progress and send all
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _VariationProgressDialog(
          buttonName: buttonName,
          variations: variations,
        );
      },
    );
  }

  void _showQuickFeedback(String message, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 1200), () {
      overlayEntry.remove();
    });
  }
}

class _VariationProgressDialog extends StatefulWidget {
  final String buttonName;
  final List<IRSignal> variations;

  const _VariationProgressDialog({
    required this.buttonName,
    required this.variations,
  });

  @override
  State<_VariationProgressDialog> createState() => _VariationProgressDialogState();
}

class _VariationProgressDialogState extends State<_VariationProgressDialog> {
  int _currentVariation = 0;
  double _progress = 0.0;
  bool _shouldCancel = false;

  @override
  void initState() {
    super.initState();
    _sendVariations();
  }

  Future<void> _sendVariations() async {
    for (int i = 0; i < widget.variations.length; i++) {
      if (_shouldCancel || !mounted) break;

      setState(() {
        _currentVariation = i + 1;
        _progress = (i + 1) / widget.variations.length;
      });

      try {
        await IRTransmitterService.transmit(widget.variations[i]);
      } catch (e) {
        // Continue
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Column(
        children: [
          const Icon(
            CupertinoIcons.antenna_radiowaves_left_right,
            size: 48,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(height: 12),
          Text('Trying ${widget.buttonName}'),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_currentVariation of ${widget.variations.length} variations',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: CupertinoColors.systemGrey5,
                valueColor: const AlwaysStoppedAnimation<Color>(CupertinoColors.activeBlue),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey.darkColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () {
            setState(() => _shouldCancel = true);
            Navigator.pop(context);
          },
          child: const Text('Stop'),
        ),
      ],
    );
  }
}
