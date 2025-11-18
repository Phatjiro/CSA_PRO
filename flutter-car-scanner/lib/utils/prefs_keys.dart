class PrefsKeys {
  // UI preferences
  static const String homeShowAll = 'ui.home.showAll'; // bool
  static const String currentVehicleId = 'vehicle.currentId'; // String
  
  // Connection preferences
  static const String lastTcpHost = 'connection.tcp.host'; // String
  static const String lastTcpPort = 'connection.tcp.port'; // String
  static const String lastBleDeviceId = 'connection.ble.deviceId'; // String
  static const String lastBleDeviceName = 'connection.ble.deviceName'; // String
  static const String pollIntervalMs = 'connection.poll.intervalMs'; // int

  // Reserve future keys here for consistency & discoverability
  // static const String themeMode = 'ui.theme.mode';
  // static const String liveDataSelectedPids = 'ui.liveData.selectedPids';
}


