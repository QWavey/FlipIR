import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/chain_code.dart';
import '../providers/remote_provider.dart';
import '../services/chain_code_service.dart';
import '../services/settings_service.dart';
import 'chain_code_editor_screen.dart';

class ChainCodesListScreen extends StatefulWidget {
  const ChainCodesListScreen({super.key});

  @override
  State<ChainCodesListScreen> createState() => _ChainCodesListScreenState();
}

class _ChainCodesListScreenState extends State<ChainCodesListScreen> {
  List<ChainCode> _chainCodes = [];
  List<ChainCode> _filteredChainCodes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterChainCodes);
    _loadChainCodes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterChainCodes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredChainCodes = _chainCodes;
      } else {
        _filteredChainCodes = _chainCodes
            .where((code) => code.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _loadChainCodes() async {
    setState(() {
      _isLoading = true;
    });

    final chainCodes = await ChainCodeService.loadChainCodes();

    if (mounted) {
      setState(() {
        _chainCodes = chainCodes;
        _filteredChainCodes = chainCodes;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChainCode(ChainCode chainCode) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Chain Code'),
        content: Text('Are you sure you want to delete "${chainCode.name}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ChainCodeService.deleteChainCode(chainCode.id);
      if (success && mounted) {
        _loadChainCodes();
        _showSuccess('Chain code deleted');
      } else if (mounted) {
        _showError('Failed to delete chain code');
      }
    }
  }

  Future<void> _executeChainCode(ChainCode chainCode) async {
    final provider = Provider.of<RemoteProvider>(context, listen: false);

    if (provider.remotes.isEmpty) {
      _showError('No remotes available. Import a remote first.');
      return;
    }

    String executionStatus = '';

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: Text('Executing ${chainCode.name}'),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 12),
                  Text(executionStatus),
                ],
              ),
            ),
          );
        },
      ),
    );

    final success = await ChainCodeService.executeChainCode(
      chainCode,
      provider.remotes,
      (status) {
        if (mounted) {
          executionStatus = status;
        }
      },
    );

    if (mounted) {
      Navigator.pop(context); // Close dialog

      if (success) {
        _showSuccess('Execution completed!');
      } else {
        _showError('Execution failed');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Chain Codes'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: () async {
            SettingsService.lightHaptic();
            await Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const ChainCodeEditorScreen(),
              ),
            );
            _loadChainCodes(); // Reload after returning
          },
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: CupertinoColors.systemBackground,
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search chain codes',
              style: const TextStyle(decoration: TextDecoration.none),
            ),
          ),
          // List
          Expanded(
            child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _filteredChainCodes.isEmpty && _searchController.text.isNotEmpty
                  ? Center(
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
                            'No chain codes match "${_searchController.text}"',
                            style: TextStyle(
                              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _chainCodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.link,
                        size: 64,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Chain Codes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color:
                              CupertinoColors.secondaryLabel.resolveFrom(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a chain code to get started',
                        style: TextStyle(
                          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredChainCodes.length,
                    itemBuilder: (context, index) {
                    final chainCode = _filteredChainCodes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.separator.resolveFrom(context),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CupertinoListTile(
                        padding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            CupertinoIcons.link,
                            color: CupertinoColors.systemBlue,
                          ),
                        ),
                        title: Text(
                          chainCode.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          '${chainCode.steps.length} step${chainCode.steps.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            decoration: TextDecoration.none,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Icon(
                                CupertinoIcons.play_fill,
                                color: CupertinoColors.systemGreen,
                              ),
                              onPressed: () {
                                SettingsService.lightHaptic();
                                _executeChainCode(chainCode);
                              },
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Icon(
                                CupertinoIcons.pencil,
                                color: CupertinoColors.systemBlue,
                              ),
                              onPressed: () async {
                                SettingsService.lightHaptic();
                                await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => ChainCodeEditorScreen(
                                      existingChainCode: chainCode,
                                    ),
                                  ),
                                );
                                _loadChainCodes(); // Reload after returning
                              },
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Icon(
                                CupertinoIcons.trash,
                                color: CupertinoColors.systemRed,
                              ),
                              onPressed: () {
                                SettingsService.lightHaptic();
                                _deleteChainCode(chainCode);
                              },
                            ),
                          ],
                        ),
                        onTap: () async {
                          SettingsService.lightHaptic();
                          await Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => ChainCodeEditorScreen(
                                existingChainCode: chainCode,
                              ),
                            ),
                          );
                          _loadChainCodes(); // Reload after returning
                        },
                      ),
                    );
                  },
                ),
              ),
          ),
        ],
      ),
    );
  }
}
