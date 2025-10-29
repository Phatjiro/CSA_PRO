import 'package:flutter/foundation.dart';

import 'obd_client.dart';

class ConnectionManager {
  ConnectionManager._internal();
  static final ConnectionManager instance = ConnectionManager._internal();

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  ObdClient? _client;

  ObdClient? get client => _client;

  Future<void> connect({required String host, required int port}) async {
    final client = ObdClient(host: host, port: port);
    await client.connect();
    _client = client;
    isConnected.value = true;
  }

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    isConnected.value = false;
  }
}


