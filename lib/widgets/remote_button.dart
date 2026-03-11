import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../models/ir_signal.dart';

class RemoteButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final List<IRSignal>?
  allVariations; // For hold-to-repeat (non-universal only)
  final bool isPressed;
  final double size;
  final Color? color;

  const RemoteButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.allVariations,
    this.isPressed = false,
    this.size = 70,
    this.color,
  });

  @override
  State<RemoteButton> createState() => _RemoteButtonState();
}

class _RemoteButtonState extends State<RemoteButton> {
  bool _isHolding = false;
  Timer? _repeatTimer;

  void _startHoldRepeat() {
    // Only repeat if NOT a universal remote (single variation)
    if (widget.allVariations != null && widget.allVariations!.length == 1) {
      setState(() => _isHolding = true);

      // First press
      SettingsService.mediumHaptic();
      _playSound();
      widget.onPressed();

      // Start repeating with configurable delay
      _repeatTimer = Timer.periodic(
        Duration(milliseconds: SettingsService.buttonRepeatDelay),
        (timer) {
          if (_isHolding) {
            SettingsService.lightHaptic();
            _playSound();
            widget.onPressed();
          }
        },
      );
    } else {
      // For universal remotes (multiple variations), just provide haptic feedback
      // but don't set holding state or trigger repeat
      SettingsService.mediumHaptic();
    }
  }

  void _stopHoldRepeat() {
    setState(() => _isHolding = false);
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _playSound() {
    if (SettingsService.soundEffectsEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? CupertinoColors.systemGrey;
    final isCurrentlyPressed = widget.isPressed || _isHolding;

    return GestureDetector(
      onTap: () {
        SettingsService.lightHaptic();
        _playSound();
        widget.onPressed();
      },
      onLongPressStart: (_) => _startHoldRepeat(),
      onLongPressEnd: (_) => _stopHoldRepeat(),
      child: AnimatedScale(
        scale: isCurrentlyPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCurrentlyPressed
                  ? [buttonColor.withOpacity(0.7), buttonColor.withOpacity(0.9)]
                  : [buttonColor.withOpacity(0.9), buttonColor],
            ),
            borderRadius: BorderRadius.circular(widget.size * 0.22),
            boxShadow: isCurrentlyPressed
                ? [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: buttonColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: CupertinoColors.white,
                  size: widget.size * 0.32,
                ),
                if (widget.label.length <= 6)
                  SizedBox(height: widget.size * 0.06),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: widget.size * (widget.icon != null ? 0.16 : 0.20),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  decoration: TextDecoration.none,
                  decorationColor: CupertinoColors.white.withOpacity(
                    0,
                  ), // Ensure no underline color
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
