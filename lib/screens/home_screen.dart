import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/remote_provider.dart';
import '../services/flipper_parser.dart';
import '../services/ir_transmitter_service.dart';
import '../services/universal_remote_service.dart';
import '../widgets/device_type_dialog.dart';
import 'remote_control_screen.dart';
import 'chain_code_editor_screen.dart';
import 'settings_screen.dart';
import '../services/settings_service.dart';
import 'converter_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasIR = false;
  bool _isImporting = false;
  bool _isDownloadingAll = false;
  double _importProgress = 0.0;
  double _downloadProgress = 0.0;
  int _currentFile = 0;
  int _totalFiles = 0;
  int _currentDownload = 0;
  int _totalDownloads = 0;
  String _currentDownloadType = '';
  bool _shouldCancelImport = false;
  bool _shouldCancelDownload = false;

  // Selection mode - KEEP for long-press delete
  bool _isSelectionMode = false;
  Set<String> _selectedRemoteIds = {};

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTypeFilter; // null = All

  @override
  void initState() {
    super.initState();
    _checkIRSupport();
    _loadRemotes();
    _searchController.addListener(() {
      setState(() {}); // Refresh UI when search text changes
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkIRSupport() async {
    final hasIR = await IRTransmitterService.hasIREmitter();
    setState(() => _hasIR = hasIR);
  }

  Future<void> _loadRemotes() async {
    final provider = Provider.of<RemoteProvider>(context, listen: false);
    await provider.loadRemotes();
  }

  Future<void> _showImportDialog() async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text(
          'Add Remote',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showDeviceTypeDialog();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 22,
                  color: CupertinoColors.activeBlue,
                ),
                SizedBox(width: 12),
                Text(
                  'Import File (.ir or .txt)',
                  style: TextStyle(fontSize: 17),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showZipImportOptions();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  CupertinoIcons.archivebox,
                  size: 22,
                  color: CupertinoColors.activeBlue,
                ),
                SizedBox(width: 12),
                Text('Import ZIP Archive', style: TextStyle(fontSize: 17)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _downloadAllUniversalRemotes();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  CupertinoIcons.cloud_download,
                  size: 22,
                  color: CupertinoColors.activeBlue,
                ),
                SizedBox(width: 12),
                Text(
                  'Download All Universal Remotes',
                  style: TextStyle(fontSize: 17),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAllUniversalRemotes() async {
    // Check if universal remotes already exist
    final provider = Provider.of<RemoteProvider>(context, listen: false);
    final existingTypes = <String>{};
    for (final remote in provider.remotes) {
      if (UniversalRemoteService.libraryUrls.keys.contains(remote.type)) {
        existingTypes.add(remote.type);
      }
    }

    if (existingTypes.isNotEmpty) {
      // Show warning
      final result = await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Universal Remotes Already Downloaded'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'You already have these universal remotes:\n${existingTypes.join(", ")}\n\nWhat would you like to do?',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, 'replace'),
              isDestructiveAction: true,
              child: const Text('Replace Existing'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, 'download'),
              isDefaultAction: true,
              child: const Text('Download Anyway'),
            ),
          ],
        ),
      );

      if (result == 'cancel' || result == null) return;

      if (result == 'replace') {
        // Delete existing universal remotes
        for (final type in existingTypes) {
          final remotesToDelete = provider.remotes
              .where((r) => r.type == type)
              .toList();
          for (final remote in remotesToDelete) {
            await provider.deleteRemote(remote.id);
          }
        }
      }
    }

    setState(() {
      _isDownloadingAll = true;
      _shouldCancelDownload = false;
      _currentDownload = 0;
      _downloadProgress = 0.0;
      _totalDownloads = UniversalRemoteService.libraryUrls.length;
    });

    int successCount = 0;

    for (int i = 0; i < UniversalRemoteService.libraryUrls.keys.length; i++) {
      if (_shouldCancelDownload) break;

      final deviceType = UniversalRemoteService.libraryUrls.keys.toList()[i];

      setState(() {
        _currentDownload = i + 1;
        _currentDownloadType = deviceType;
        _downloadProgress = (i + 1) / _totalDownloads;
      });

      try {
        final remote = await UniversalRemoteService.createUniversalRemote(
          deviceType,
          deviceType,
        );
        if (remote != null && remote.signals.isNotEmpty) {
          await provider.addRemote(remote);
          successCount++;
        }
      } catch (e) {
        // Continue on error
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _isDownloadingAll = false;
      _downloadProgress = 0.0;
    });

    if (_shouldCancelDownload) {
      _showMessage('Download Cancelled', isError: true);
    } else if (successCount > 0) {
      _showMessage(
        'Downloaded $successCount Remote${successCount > 1 ? "s" : ""}',
      );
    } else {
      _showMessage('Failed to Download Remotes', isError: true);
    }
  }

  Future<void> _showZipImportOptions() async {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Import ZIP Archive'),
        content: const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'How would you like to import the .ir files from this ZIP?',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _importFromZip('regular');
            },
            child: const Text('Separate Remotes\n(Each file = 1 remote)'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _importFromZip('merge_universal');
            },
            child: const Text('Single Universal Remote\n(Merge all files)'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _importFromZip('multiple_universal');
            },
            child: const Text(
              'Multiple Universal Remotes\n(Each file = 1 universal)',
            ),
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

  Future<void> _importFromZip(String mode) async {
    try {
      setState(() {
        _shouldCancelImport = false;
        _isImporting = true;
        _importProgress = 0.0;
        _currentFile = 0;
        _totalFiles = 0;
      });

      if (mode == 'regular') {
        // Regular import - each file is a separate remote
        final remotes = await UniversalRemoteService.importFromZip(
          onProgress: (current, total, fileName) {
            if (mounted && !_shouldCancelImport) {
              setState(() {
                _currentFile = current;
                _totalFiles = total;
                _importProgress = total > 0 ? current / total : 0.0;
              });
            }
          },
          shouldCancel: () => _shouldCancelImport,
        );

        if (mounted) setState(() => _isImporting = false);

        if (_shouldCancelImport) {
          _showMessage('Import Cancelled', isError: true);
          return;
        }

        if (remotes.isEmpty) {
          _showMessage('No Valid IR Files Found', isError: true);
          return;
        }

        final provider = Provider.of<RemoteProvider>(context, listen: false);
        for (final remote in remotes) {
          await provider.addRemote(remote);
        }

        _showMessage(
          'Imported ${remotes.length} Remote${remotes.length > 1 ? "s" : ""}',
        );
      } else if (mode == 'merge_universal') {
        // Merge all files into ONE universal remote
        final remote = await UniversalRemoteService.importZipAsMergedUniversal(
          onProgress: (current, total, fileName) {
            if (mounted && !_shouldCancelImport) {
              setState(() {
                _currentFile = current;
                _totalFiles = total;
                _importProgress = total > 0 ? current / total : 0.0;
              });
            }
          },
          shouldCancel: () => _shouldCancelImport,
        );

        if (mounted) setState(() => _isImporting = false);

        if (_shouldCancelImport) {
          _showMessage('Import Cancelled', isError: true);
          return;
        }

        if (remote == null) {
          _showMessage('No Valid IR Files Found', isError: true);
          return;
        }

        final provider = Provider.of<RemoteProvider>(context, listen: false);
        await provider.addRemote(remote);

        _showMessage(
          'Imported merged universal remote with ${remote.signals.length} signal${remote.signals.length > 1 ? "s" : ""}',
        );
      } else {
        // multiple_universal - each file becomes a universal remote
        final remotes =
            await UniversalRemoteService.importZipAsMultipleUniversal(
              onProgress: (current, total, fileName) {
                if (mounted && !_shouldCancelImport) {
                  setState(() {
                    _currentFile = current;
                    _totalFiles = total;
                    _importProgress = total > 0 ? current / total : 0.0;
                  });
                }
              },
              shouldCancel: () => _shouldCancelImport,
            );

        if (mounted) setState(() => _isImporting = false);

        if (_shouldCancelImport) {
          _showMessage('Import Cancelled', isError: true);
          return;
        }

        if (remotes.isEmpty) {
          _showMessage('No Valid IR Files Found', isError: true);
          return;
        }

        final provider = Provider.of<RemoteProvider>(context, listen: false);
        for (final remote in remotes) {
          await provider.addRemote(remote);
        }

        _showMessage(
          'Imported ${remotes.length} universal remote${remotes.length > 1 ? "s" : ""}',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isImporting = false);
      _showMessage('Import Failed', isError: true);
    }
  }

  Future<void> _showDeviceTypeDialog() async {
    showDialog(
      context: context,
      builder: (context) => DeviceTypeDialog(
        onTypeSelected: (deviceType) => _importFlipperFiles(deviceType),
      ),
    );
  }

  Future<void> _importFlipperFiles(String deviceType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        // Let the user see all files; we'll filter by content/extension ourselves
        type: FileType.any,
        allowMultiple: true, // ENABLE MULTIPLE FILE SELECTION
      );

      if (result != null && result.files.isNotEmpty) {
        int successCount = 0;
        int totalButtons = 0;

        // Decide how to handle parsed signals (RAW vs parsed) for this import batch
        bool convertParsedToRaw = false;
        String policy = SettingsService.parsedImportPolicy;
        if (policy == 'raw') {
          convertParsedToRaw = true;
        } else if (policy == 'parsed') {
          convertParsedToRaw = false;
        } else {
          // Ask the user once for this batch, based on the first valid file's content
          final firstFile = result.files.firstWhere(
            (f) {
              final name = f.name.toLowerCase();
              return name.endsWith('.ir') || name.endsWith('.txt');
            },
            orElse: () => result.files.first,
          );

          if (firstFile.path != null) {
            final file = File(firstFile.path!);
            if (await file.exists()) {
              final content = await file.readAsString();
              final proto = _detectProtocolFromContent(content);
              final decision = await _askParsedImportDecision(proto);
              if (decision == null) {
                // User cancelled – abort the whole import
                return;
              }
              convertParsedToRaw = decision.convertToRaw;
            }
          }
        }

        for (final fileData in result.files) {
          if (fileData.path == null) continue;

          try {
            // Skip non-.ir/.txt files explicitly
            final lowerName = fileData.name.toLowerCase();
            if (!lowerName.endsWith('.ir') && !lowerName.endsWith('.txt')) {
              continue;
            }

            final file = File(fileData.path!);
            final content = await file.readAsString();
            final fileName = fileData.name;

            if (!FlipperZeroParser.isValidFlipperFile(content)) {
              continue;
            }

            var remote = FlipperZeroParser.parseFlipperFile(
              content,
              fileName,
              convertParsedToRaw: convertParsedToRaw,
            );

            if (remote.signals.isEmpty) {
              continue;
            }

            remote = remote.copyWith(type: deviceType);
            final provider = Provider.of<RemoteProvider>(
              context,
              listen: false,
            );
            await provider.addRemote(remote);

            successCount++;
            totalButtons += remote.signals.length;
          } catch (e) {
            // Skip file on error
          }
        }

        if (successCount > 0) {
          _showMessage(
            'Imported $successCount file${successCount > 1 ? "s" : ""} with $totalButtons button${totalButtons > 1 ? "s" : ""}',
          );
        } else {
          _showMessage('No Valid Files Found', isError: true);
        }
      }
    } catch (e) {
      _showMessage('Import Failed', isError: true);
    }
  }

  String? _detectProtocolFromContent(String content) {
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.toLowerCase().startsWith('protocol:')) {
        return line.split(':').last.trim();
      }
    }
    return null;
  }

  Future<_ParsedImportDecision?> _askParsedImportDecision(String? protocol) async {
    final protoName = protocol ?? 'an unknown protocol';
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Convert to RAW timings?'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'This file seems to be in $protoName.\n\n'
            'Do you want to convert all parsed signals into RAW timings now, '
            'or keep them as parsed? You can convert it later too if you\'re unsure.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, 'raw_once'),
            isDefaultAction: true,
            child: const Text('Convert to RAW'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, 'parsed_once'),
            child: const Text('Keep Parsed'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, 'raw_always'),
            child: const Text('Always Convert to RAW'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, 'parsed_always'),
            child: const Text('Always Keep Parsed'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    switch (result) {
      case 'raw_once':
        return const _ParsedImportDecision(convertToRaw: true);
      case 'parsed_once':
        return const _ParsedImportDecision(convertToRaw: false);
      case 'raw_always':
        await SettingsService.setParsedImportPolicy('raw');
        return const _ParsedImportDecision(convertToRaw: true);
      case 'parsed_always':
        await SettingsService.setParsedImportPolicy('parsed');
        return const _ParsedImportDecision(convertToRaw: false);
      case 'cancel':
      default:
        // Treat cancel/unknown as "no decision" – caller should abort import
        return null;
    }
  }

  void _toggleRemoteSelection(String remoteId) {
    setState(() {
      if (_selectedRemoteIds.contains(remoteId)) {
        _selectedRemoteIds.remove(remoteId);
      } else {
        _selectedRemoteIds.add(remoteId);
      }
    });
  }

  void _deleteSelectedRemotes() {
    if (_selectedRemoteIds.isEmpty) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          'Delete ${_selectedRemoteIds.length} Remote${_selectedRemoteIds.length > 1 ? "s" : ""}?',
        ),
        content: const Text('This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              final provider = Provider.of<RemoteProvider>(
                context,
                listen: false,
              );
              for (final id in _selectedRemoteIds) {
                provider.deleteRemote(id);
              }
              Navigator.pop(context);
              _showMessage(
                'Deleted ${_selectedRemoteIds.length} Remote${_selectedRemoteIds.length > 1 ? "s" : ""}',
              );
              setState(() {
                _selectedRemoteIds.clear();
                _isSelectionMode = false;
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String remoteId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Remote?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              final provider = Provider.of<RemoteProvider>(
                context,
                listen: false,
              );
              provider.deleteRemote(remoteId);
              Navigator.pop(context);
              _showMessage('Remote Deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError
                  ? CupertinoIcons.exclamationmark_circle_fill
                  : CupertinoIcons.checkmark_circle_fill,
              color: isError
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemGreen,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(isError ? 'Error' : 'Success'),
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        border: null,
        middle: _isSelectionMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    CupertinoIcons.antenna_radiowaves_left_right,
                    size: 22,
                    color: CupertinoColors.activeBlue,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'OnePlus IR Remote',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                  ),
                ],
              ),
        leading: _isSelectionMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedRemoteIds.clear();
                  });
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.normal),
                ),
              )
            : null,
        trailing: _isSelectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedRemoteIds.length == 1)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => ConverterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Convert',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (_selectedRemoteIds.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _deleteSelectedRemotes,
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: CupertinoColors.systemRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        final provider = Provider.of<RemoteProvider>(
                          context,
                          listen: false,
                        );
                        if (_selectedRemoteIds.length ==
                            provider.remotes.length) {
                          // Deselect all
                          _selectedRemoteIds.clear();
                        } else {
                          // Select all
                          _selectedRemoteIds = provider.remotes
                              .map((r) => r.id)
                              .toSet();
                        }
                      });
                    },
                    child: Text(
                      _selectedRemoteIds.length ==
                              Provider.of<RemoteProvider>(
                                context,
                                listen: false,
                              ).remotes.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      SettingsService.lightHaptic();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const ChainCodeEditorScreen(),
                        ),
                      );
                    },
                    child: const Icon(CupertinoIcons.link, size: 24),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      SettingsService.lightHaptic();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: const Icon(CupertinoIcons.gear_alt_fill, size: 24),
                  ),
                ],
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Modern IR Status Banner with Gradient
            if (_hasIR)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CupertinoColors.systemGreen.withValues(alpha: 0.15),
                      CupertinoColors.systemGreen.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.systemGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: CupertinoColors.systemGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IR Blaster Ready',
                            style: TextStyle(
                              color: CupertinoColors.systemGreen.darkColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Device is ready to send IR signals',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Import Progress
            if (_isImporting)
              _buildProgressCard(
                title: 'Importing Files',
                subtitle: '$_currentFile of $_totalFiles',
                progress: _importProgress,
                color: CupertinoColors.activeBlue,
                onCancel: () => setState(() => _shouldCancelImport = true),
              ),

            // Download Progress
            if (_isDownloadingAll)
              _buildProgressCard(
                title: 'Downloading $_currentDownloadType',
                subtitle: '$_currentDownload of $_totalDownloads remotes',
                progress: _downloadProgress,
                color: CupertinoColors.systemGreen,
                onCancel: () => setState(() => _shouldCancelDownload = true),
              ),

            // Modern Add Remote Button with Gradient
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CupertinoColors.activeBlue, Color(0xFF007AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.activeBlue.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  onPressed: _isImporting || _isDownloadingAll
                      ? null
                      : _showImportDialog,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        CupertinoIcons.add_circled_solid,
                        size: 24,
                        color: CupertinoColors.white,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Add New Remote',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search and Filter
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              color: CupertinoColors.systemGroupedBackground,
              child: Column(
                children: [
                  CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search remotes',
                    style: const TextStyle(decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('All', null),
                        const SizedBox(width: 8),
                        _buildFilterChip('TV', 'TV'),
                        const SizedBox(width: 8),
                        _buildFilterChip('AC', 'AC'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Fan', 'Fan'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Audio', 'Audio'),
                        const SizedBox(width: 8),
                        _buildFilterChip('LED', 'LEDs'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Projector', 'Projector'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Other', 'Other'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Remotes List
            Expanded(
              child: Consumer<RemoteProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CupertinoActivityIndicator(radius: 16),
                    );
                  }

                  if (provider.remotes.isEmpty) {
                    return _buildEmptyState();
                  }

                  final filteredRemotes = _getFilteredRemotes(provider);

                  if (filteredRemotes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.search,
                            size: 64,
                            color: CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Results',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No remotes match "${_searchController.text}"'
                                : 'No $_selectedTypeFilter remotes found',
                            style: TextStyle(
                              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredRemotes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final remote = filteredRemotes[index];
                      final isSelected = _selectedRemoteIds.contains(remote.id);

                      return _buildRemoteCard(remote, isSelected, provider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getFilteredRemotes(RemoteProvider provider) {
    var remotes = provider.remotes;
    final query = _searchController.text.toLowerCase();
    
    // Apply type filter
    if (_selectedTypeFilter != null) {
      remotes = remotes.where((r) => r.type == _selectedTypeFilter).toList();
    }
    
    // Apply search filter
    if (query.isNotEmpty) {
      remotes = remotes.where((r) => 
        r.name.toLowerCase().contains(query) ||
        r.type.toLowerCase().contains(query)
      ).toList();
    }
    
    return remotes;
  }

  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = _selectedTypeFilter == filterValue;
    return GestureDetector(
      onTap: () {
        SettingsService.lightHaptic();
        setState(() {
          _selectedTypeFilter = filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? CupertinoColors.activeBlue
                : CupertinoColors.separator,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? CupertinoColors.white
                : CupertinoColors.label,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required String subtitle,
    required double progress,
    required Color color,
    required VoidCallback onCancel,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
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
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey.darkColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onCancel,
                color: CupertinoColors.systemRed,
                borderRadius: BorderRadius.circular(10), minimumSize: Size(0, 0),
                child: const Icon(
                  CupertinoIcons.stop_fill,
                  size: 18,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: CupertinoColors.systemGrey5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemGrey2.darkColor,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.antenna_radiowaves_left_right,
            size: 72,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 20),
          const Text(
            'No Remotes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Remote" to get started',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteCard(remote, bool isSelected, RemoteProvider provider) {
    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() => _isSelectionMode = true);
        }
        _toggleRemoteSelection(remote.id);
      },
      child: Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  CupertinoColors.activeBlue.withValues(alpha: 0.22),
                  CupertinoColors.activeBlue.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected
            ? null
            : CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? CupertinoColors.activeBlue
              : CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.3),
          width: isSelected ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? CupertinoColors.activeBlue.withValues(alpha: 0.22)
                : CupertinoColors.systemGrey.withValues(alpha: 0.08),
            blurRadius: isSelected ? 18 : 12,
            offset: Offset(0, isSelected ? 6 : 4),
          ),
        ],
      ),
      child: CupertinoListTile(
        padding: const EdgeInsets.all(18),
        leading: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getRemoteColor(remote.type).withOpacity(0.85),
                _getRemoteColor(remote.type),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _getRemoteColor(remote.type).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            _getRemoteIcon(remote.type),
            color: CupertinoColors.white,
            size: 28,
          ),
        ),
        title: Text(
          remote.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            decoration: TextDecoration.none,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRemoteColor(remote.type).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  remote.type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _getRemoteColor(remote.type),
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${remote.signals.length} buttons',
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        trailing: _isSelectionMode
            ? Icon(
                isSelected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: isSelected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.systemGrey3,
                size: 28,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _showRenameDialog(remote, provider);
                    },
                    child: const Icon(
                      CupertinoIcons.pencil,
                      size: 20,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmDelete(remote.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CupertinoIcons.trash_fill,
                        size: 20,
                        color: CupertinoColors.systemRed.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
        onTap: () {
          if (_isSelectionMode) {
            _toggleRemoteSelection(remote.id);
          } else {
            provider.setCurrentRemote(remote);
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const RemoteControlScreen(),
              ),
            );
          }
        },
      ),
    ),
    );
  }

  void _showRenameDialog(remote, RemoteProvider provider) {
    final controller = TextEditingController(text: remote.name);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Rename Remote'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Remote name',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updated = remote.copyWith(
                  name: newName,
                  updatedAt: DateTime.now(),
                );
                await provider.updateRemote(updated);
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _getRemoteColor(String type) {
    switch (type.toLowerCase()) {
      case 'tv':
        return const Color(0xFF5856D6); // Purple
      case 'ac':
        return const Color(0xFF00C7BE); // Teal
      case 'fan':
        return const Color(0xFF32ADE6); // Sky Blue
      case 'projector':
        return const Color(0xFFFF9500); // Orange
      case 'audio':
        return const Color(0xFFFF2D55); // Pink
      case 'leds':
        return const Color(0xFFFFCC00); // Yellow
      case 'universal':
        return const Color(0xFF30D158); // Green
      default:
        return CupertinoColors.activeBlue;
    }
  }

  IconData _getRemoteIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tv':
        return CupertinoIcons.tv;
      case 'ac':
        return CupertinoIcons.snow;
      case 'fan':
        return CupertinoIcons.wind;
      case 'projector':
        return CupertinoIcons.videocam;
      case 'audio':
        return CupertinoIcons.speaker_2_fill;
      case 'leds':
        return CupertinoIcons.lightbulb_fill;
      default:
        return CupertinoIcons.antenna_radiowaves_left_right;
    }
  }
}

class _ParsedImportDecision {
  final bool convertToRaw;
  const _ParsedImportDecision({required this.convertToRaw});
}
