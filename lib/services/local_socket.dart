/// # LocalSocket — Plug & Play WebSocket untuk Flutter (Local WiFi)
///
/// Komunikasi real-time antar HP lewat WiFi lokal **tanpa internet**.
/// Cukup 1 file ini, tanpa package tambahan (pakai `dart:io` bawaan Dart).
///
/// ---
///
/// ## Arsitektur
///
/// ```
/// ┌──────────────┐          WiFi Lokal           ┌──────────────┐
/// │  HP Server   │◄────── (tanpa internet) ─────►│  HP Client 1 │
/// │  (1 device)  │                               ├──────────────┤
/// │              │◄─────────────────────────────►│  HP Client 2 │
/// │  broadcast() │        auto-reconnect         ├──────────────┤
/// │  sendTo()    │◄─────────────────────────────►│  HP Client N │
/// └──────────────┘                               └──────────────┘
/// ```
///
/// - **Server** = 1 device (HP utama), menjalankan `LocalSocketServer`
/// - **Client** = device lain (bisa banyak), menjalankan `LocalSocketClient`
/// - Semua pesan berformat JSON (`Map<String, dynamic>`)
/// - Gunakan field `'type'` di setiap pesan untuk membedakan jenis pesan
///
/// ---
///
/// ## Quick Start (3 Langkah)
///
/// ### Langkah 1: Copy file ini ke project kamu
/// Taruh di `lib/services/local_socket.dart`, lalu import:
/// ```dart
/// import 'services/local_socket.dart';
/// ```
///
/// ### Langkah 2: Tambah permission Android
/// Di `android/app/src/main/AndroidManifest.xml`, tambahkan SEBELUM tag `<application>`:
/// ```xml
/// <uses-permission android:name="android.permission.INTERNET"/>
/// <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
/// <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
/// ```
/// Lalu di tag `<application>` tambahkan atribut:
/// ```xml
/// <application android:usesCleartextTraffic="true" ...>
/// ```
/// (Tanpa ini, Android akan block koneksi ws:// ke IP lokal)
///
/// ### Langkah 3: Pakai di Widget
/// Lihat contoh lengkap di bawah.
///
/// ---
///
/// ## Contoh Lengkap: Server Widget
///
/// ```dart
/// class ServerPage extends StatefulWidget {
///   @override
///   State<ServerPage> createState() => _ServerPageState();
/// }
///
/// class _ServerPageState extends State<ServerPage> {
///   final server = LocalSocketServer();
///   List<String> messages = [];
///
///   @override
///   void initState() {
///     super.initState();
///
///     // [1] Terima pesan dari client manapun
///     server.onClientMessage = (clientId, message) {
///       setState(() => messages.add('Dari $clientId: ${message['text']}'));
///
///       // Broadcast balik ke semua client
///       server.broadcast({'type': 'chat', 'text': message['text']});
///     };
///
///     // [2] Saat client baru connect, kirim data terbaru
///     server.onClientConnected = (clientId, metadata) {
///       server.sendTo(clientId, {
///         'type': 'init',
///         'allMessages': messages,
///       });
///     };
///
///     // [3] Update UI saat jumlah client berubah
///     server.addListener(() => setState(() {}));
///
///     // [4] Start server
///     server.start(port: 8080);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(
///         title: Text('Server | IP: ${server.localIp ?? "..."}'),
///         // Tampilkan IP ini ke user, client butuh IP ini untuk connect
///       ),
///       body: Column(
///         children: [
///           Text('${server.clientCount} device terhubung'),
///           Expanded(
///             child: ListView(
///               children: messages.map((m) => Text(m)).toList(),
///             ),
///           ),
///         ],
///       ),
///     );
///   }
///
///   @override
///   void dispose() {
///     server.dispose(); // PENTING: selalu dispose saat widget dihapus
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Contoh Lengkap: Client Widget
///
/// ```dart
/// class ClientPage extends StatefulWidget {
///   @override
///   State<ClientPage> createState() => _ClientPageState();
/// }
///
/// class _ClientPageState extends State<ClientPage> {
///   final client = LocalSocketClient();
///   List<String> messages = [];
///
///   @override
///   void initState() {
///     super.initState();
///
///     // [1] Terima pesan dari server
///     client.onMessage = (message) {
///       if (message['type'] == 'chat') {
///         setState(() => messages.add(message['text']));
///       }
///       if (message['type'] == 'init') {
///         setState(() => messages = List<String>.from(message['allMessages']));
///       }
///     };
///
///     // [2] Callback saat reconnect berhasil
///     client.onReconnected = () {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text('Terhubung kembali!')),
///       );
///     };
///
///     // [3] Update UI saat status koneksi berubah
///     client.addListener(() => setState(() {}));
///
///     // [4] Connect ke server
///     //     IP = lihat di layar server, metadata = identitas client
///     client.connect('192.168.1.100', port: 8080, metadata: {'name': 'Andi'});
///   }
///
///   void _sendMessage(String text) {
///     // Kirim pesan -- kalau offline, otomatis masuk antrian
///     client.send({'type': 'chat', 'text': text});
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(
///         title: Text(client.connected ? 'Online' : 'Offline'),
///         // client.reconnecting == true artinya sedang coba reconnect
///       ),
///       body: ListView(
///         children: messages.map((m) => Text(m)).toList(),
///       ),
///     );
///   }
///
///   @override
///   void dispose() {
///     client.dispose(); // PENTING: selalu dispose
///     super.dispose();
///   }
/// }
/// ```
///
/// ---
///
/// ## API Reference Ringkas
///
/// ### LocalSocketServer
/// | Method/Property      | Fungsi                                              |
/// |----------------------|-----------------------------------------------------|
/// | `start(port: 8080)`  | Jalankan server                                     |
/// | `stop()`             | Matikan server                                      |
/// | `broadcast(msg)`     | Kirim pesan ke SEMUA client                         |
/// | `sendTo(id, msg)`    | Kirim pesan ke 1 client (pakai clientId)             |
/// | `running`            | `true` jika server aktif                            |
/// | `localIp`            | IP lokal server (tampilkan ke user)                 |
/// | `clientCount`        | Jumlah client terhubung                             |
/// | `clients`            | Daftar ConnectedClient                              |
/// | `onClientMessage`    | Callback: pesan masuk `(clientId, message)`          |
/// | `onClientConnected`  | Callback: client baru `(clientId, metadata)`         |
/// | `onClientDisconnected` | Callback: client pergi `(clientId)`                |
///
/// ### LocalSocketClient
/// | Method/Property      | Fungsi                                              |
/// |----------------------|-----------------------------------------------------|
/// | `connect(ip, ...)`   | Connect ke server                                   |
/// | `disconnect()`       | Putus koneksi (manual, tidak auto-reconnect)        |
/// | `send(msg)`          | Kirim pesan (otomatis antri kalau offline)           |
/// | `connected`          | `true` jika terhubung                               |
/// | `reconnecting`       | `true` jika sedang coba reconnect                   |
/// | `pendingCount`       | Jumlah pesan di antrian (belum terkirim)            |
/// | `onMessage`          | Callback: pesan dari server `(message)`              |
/// | `onReconnected`      | Callback: berhasil reconnect `()`                    |
/// | `onDisconnected`     | Callback: koneksi putus `()`                         |
///
/// ---
///
/// ## Format Pesan
///
/// Semua pesan WAJIB berupa `Map<String, dynamic>`.
/// Disarankan selalu pakai field `'type'` untuk membedakan jenis pesan:
/// ```dart
/// // Contoh kirim
/// client.send({'type': 'order', 'table': 5, 'items': ['Nasi Goreng']});
/// server.broadcast({'type': 'notification', 'text': 'Pesanan siap!'});
///
/// // Contoh terima & handle berdasarkan type
/// client.onMessage = (message) {
///   switch (message['type']) {
///     case 'notification':
///       showAlert(message['text']);
///     case 'order_update':
///       updateOrder(message['orderId'], message['status']);
///   }
/// };
/// ```
///
/// Pesan internal (diawali `_`) di-handle otomatis, jangan pakai:
/// - `_welcome` → dikirim server ke client saat connect
/// - `_identify` → dikirim client ke server untuk kirim metadata
///
/// ---
///
/// ## Troubleshooting
///
/// **"Connection refused" / tidak bisa connect:**
/// - Pastikan server dan client di WiFi yang SAMA
/// - Pastikan IP yang dimasukkan benar (lihat di layar server)
/// - Pastikan `android:usesCleartextTraffic="true"` sudah ditambahkan
/// - Pastikan permission INTERNET ada di AndroidManifest.xml
///
/// **"Connection lost" terus-menerus:**
/// - Cek jarak device ke router WiFi
/// - Cek apakah server masih berjalan (`server.running`)
/// - Client akan auto-reconnect, tunggu beberapa detik
///
/// **Pesan tidak sampai:**
/// - Pastikan field `'type'` tidak diawali `_` (reserved untuk internal)
/// - Cek `client.pendingCount` -- jika > 0, pesan masih di antrian (offline)
/// - Cek `server.logs` / `client.logs` untuk debug
///
/// **Performa lambat dengan banyak device:**
/// - Jangan broadcast terlalu sering (max ~10x/detik sudah cukup)
/// - Kirim data sekecil mungkin (jangan kirim seluruh database tiap update)
/// - Gunakan `sendTo()` jika pesan hanya untuk 1 client
///
/// ---
///
/// ## Fitur Bawaan
/// - Auto-reconnect: client otomatis coba connect ulang (1s → 2s → 4s → 8s → 15s max)
/// - Message queue: pesan yang dikirim saat offline tersimpan, terkirim saat reconnect
/// - State sync: server bisa kirim data ke client baru via `onClientConnected`
/// - Client identity: client kirim metadata (nama, role) saat connect
/// - Log internal: semua aktivitas tercatat di `.logs` (max 200 entry)
/// - ChangeNotifier: tinggal `addListener(() => setState(() {}))` untuk auto-update UI
library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SERVER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Info tentang 1 client yang terhubung ke server.
class ConnectedClient {
  /// ID unik client (format: "ip:port")
  final String id;

  /// IP address client
  final String address;

  /// Waktu client terhubung
  final DateTime connectedAt;

  /// Metadata yang dikirim client saat identify (misal: nama, role, dll).
  /// Null sampai client mengirim pesan `identify`.
  Map<String, dynamic>? metadata;

  final WebSocket _socket;

  ConnectedClient._({
    required this.id,
    required this.address,
    required WebSocket socket,
  })  : _socket = socket,
        connectedAt = DateTime.now();
}

/// WebSocket server yang berjalan di device lokal.
///
/// Jalankan [start] untuk mulai mendengarkan koneksi.
/// Gunakan [broadcast] untuk kirim ke semua client,
/// atau [sendTo] untuk kirim ke client tertentu.
class LocalSocketServer extends ChangeNotifier {
  HttpServer? _server;
  final Map<String, ConnectedClient> _clients = {};
  final List<SocketLogEntry> _logs = [];
  bool _running = false;
  String? _localIp;

  // ─── Public getters ─────────────────────────────────

  /// Apakah server sedang berjalan.
  bool get running => _running;

  /// IP lokal server (untuk ditampilkan ke user supaya client bisa connect).
  /// Null sebelum [start] dipanggil.
  String? get localIp => _localIp;

  /// Jumlah client yang terhubung saat ini.
  int get clientCount => _clients.length;

  /// Daftar client yang terhubung (read-only).
  List<ConnectedClient> get clients => _clients.values.toList();

  /// Log aktivitas server (max 200 entry, FIFO).
  List<SocketLogEntry> get logs => List.unmodifiable(_logs);

  // ─── Callbacks ──────────────────────────────────────

  /// Dipanggil setiap kali ada pesan masuk dari client.
  /// [clientId] = ID client pengirim, [message] = isi pesan (JSON decoded).
  void Function(String clientId, Map<String, dynamic> message)?
      onClientMessage;

  /// Dipanggil saat client baru terhubung dan sudah identify.
  /// [clientId] = ID client, [metadata] = data identitas dari client.
  void Function(String clientId, Map<String, dynamic>? metadata)?
      onClientConnected;

  /// Dipanggil saat client disconnect.
  void Function(String clientId)? onClientDisconnected;

  // ─── Core methods ───────────────────────────────────

  /// Mulai menjalankan WebSocket server.
  ///
  /// [port] default 8080. Server akan listen di 0.0.0.0 (semua interface).
  /// IP lokal otomatis dideteksi dan tersedia di [localIp].
  Future<void> start({int port = 8080}) async {
    if (_running) return;

    _localIp = await _getLocalIp();
    _server = await HttpServer.bind('0.0.0.0', port);
    _running = true;
    _log('Server started on $_localIp:$port');
    notifyListeners();

    await for (final request in _server!) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        _handleWebSocket(request);
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('LocalSocket Server Running')
          ..close();
      }
    }
  }

  /// Kirim pesan ke SEMUA client yang terhubung.
  ///
  /// [exclude] (opsional) → ID client yang tidak ikut menerima.
  /// Return: jumlah client yang berhasil menerima.
  int broadcast(Map<String, dynamic> message, {String? exclude}) {
    final encoded = jsonEncode(message);
    int sent = 0;

    _clients.removeWhere((_, c) => c._socket.readyState != WebSocket.open);

    for (final entry in _clients.entries) {
      if (entry.key == exclude) continue;
      try {
        entry.value._socket.add(encoded);
        sent++;
      } catch (_) {}
    }
    _log('Broadcast [${message['type'] ?? '?'}] to $sent clients');
    notifyListeners();
    return sent;
  }

  /// Kirim pesan ke 1 client tertentu berdasarkan [clientId].
  ///
  /// Return `true` jika berhasil terkirim.
  bool sendTo(String clientId, Map<String, dynamic> message) {
    final client = _clients[clientId];
    if (client == null || client._socket.readyState != WebSocket.open) {
      return false;
    }
    try {
      client._socket.add(jsonEncode(message));
      _log('Sent [${message['type'] ?? '?'}] to $clientId');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stop server dan disconnect semua client.
  Future<void> stop() async {
    for (final client in _clients.values) {
      await client._socket.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _running = false;
    _log('Server stopped');
    notifyListeners();
  }

  // ─── Internal ───────────────────────────────────────

  void _handleWebSocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    final addr = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final port = request.connectionInfo?.remotePort ?? 0;
    final clientId = '$addr:$port';

    final client = ConnectedClient._(
      id: clientId,
      address: addr,
      socket: socket,
    );
    _clients[clientId] = client;

    _log('Client connected: $clientId (total: ${_clients.length})');
    notifyListeners();

    // Kirim welcome message otomatis
    socket.add(jsonEncode({
      'type': '_welcome',
      'clientId': clientId,
      'clientsOnline': _clients.length,
    }));

    socket.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;

          // Pesan internal: client identify
          if (message['type'] == '_identify') {
            client.metadata = message['metadata'] as Map<String, dynamic>?;
            _log('Client $clientId identified: ${client.metadata}');
            onClientConnected?.call(clientId, client.metadata);
            notifyListeners();
            return;
          }

          _log('Received [${message['type'] ?? '?'}] from $clientId');
          onClientMessage?.call(clientId, message);
          notifyListeners();
        } catch (e) {
          _log('Error parsing from $clientId: $e');
        }
      },
      onDone: () {
        _clients.remove(clientId);
        _log('Client disconnected: $clientId (total: ${_clients.length})');
        onClientDisconnected?.call(clientId);
        notifyListeners();
      },
      onError: (error) {
        _clients.remove(clientId);
        _log('Client error $clientId: $error');
        onClientDisconnected?.call(clientId);
        notifyListeners();
      },
    );
  }

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '0.0.0.0';
  }

  void _log(String text) {
    _logs.add(SocketLogEntry(text));
    if (_logs.length > 200) _logs.removeAt(0);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  CLIENT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// WebSocket client yang connect ke [LocalSocketServer].
///
/// Fitur utama:
/// - Auto-reconnect dengan exponential backoff
/// - Message queue: pesan offline otomatis dikirim saat reconnect
/// - Identity: kirim metadata saat connect (nama, role, dll)
class LocalSocketClient extends ChangeNotifier {
  WebSocket? _socket;
  bool _connected = false;
  bool _intentionalDisconnect = false;
  bool _reconnecting = false;
  final List<SocketLogEntry> _logs = [];
  final List<Map<String, dynamic>> _pendingMessages = [];

  String? _serverIp;
  int _port = 8080;
  Map<String, dynamic>? _metadata;
  String? _clientId;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  /// Delay reconnect maksimal (default 15 detik).
  Duration maxReconnectDelay;

  /// Timeout saat connect ke server (default 5 detik).
  Duration connectTimeout;

  LocalSocketClient({
    this.maxReconnectDelay = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 5),
  });

  // ─── Public getters ─────────────────────────────────

  /// Apakah sedang terhubung ke server.
  bool get connected => _connected;

  /// Apakah sedang mencoba reconnect.
  bool get reconnecting => _reconnecting;

  /// ID client yang diberikan server setelah connect. Null sebelum connect.
  String? get clientId => _clientId;

  /// Jumlah pesan yang menunggu dikirim (antrian offline).
  int get pendingCount => _pendingMessages.length;

  /// Log aktivitas client (max 200 entry, FIFO).
  List<SocketLogEntry> get logs => List.unmodifiable(_logs);

  // ─── Callbacks ──────────────────────────────────────

  /// Dipanggil setiap kali ada pesan dari server.
  void Function(Map<String, dynamic> message)? onMessage;

  /// Dipanggil saat berhasil reconnect (bukan connect pertama kali).
  void Function()? onReconnected;

  /// Dipanggil saat koneksi terputus (bukan intentional disconnect).
  void Function()? onDisconnected;

  // ─── Core methods ───────────────────────────────────

  /// Connect ke server.
  ///
  /// [serverIp] → IP server (lihat di layar server, misal "192.168.1.100").
  /// [port] → port server (default 8080).
  /// [metadata] → data identitas yang dikirim ke server (misal: nama, role).
  ///   Server bisa menggunakan ini untuk filter/sync data per client.
  ///
  /// Return `true` jika berhasil connect.
  Future<bool> connect(
    String serverIp, {
    int port = 8080,
    Map<String, dynamic>? metadata,
  }) async {
    _serverIp = serverIp;
    _port = port;
    _metadata = metadata;
    _intentionalDisconnect = false;
    _reconnectAttempt = 0;
    return _doConnect();
  }

  /// Kirim pesan ke server.
  ///
  /// Jika sedang offline, pesan otomatis masuk antrian
  /// dan akan dikirim begitu reconnect berhasil.
  void send(Map<String, dynamic> message) {
    if (_connected && _socket != null) {
      _socketSend(message);
      _log('Sent [${message['type'] ?? '?'}]');
    } else {
      _pendingMessages.add(message);
      _log('Queued [${message['type'] ?? '?'}] '
          '(offline, ${_pendingMessages.length} pending)');
    }
    notifyListeners();
  }

  /// Disconnect dari server secara manual. Tidak akan auto-reconnect.
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnecting = false;
    await _socket?.close();
    _socket = null;
    _connected = false;
    _clientId = null;
    _log('Disconnected');
    notifyListeners();
  }

  // ─── Internal ───────────────────────────────────────

  Future<bool> _doConnect() async {
    try {
      _log(_reconnecting
          ? 'Reconnecting to $_serverIp:$_port '
              '(attempt ${_reconnectAttempt + 1})...'
          : 'Connecting to $_serverIp:$_port...');
      notifyListeners();

      _socket = await WebSocket.connect(
        'ws://$_serverIp:$_port',
      ).timeout(connectTimeout);

      _connected = true;
      _reconnectAttempt = 0;
      final wasReconnecting = _reconnecting;
      _reconnecting = false;
      _log('Connected!');
      notifyListeners();

      // Kirim identitas ke server
      if (_metadata != null) {
        _socketSend({'type': '_identify', 'metadata': _metadata});
      }

      // Kirim semua pesan yang tertunda
      _flushPendingMessages();

      if (wasReconnecting) {
        onReconnected?.call();
      }

      _socket!.listen(
        (data) {
          try {
            final message =
                jsonDecode(data as String) as Map<String, dynamic>;

            // Pesan internal: welcome dari server
            if (message['type'] == '_welcome') {
              _clientId = message['clientId'] as String?;
              _log('Assigned clientId: $_clientId');
              notifyListeners();
              return;
            }

            _log('Received [${message['type'] ?? '?'}]');
            onMessage?.call(message);
            notifyListeners();
          } catch (e) {
            _log('Parse error: $e');
          }
        },
        onDone: () {
          _connected = false;
          _log('Disconnected from server');
          onDisconnected?.call();
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (error) {
          _connected = false;
          _log('Connection error: $error');
          onDisconnected?.call();
          notifyListeners();
          _scheduleReconnect();
        },
      );

      return true;
    } catch (e) {
      _log('Failed to connect: $e');
      _connected = false;
      _reconnecting = false;
      notifyListeners();
      _scheduleReconnect();
      return false;
    }
  }

  /// Exponential backoff: 1s → 2s → 4s → 8s → 15s (max)
  void _scheduleReconnect() {
    if (_intentionalDisconnect || _serverIp == null) return;

    _reconnecting = true;
    _reconnectAttempt++;

    final delayMs = (1000 * (1 << _reconnectAttempt.clamp(0, 4)))
        .clamp(1000, maxReconnectDelay.inMilliseconds);
    final delay = Duration(milliseconds: delayMs);

    _log('Reconnecting in ${delay.inSeconds}s...');
    notifyListeners();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalDisconnect) _doConnect();
    });
  }

  void _socketSend(Map<String, dynamic> message) {
    try {
      _socket!.add(jsonEncode(message));
    } catch (e) {
      _pendingMessages.add(message);
      _log('Send failed, queued: $e');
    }
  }

  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty) return;
    _log('Flushing ${_pendingMessages.length} pending messages...');
    final messages = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final msg in messages) {
      _socketSend(msg);
    }
    _log('All pending messages sent');
    notifyListeners();
  }

  void _log(String text) {
    _logs.add(SocketLogEntry(text));
    if (_logs.length > 200) _logs.removeAt(0);
  }

  @override
  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SHARED
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Entry log aktivitas server/client.
class SocketLogEntry {
  final DateTime time;
  final String text;
  SocketLogEntry(this.text) : time = DateTime.now();

  @override
  String toString() =>
      '${time.hour}:${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')} $text';
}
