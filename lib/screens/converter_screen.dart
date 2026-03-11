import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/ir_remote.dart';
import '../models/ir_signal.dart';
import '../providers/remote_provider.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  IRRemote? _selectedRemote;
  bool _showRaw = true;

  Future<void> _saveCurrentView() async {
    final remote = _selectedRemote;
    if (remote == null) return;

    if (!_showRaw) {
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Save Not Supported'),
          content: const Text(
            'Saving from the parsed view is not supported because raw-only signals '
            'cannot always be converted back to a specific protocol safely.\n\n'
            'Switch to RAW view to persist RAW timings to this remote.',
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
      return;
    }

    final updatedSignals = <IRSignal>[];
    for (final s in remote.signals) {
      if (s.type == 'raw' && s.data != null && s.data!.isNotEmpty) {
        updatedSignals.add(s);
      } else {
        final tx = s.toAndroidFormat();
        updatedSignals.add(
          IRSignal(
            name: s.name,
            type: 'raw',
            protocol: s.protocol,
            address: s.address,
            command: s.command,
            frequency: tx.carrierFrequency,
            dutyCycle: s.dutyCycle ?? 0.33,
            data: tx.pattern.join(' '),
            model: s.model,
          ),
        );
      }
    }

    final provider = Provider.of<RemoteProvider>(context, listen: false);
    final updatedRemote = remote.copyWith(
      signals: updatedSignals,
      updatedAt: DateTime.now(),
    );
    await provider.updateRemote(updatedRemote);

    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Saved RAW View'),
        content: const Text(
          'The current remote has been updated so that all signals are stored as RAW timings.',
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: const Text('Converter'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _selectedRemote == null ? null : _saveCurrentView,
          child: const Icon(
            CupertinoIcons.floppy_disk,
            size: 22,
          ),
        ),
      ),
      child: SafeArea(
        child: Consumer<RemoteProvider>(
          builder: (context, provider, _) {
            final remotes = provider.remotes;
            _selectedRemote ??= remotes.isNotEmpty ? remotes.first : null;

            return Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoButton(
                    padding: const EdgeInsets.all(14),
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: remotes.isEmpty
                        ? null
                        : () {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (context) => Container(
                                height: 300,
                                color: CupertinoColors.systemBackground,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 44,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          CupertinoButton(
                                            padding: EdgeInsets.zero,
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          CupertinoButton(
                                            padding: EdgeInsets.zero,
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Done'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: CupertinoPicker(
                                        itemExtent: 40,
                                        onSelectedItemChanged: (index) {
                                          setState(() {
                                            _selectedRemote = remotes[index];
                                          });
                                        },
                                        children: remotes
                                            .map(
                                              (r) => Center(
                                                child: Text(r.name),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedRemote?.name ?? 'No remote selected',
                          style: TextStyle(
                            color: _selectedRemote == null
                                ? CupertinoColors.placeholderText
                                : CupertinoColors.label,
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.chevron_down,
                          color: CupertinoColors.systemGrey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoSegmentedControl<bool>(
                    groupValue: _showRaw,
                    children: const {
                      true: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('RAW view'),
                      ),
                      false: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Parsed view'),
                      ),
                    },
                    onValueChanged: (value) {
                      setState(() {
                        _showRaw = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: Text(
                          _buildPreview(_selectedRemote, _showRaw),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _buildPreview(IRRemote? remote, bool raw) {
    if (remote == null) return 'No remote selected.';

    final buffer = StringBuffer();
    buffer.writeln('Filetype: IR signals file');
    buffer.writeln('Version: 1');
    buffer.writeln('#');

    for (final signal in remote.signals) {
      buffer.writeln('name: ${signal.name}');
      if (raw) {
        buffer.writeln('type: raw');
        buffer.writeln('frequency: ${signal.frequency ?? 38000}');
        buffer.writeln('duty_cycle: ${(signal.dutyCycle ?? 0.33).toStringAsFixed(6)}');
        buffer.writeln('data: ${signal.data ?? ''}');
      } else {
        buffer.writeln('type: parsed');
        buffer.writeln('protocol: ${signal.protocol ?? ''}');
        buffer.writeln('address: ${signal.address ?? '00 00 00 00'}');
        buffer.writeln('command: ${signal.command ?? '00 00 00 00'}');
      }
      buffer.writeln('#');
    }

    return buffer.toString();
  }
}

