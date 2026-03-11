import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/ir_transmitter_service.dart';

class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _hasIR = false;
  List<int> _frequencies = [];

  @override
  void initState() {
    super.initState();
    _initDebug();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initDebug() async {
    _addLog('═══ Debug Console Started ═══');
    
    // Check IR support
    _addLog('Checking IR emitter...');
    final hasIR = await IRTransmitterService.hasIREmitter();
    setState(() {
      _hasIR = hasIR;
    });
    _addLog('IR Emitter: ${hasIR ? "✓ FOUND" : "✗ NOT FOUND"}');

    if (hasIR) {
      _addLog('Getting carrier frequencies...');
      final freqs = await IRTransmitterService.getCarrierFrequencies();
      setState(() {
        _frequencies = freqs;
      });
      _addLog('✓ Supported frequencies: ${freqs.join(", ")} Hz');
    }

    // Download debug logs (not implemented)
    _addLog('');
    _addLog('═══ Download Debug Logs ═══');
    _addLog('Debug logging not available');

    _addLog('');
    _addLog('═══ Debug Console Ready ═══');
    _scrollToBottom();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyToClipboard() {
    final allLogs = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: allLogs));
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Copied'),
        content: const Text('Debug logs copied to clipboard'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('═══ Logs Cleared ═══');
  }

  void _refreshLogs() {
    setState(() {
      _logs.clear();
    });
    _initDebug();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Debug Console'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _refreshLogs,
              child: const Icon(CupertinoIcons.refresh),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _copyToClipboard,
              child: const Icon(CupertinoIcons.doc_on_clipboard),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _clearLogs,
              child: const Icon(CupertinoIcons.trash),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Status Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _hasIR
                    ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                    : CupertinoColors.systemRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasIR
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.systemRed,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _hasIR
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.xmark_circle_fill,
                        color: _hasIR
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemRed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hasIR ? 'IR Blaster Active' : 'No IR Blaster',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _hasIR
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                  if (_frequencies.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Frequencies: ${_frequencies.length} available',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Logs
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color textColor = CupertinoColors.white;
                    FontWeight fontWeight = FontWeight.normal;

                    // Color coding
                    if (log.contains('✓') || log.contains('SUCCESS')) {
                      textColor = CupertinoColors.systemGreen;
                    } else if (log.contains('✗') || log.contains('ERROR') || log.contains('FAILED')) {
                      textColor = CupertinoColors.systemRed;
                    } else if (log.contains('⚠') || log.contains('WARNING')) {
                      textColor = CupertinoColors.systemOrange;
                    } else if (log.contains('═══')) {
                      textColor = CupertinoColors.systemBlue;
                      fontWeight = FontWeight.bold;
                    } else if (log.contains('⬇') || log.contains('📤')) {
                      textColor = CupertinoColors.systemPurple;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          color: textColor,
                          fontWeight: fontWeight,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Info Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Logs update automatically • Copy to share • Clear to reset',
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.systemGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
