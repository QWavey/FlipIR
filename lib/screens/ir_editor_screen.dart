import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/ir_remote.dart';
import '../providers/remote_provider.dart';
import '../services/flipper_parser.dart';
import '../services/settings_service.dart';

class IrEditorScreen extends StatefulWidget {
  const IrEditorScreen({super.key});

  @override
  State<IrEditorScreen> createState() => _IrEditorScreenState();
}

class _IrEditorScreenState extends State<IrEditorScreen> {
  IRRemote? _selectedRemote;
  final TextEditingController _controller = TextEditingController();
  bool _isDirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadRemote(IRRemote? remote) {
    _selectedRemote = remote;
    _isDirty = false;
    if (remote == null) {
      _controller.text = '';
    } else {
      _controller.text = remote.toFlipperFile();
    }
  }

  Future<void> _saveAndReparse() async {
    final remote = _selectedRemote;
    if (remote == null) return;

    final content = _controller.text;
    if (!FlipperZeroParser.isValidFlipperFile(content)) {
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Invalid .ir File'),
          content: const Text(
            'The edited text does not look like a valid Flipper .ir file.\n\n'
            'Please check the header, name/type lines, and field syntax.',
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

    final policy = SettingsService.parsedImportPolicy;
    final convertParsedToRaw = policy == 'raw';

    try {
      final parsed = FlipperZeroParser.parseFlipperFile(
        content,
        '${remote.name}.ir',
        convertParsedToRaw: convertParsedToRaw,
      );

      if (parsed.signals.isEmpty) {
        await showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('No Signals Found'),
            content: const Text('The edited file does not contain any valid signals.'),
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

      final provider = Provider.of<RemoteProvider>(context, listen: false);
      final updated = remote.copyWith(
        signals: parsed.signals,
        updatedAt: DateTime.now(),
      );
      await provider.updateRemote(updated);

      setState(() {
        _isDirty = false;
      });

      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Saved'),
          content: Text(
            'Re-parsed successfully with ${parsed.signals.length} signal'
            '${parsed.signals.length == 1 ? '' : 's'}.',
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
    } catch (e) {
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Parse Error'),
          content: Text('Failed to parse edited .ir text:\n$e'),
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
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: const Text('IR File Editor'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isDirty ? _saveAndReparse : null,
          child: Icon(
            CupertinoIcons.floppy_disk,
            size: 22,
            color: _isDirty
                ? CupertinoColors.activeBlue
                : CupertinoColors.inactiveGray,
          ),
        ),
      ),
      child: SafeArea(
        child: Consumer<RemoteProvider>(
          builder: (context, provider, _) {
            final remotes = provider.remotes;
            if (_selectedRemote == null && remotes.isNotEmpty) {
              _loadRemote(remotes.first);
            }

            return Column(
              children: [
                const SizedBox(height: 12),
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
                                            _loadRemote(remotes[index]);
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
                const SizedBox(height: 8),
                if (_selectedRemote != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Editing Flipper .ir text for this remote. Changes will replace its signals when you tap the save icon.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CupertinoTextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                      onChanged: (_) {
                        if (!_isDirty) {
                          setState(() {
                            _isDirty = true;
                          });
                        }
                      },
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
}

