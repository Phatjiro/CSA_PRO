import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'obd_link.dart';

class TcpObdLink implements ObdLink {
  final String host;
  final int port;

  Socket? _socket;
  final StreamController<String> _rx = StreamController.broadcast();

  TcpObdLink({required this.host, required this.port});

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    _socket!.listen((bytes) {
      _rx.add(utf8.decode(bytes));
    }, onDone: () => _rx.close(), onError: (_) => _rx.close());
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  @override
  bool get isConnected => _socket != null;

  @override
  Stream<String> get rx => _rx.stream;

  @override
  Future<void> tx(String command) async {
    final s = _socket;
    if (s == null) return;
    s.add(utf8.encode('$command\r'));
    await s.flush();
  }
}
