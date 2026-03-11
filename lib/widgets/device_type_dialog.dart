import 'package:flutter/material.dart';

class DeviceTypeDialog extends StatelessWidget {
  final Function(String) onTypeSelected;

  const DeviceTypeDialog({
    super.key,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Device Type'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What type of device are you importing?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            _DeviceTypeButton(
              icon: Icons.tv,
              label: 'TV',
              onTap: () {
                Navigator.pop(context);
                onTypeSelected('TV');
              },
            ),
            _DeviceTypeButton(
              icon: Icons.speaker,
              label: 'Audio',
              onTap: () {
                Navigator.pop(context);
                onTypeSelected('Audio');
              },
            ),
            _DeviceTypeButton(
              icon: Icons.video_label,
              label: 'Projector',
              onTap: () {
                Navigator.pop(context);
                onTypeSelected('Projector');
              },
            ),
            _DeviceTypeButton(
              icon: Icons.lightbulb,
              label: 'LEDs',
              onTap: () {
                Navigator.pop(context);
                onTypeSelected('LEDs');
              },
            ),
            _DeviceTypeButton(
              icon: Icons.air,
              label: 'Fan',
              onTap: () {
                Navigator.pop(context);
                onTypeSelected('Fan');
              },
            ),
            _DeviceTypeButton(
              icon: Icons.ac_unit,
              label: 'AC',
              onTap: () {
                Navigator.pop(context);
                onTypeSelected('AC');
              },
            ),
            const Divider(height: 30),
            _DeviceTypeButton(
              icon: Icons.settings_remote,
              label: 'Custom',
              subtitle: 'Experimental - Auto-detect',
              onTap: () {
                Navigator.pop(context);
                _showCustomWarning(context);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _showCustomWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Mode'),
        content: const Text(
          'Custom mode is experimental. The app will try to guess the infrared codes automatically, but you might have to edit the buttons with the pen icon in the right corner.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Take me back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onTypeSelected('Custom');
            },
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }
}

class _DeviceTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _DeviceTypeButton({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
