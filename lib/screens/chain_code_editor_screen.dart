import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/chain_code.dart';
import '../models/ir_remote.dart';
import '../providers/remote_provider.dart';
import '../services/chain_code_service.dart';
import '../services/settings_service.dart';
import 'chain_codes_list_screen.dart';

class ChainCodeEditorScreen extends StatefulWidget {
  final ChainCode? existingChainCode;

  const ChainCodeEditorScreen({super.key, this.existingChainCode});

  @override
  State<ChainCodeEditorScreen> createState() => _ChainCodeEditorScreenState();
}

class _ChainCodeEditorScreenState extends State<ChainCodeEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<ChainStep> _steps = [];
  bool _isExecuting = false;
  String _executionStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.existingChainCode != null) {
      _nameController.text = widget.existingChainCode!.name;
      _steps.addAll(widget.existingChainCode!.steps);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addCommandStep() {
    final provider = Provider.of<RemoteProvider>(context, listen: false);
    if (provider.remotes.isEmpty) {
      _showError('No remotes available. Import a remote first.');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => _SelectCommandDialog(
        remotes: provider.remotes,
        onSelected: (remoteId, signalName) {
          setState(() {
            _steps.add(
              ChainStep.command(signalName: signalName, remoteId: remoteId),
            );
          });
        },
      ),
    );
  }

  void _addHoldStep() {
    final provider = Provider.of<RemoteProvider>(context, listen: false);
    if (provider.remotes.isEmpty) {
      _showError('No remotes available. Import a remote first.');
      return;
    }

    // First ask for hold duration
    final durationController = TextEditingController(text: '1000');

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Hold Duration'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            placeholder: '1000',
            suffix: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'ms',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final holdMs = int.tryParse(durationController.text) ?? 1000;
              Navigator.pop(context);

              // Now pick which command to hold
              showCupertinoModalPopup(
                context: context,
                builder: (context) => _SelectCommandDialog(
                  remotes: provider.remotes,
                  onSelected: (remoteId, signalName) {
                    setState(() {
                      _steps.add(
                        ChainStep.hold(
                          signalName: signalName,
                          remoteId: remoteId,
                          holdMs: holdMs,
                        ),
                      );
                    });
                  },
                ),
              );
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  void _addDelayStep() {
    final controller = TextEditingController(text: '1000');

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Delay'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '1000',
            suffix: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'ms',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final delay = int.tryParse(controller.text) ?? 1000;
              setState(() {
                _steps.add(ChainStep.delay(delay));
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addLoopBegin() {
    final controller = TextEditingController(text: '3');
    bool isInfinite = false;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Add Loop Start'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('How many times should the loop repeat?'),
              const SizedBox(height: 12),
              Row(
                children: [
                  CupertinoSwitch(
                    value: isInfinite,
                    onChanged: (value) {
                      setDialogState(() {
                        isInfinite = value;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('Infinite Loop'),
                ],
              ),
              if (!isInfinite) ...[
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  placeholder: '3',
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'times',
                      style: TextStyle(
                        color: CupertinoColors.systemGrey,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final count = isInfinite
                    ? null
                    : (int.tryParse(controller.text) ?? 3);
                setState(() {
                  _steps.add(ChainStep.loopBegin(count));
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addLoopEnd() {
    setState(() {
      _steps.add(ChainStep.loopEnd());
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  void _editStep(int index) {
    final step = _steps[index];

    if (step.type == 'delay') {
      final controller = TextEditingController(text: step.delayMs.toString());

      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Edit Delay'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              suffix: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  'ms',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final delay = int.tryParse(controller.text) ?? 1000;
                setState(() {
                  _steps[index] = ChainStep.delay(delay);
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } else if (step.type == 'loop_begin') {
      final controller = TextEditingController(
        text: step.loopCount?.toString() ?? '',
      );
      bool isInfinite = step.loopCount == null;

      showCupertinoDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => CupertinoAlertDialog(
            title: const Text('Edit Loop'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    CupertinoSwitch(
                      value: isInfinite,
                      onChanged: (value) {
                        setDialogState(() {
                          isInfinite = value;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Infinite Loop'),
                  ],
                ),
                if (!isInfinite) ...[
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    placeholder: '3',
                    suffix: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        'times',
                        style: TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  final count = isInfinite
                      ? null
                      : (int.tryParse(controller.text) ?? 3);
                  setState(() {
                    _steps[index] = ChainStep.loopBegin(count);
                  });
                  Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      );
    } else if (step.type == 'hold') {
      final controller = TextEditingController(
        text: step.holdMs?.toString() ?? '1000',
      );

      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Edit Hold Duration'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              placeholder: '1000',
              suffix: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  'ms',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final holdMs = int.tryParse(controller.text) ?? 1000;
                setState(() {
                  _steps[index] = ChainStep.hold(
                    signalName: step.signalName ?? '',
                    remoteId: step.remoteId ?? '',
                    holdMs: holdMs,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveChainCode() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a name');
      return;
    }

    if (_steps.isEmpty) {
      _showError('Please add at least one step');
      return;
    }

    // Validate chain code structure
    final chainCode = ChainCode(
      id:
          widget.existingChainCode?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      steps: _steps,
      createdAt: widget.existingChainCode?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final validationError = ChainCodeService.validateChainCode(chainCode);
    if (validationError != null) {
      _showError('Invalid structure: $validationError');
      return;
    }

    final success = await ChainCodeService.saveChainCode(chainCode);

    if (success) {
      if (mounted) {
        await _showSuccess('Chain code saved successfully!');
        // Go back to chain codes list with the saved chain code
        if (mounted) {
          Navigator.pop(context, chainCode);
        }
      }
    } else {
      if (mounted) {
        _showError('Failed to save chain code');
      }
    }
  }

  Future<void> _executeChainCode() async {
    if (_steps.isEmpty) {
      _showError('No steps to execute');
      return;
    }

    // Validate structure before executing
    final tempChainCode = ChainCode(
      id: 'temp',
      name: 'Test',
      steps: _steps,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final validationError = ChainCodeService.validateChainCode(tempChainCode);
    if (validationError != null) {
      _showError('Cannot execute: $validationError');
      return;
    }

    setState(() {
      _isExecuting = true;
      _executionStatus = 'Starting...';
    });

    final provider = Provider.of<RemoteProvider>(context, listen: false);

    final success = await ChainCodeService.executeChainCode(
      tempChainCode,
      provider.remotes,
      (status) {
        if (mounted) {
          setState(() {
            _executionStatus = status;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isExecuting = false;
      });

      if (success) {
        _showSuccess('Execution completed!');
      }
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
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccess(String message) async {
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
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
        middle: Text(
          widget.existingChainCode == null
              ? 'New Chain Code'
              : 'Edit Chain Code',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isExecuting)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  SettingsService.lightHaptic();
                  Navigator.pushReplacement(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const ChainCodesListScreen(),
                    ),
                  );
                },
                child: const Icon(CupertinoIcons.list_bullet),
              ),
            if (!_isExecuting)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _executeChainCode,
                child: const Icon(CupertinoIcons.play_fill),
              ),
            if (!_isExecuting)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saveChainCode,
                child: const Icon(CupertinoIcons.floppy_disk),
              ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Execution Status
            if (_isExecuting)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemBlue,
                ),
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _executionStatus,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Name Input
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoTextField(
                controller: _nameController,
                placeholder: 'Chain Code Name (e.g., Movie Mode)',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Info Text
            if (_steps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.info_circle,
                      size: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Long press to reorder • ${_steps.length} step${_steps.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Steps List
            Expanded(
              child: _steps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.link,
                            size: 64,
                            color: CupertinoColors.systemGrey.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No steps added yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: CupertinoColors.systemGrey,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add commands, delays, and loops below',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _steps.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex--;
                          }
                          final step = _steps.removeAt(oldIndex);
                          _steps.insert(newIndex, step);
                        });
                      },
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return _StepItemIOS(
                          key: ValueKey('step-$index-${step.hashCode}'),
                          step: step,
                          index: index,
                          onRemove: () => _removeStep(index),
                          onEdit: (step.type == 'delay' ||
                                  step.type == 'loop_begin' ||
                                  step.type == 'hold')
                              ? () => _editStep(index)
                              : null,
                        );
                      },
                    ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: const Border(
                  top: BorderSide(color: CupertinoColors.separator, width: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          onPressed: _isExecuting ? null : _addCommandStep,
                          color: CupertinoColors.activeBlue,
                          padding: const EdgeInsets.all(12),
                          borderRadius: BorderRadius.circular(12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.add, size: 20),
                              SizedBox(width: 8),
                              Text('Command'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          onPressed: _isExecuting ? null : _addDelayStep,
                          color: CupertinoColors.systemOrange,
                          padding: const EdgeInsets.all(12),
                          borderRadius: BorderRadius.circular(12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.timer, size: 20),
                              SizedBox(width: 8),
                              Text('Delay'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          onPressed: _isExecuting ? null : _addLoopBegin,
                          color: CupertinoColors.systemPurple,
                          padding: const EdgeInsets.all(12),
                          borderRadius: BorderRadius.circular(12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.repeat, size: 20),
                              SizedBox(width: 8),
                              Text('Loop Start'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          onPressed: _isExecuting ? null : _addLoopEnd,
                          color: CupertinoColors.systemGreen,
                          padding: const EdgeInsets.all(12),
                          borderRadius: BorderRadius.circular(12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.checkmark_alt, size: 20),
                              SizedBox(width: 8),
                              Text('Loop End'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          onPressed: _isExecuting ? null : _addHoldStep,
                          color: CupertinoColors.systemTeal,
                          padding: const EdgeInsets.all(12),
                          borderRadius: BorderRadius.circular(12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.hand_raised, size: 20),
                              SizedBox(width: 8),
                              Text('Hold Key'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItemIOS extends StatelessWidget {
  final ChainStep step;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  const _StepItemIOS({
    super.key,
    required this.step,
    required this.index,
    required this.onRemove,
    this.onEdit,
  });

  Color _getStepColor() {
    switch (step.type) {
      case 'command':
        return CupertinoColors.systemBlue;
      case 'delay':
        return CupertinoColors.systemOrange;
      case 'loop_begin':
        return CupertinoColors.systemPurple;
      case 'loop_end':
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  IconData _getStepIcon() {
    switch (step.type) {
      case 'command':
        return CupertinoIcons.arrow_up_circle_fill;
      case 'delay':
        return CupertinoIcons.timer_fill;
      case 'loop_begin':
        return CupertinoIcons.repeat;
      case 'loop_end':
        return CupertinoIcons.checkmark_alt_circle_fill;
      default:
        return CupertinoIcons.question_circle_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _getStepColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getStepIcon(), color: _getStepColor(), size: 20),
        ),
        title: Text(
          step.displayText,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        subtitle: Text(
          'Step ${index + 1}',
          style: const TextStyle(decoration: TextDecoration.none),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onEdit,
                minimumSize: Size(30, 30),
                child: const Icon(
                  CupertinoIcons.pencil,
                  size: 20,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onRemove,
              minimumSize: Size(30, 30),
              child: const Icon(
                CupertinoIcons.delete,
                size: 20,
                color: CupertinoColors.systemRed,
              ),
            ),
            const Icon(
              CupertinoIcons.bars,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectCommandDialog extends StatefulWidget {
  final List<IRRemote> remotes;
  final Function(String remoteId, String signalName) onSelected;

  const _SelectCommandDialog({required this.remotes, required this.onSelected});

  @override
  State<_SelectCommandDialog> createState() => _SelectCommandDialogState();
}

class _SelectCommandDialogState extends State<_SelectCommandDialog> {
  IRRemote? _selectedRemote;

  // Check if a signal has multiple variations (universal remote)
  int _getVariationCount(String signalName) {
    if (_selectedRemote == null) return 0;
    return _selectedRemote!.signals
        .where((s) => s.name.toLowerCase() == signalName.toLowerCase())
        .length;
  }

  void _handleSignalSelection(String signalName) {
    final variationCount = _getVariationCount(signalName);

    if (variationCount <= 1) {
      // Single signal - just add it
      widget.onSelected(_selectedRemote!.id, signalName);
      Navigator.pop(context);
      return;
    }

    // Multiple variations - ask user what they want
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('$signalName has $variationCount variations'),
        content: const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'This is a universal remote with multiple signal variations. What would you like to do?',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Add command that will send ALL variations
              widget.onSelected(_selectedRemote!.id, signalName);
              Navigator.pop(context); // Close command dialog
            },
            child: const Text('Send All Variations'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _showVariationPicker(signalName);
            },
            child: const Text('Pick One Variation'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showVariationPicker(String signalName) {
    final variations = _selectedRemote!.signals
        .where((s) => s.name.toLowerCase() == signalName.toLowerCase())
        .toList();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Text(
                    'Pick $signalName Variation',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 60),
                ],
              ),
            ),

            // Variations List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: variations.length,
                itemBuilder: (context, index) {
                  final variation = variations[index];
                  
                  // Display the actual signal name with the model/brand if available
                  String variationName = variation.name;
                  if (variation.model != null && variation.model!.isNotEmpty) {
                    variationName = '${variation.name} (${ variation.model})';
                  } else {
                    variationName = '${variation.name} - Variation ${index + 1}';
                  }
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CupertinoListTile(
                      title: Text(
                        variationName,
                        style: const TextStyle(
                          decoration: TextDecoration.none,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type: ${variation.type}',
                            style: const TextStyle(
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (variation.protocol != null)
                            Text(
                              'Protocol: ${variation.protocol}',
                              style: const TextStyle(
                                decoration: TextDecoration.none,
                              ),
                            ),
                          if (variation.frequency != null)
                            Text(
                              'Frequency: ${variation.frequency} Hz',
                              style: const TextStyle(
                                decoration: TextDecoration.none,
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(
                        CupertinoIcons.checkmark_circle,
                        color: CupertinoColors.activeBlue,
                      ),
                      onTap: () {
                        // Create a unique name for this specific variation
                        final uniqueName = '$signalName#${index + 1}';
                        widget.onSelected(_selectedRemote!.id, uniqueName);
                        Navigator.pop(context); // Close variation picker
                        Navigator.pop(context); // Close command dialog
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Text(
                  'Select Command',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 60), // Balance the header
              ],
            ),
          ),

          // Remote Picker
          Padding(
            padding: const EdgeInsets.all(16),
            child: CupertinoButton(
              padding: const EdgeInsets.all(16),
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => Container(
                    height: 250,
                    color: CupertinoColors.systemBackground,
                    child: Column(
                      children: [
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.pop(context),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Text('Done'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 40,
                            onSelectedItemChanged: (index) {
                              setState(() {
                                _selectedRemote = widget.remotes[index];
                              });
                            },
                            children: widget.remotes
                                .map(
                                  (remote) => Center(child: Text(remote.name)),
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
                    _selectedRemote?.name ?? 'Select Remote',
                    style: TextStyle(
                      color: _selectedRemote == null
                          ? CupertinoColors.placeholderText
                          : CupertinoColors.label,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    size: 20,
                    color: CupertinoColors.systemGrey,
                  ),
                ],
              ),
            ),
          ),

          // Commands List (show unique button names only)
          if (_selectedRemote != null)
            Expanded(
              child: Builder(
                builder: (context) {
                  // Get unique signal names
                  final uniqueNames = <String>{};
                  for (final signal in _selectedRemote!.signals) {
                    uniqueNames.add(signal.name);
                  }
                  final sortedNames = uniqueNames.toList()..sort();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedNames.length,
                    itemBuilder: (context, index) {
                      final signalName = sortedNames[index];
                      // Get first signal with this name for type display
                      final signal = _selectedRemote!.signals.firstWhere(
                        (s) => s.name == signalName,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CupertinoListTile(
                          title: Text(signal.name),
                          subtitle: Text(signal.type),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_getVariationCount(signal.name) > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemOrange
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_getVariationCount(signal.name)} variations',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.systemOrange,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              const Icon(
                                CupertinoIcons.chevron_forward,
                                size: 20,
                              ),
                            ],
                          ),
                          onTap: () => _handleSignalSelection(signalName),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
