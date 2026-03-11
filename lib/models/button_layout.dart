// Button Layout Model - for custom button arrangements
class ButtonLayout {
  final String buttonId;
  final String label;
  final String? signalName;
  final int position;
  final String icon;

  ButtonLayout({
    required this.buttonId,
    required this.label,
    this.signalName,
    required this.position,
    this.icon = 'default',
  });

  Map<String, dynamic> toJson() {
    return {
      'buttonId': buttonId,
      'label': label,
      'signalName': signalName,
      'position': position,
      'icon': icon,
    };
  }

  factory ButtonLayout.fromJson(Map<String, dynamic> json) {
    return ButtonLayout(
      buttonId: json['buttonId'] as String,
      label: json['label'] as String,
      signalName: json['signalName'] as String?,
      position: json['position'] as int,
      icon: json['icon'] as String? ?? 'default',
    );
  }

  ButtonLayout copyWith({
    String? buttonId,
    String? label,
    String? signalName,
    int? position,
    String? icon,
  }) {
    return ButtonLayout(
      buttonId: buttonId ?? this.buttonId,
      label: label ?? this.label,
      signalName: signalName ?? this.signalName,
      position: position ?? this.position,
      icon: icon ?? this.icon,
    );
  }
}

// Predefined device type templates
class DeviceTemplate {
  final String type;
  final List<ButtonLayout> buttons;

  DeviceTemplate({
    required this.type,
    required this.buttons,
  });

  static DeviceTemplate tv() {
    return DeviceTemplate(
      type: 'TV',
      buttons: [
        ButtonLayout(buttonId: 'power', label: 'POWER', signalName: 'Power', position: 0, icon: 'power'),
        ButtonLayout(buttonId: 'mute', label: 'MUTE', signalName: 'Mute', position: 1, icon: 'mute'),
        ButtonLayout(buttonId: 'vol_up', label: 'VOL +', signalName: 'Vol_up', position: 2, icon: 'vol_up'),
        ButtonLayout(buttonId: 'vol_down', label: 'VOL -', signalName: 'Vol_dn', position: 3, icon: 'vol_down'),
        ButtonLayout(buttonId: 'ch_up', label: 'CH +', signalName: 'Ch_next', position: 4, icon: 'ch_up'),
        ButtonLayout(buttonId: 'ch_down', label: 'CH -', signalName: 'Ch_prev', position: 5, icon: 'ch_down'),
      ],
    );
  }

  static DeviceTemplate audio() {
    return DeviceTemplate(
      type: 'Audio',
      buttons: [
        ButtonLayout(buttonId: 'power', label: 'POWER', signalName: 'Power', position: 0, icon: 'power'),
        ButtonLayout(buttonId: 'mute', label: 'MUTE', signalName: 'Mute', position: 1, icon: 'mute'),
        ButtonLayout(buttonId: 'vol_up', label: 'VOL +', signalName: 'Vol_up', position: 2, icon: 'vol_up'),
        ButtonLayout(buttonId: 'vol_down', label: 'VOL -', signalName: 'Vol_dn', position: 3, icon: 'vol_down'),
        ButtonLayout(buttonId: 'next', label: 'NEXT', signalName: 'Next', position: 4, icon: 'next'),
        ButtonLayout(buttonId: 'prev', label: 'PREV', signalName: 'Prev', position: 5, icon: 'prev'),
        ButtonLayout(buttonId: 'pause', label: 'PAUSE', signalName: 'Pause', position: 6, icon: 'pause'),
        ButtonLayout(buttonId: 'play', label: 'PLAY', signalName: 'Play', position: 7, icon: 'play'),
      ],
    );
  }

  static DeviceTemplate projector() {
    return DeviceTemplate(
      type: 'Projector',
      buttons: [
        ButtonLayout(buttonId: 'power', label: 'POWER', signalName: 'Power', position: 0, icon: 'power'),
        ButtonLayout(buttonId: 'mute', label: 'MUTE', signalName: 'Mute', position: 1, icon: 'mute'),
        ButtonLayout(buttonId: 'play', label: 'PLAY', signalName: 'Play', position: 2, icon: 'play'),
        ButtonLayout(buttonId: 'pause', label: 'PAUSE', signalName: 'Pause', position: 3, icon: 'pause'),
        ButtonLayout(buttonId: 'vol_up', label: 'VOL +', signalName: 'Vol_up', position: 4, icon: 'vol_up'),
        ButtonLayout(buttonId: 'vol_down', label: 'VOL -', signalName: 'Vol_dn', position: 5, icon: 'vol_down'),
      ],
    );
  }

  static DeviceTemplate leds() {
    return DeviceTemplate(
      type: 'LEDs',
      buttons: [
        ButtonLayout(buttonId: 'on', label: 'ON', signalName: 'On', position: 0, icon: 'power'),
        ButtonLayout(buttonId: 'off', label: 'OFF', signalName: 'Off', position: 1, icon: 'power'),
        ButtonLayout(buttonId: 'bright_up', label: '+', signalName: 'Brightness_up', position: 2, icon: 'plus'),
        ButtonLayout(buttonId: 'bright_down', label: '-', signalName: 'Brightness_down', position: 3, icon: 'minus'),
        ButtonLayout(buttonId: 'red', label: 'R', signalName: 'Red', position: 4, icon: 'color'),
        ButtonLayout(buttonId: 'green', label: 'G', signalName: 'Green', position: 5, icon: 'color'),
        ButtonLayout(buttonId: 'blue', label: 'B', signalName: 'Blue', position: 6, icon: 'color'),
        ButtonLayout(buttonId: 'white', label: 'W', signalName: 'White', position: 7, icon: 'color'),
      ],
    );
  }

  static DeviceTemplate fans() {
    return DeviceTemplate(
      type: 'Fans',
      buttons: [
        ButtonLayout(buttonId: 'power', label: 'POWER', signalName: 'Power', position: 0, icon: 'power'),
        ButtonLayout(buttonId: 'mode', label: 'MODE', signalName: 'Mode', position: 1, icon: 'mode'),
        ButtonLayout(buttonId: 'rotate', label: 'ROTATE', signalName: 'Rotate', position: 2, icon: 'rotate'),
        ButtonLayout(buttonId: 'timer', label: 'TIMER', signalName: 'Timer', position: 3, icon: 'timer'),
        ButtonLayout(buttonId: 'speed_up', label: '+', signalName: 'Speed_up', position: 4, icon: 'plus'),
        ButtonLayout(buttonId: 'speed_down', label: '-', signalName: 'Speed_down', position: 5, icon: 'minus'),
      ],
    );
  }

  static DeviceTemplate ac() {
    return DeviceTemplate(
      type: 'ACs',
      buttons: [
        ButtonLayout(buttonId: 'off', label: 'OFF', signalName: 'Off', position: 0, icon: 'power'),
        ButtonLayout(buttonId: 'dry', label: 'DRY', signalName: 'Dh', position: 1, icon: 'mode'),
        ButtonLayout(buttonId: 'cool_up', label: 'COOL +', signalName: 'Cool_hi', position: 2, icon: 'temp_up'),
        ButtonLayout(buttonId: 'cool_down', label: 'COOL -', signalName: 'Cool_lo', position: 3, icon: 'temp_down'),
        ButtonLayout(buttonId: 'heat_up', label: 'HEAT +', signalName: 'Heat_hi', position: 4, icon: 'temp_up'),
        ButtonLayout(buttonId: 'heat_down', label: 'HEAT -', signalName: 'Heat_lo', position: 5, icon: 'temp_down'),
      ],
    );
  }
}
