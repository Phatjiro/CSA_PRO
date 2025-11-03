// Transport abstraction for ELM327 links (TCP, BLE, Classic SPP)
// Keeps ObdClient unchanged for higher layers.

abstract class ObdLink {
  Future<void> connect();
  Future<void> disconnect();
  Future<void> tx(String command); // send a single ELM command (no trailing CR needed)
  Stream<String> get rx; // incoming raw text chunks including prompts
  bool get isConnected;
}
