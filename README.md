# POS Resto

Aplikasi Point of Sale (POS) restoran berbasis Flutter dengan komunikasi **real-time antar device via WiFi lokal** — tanpa internet, tanpa server eksternal.

## Arsitektur

```
┌──────────────────┐        WiFi Lokal (tanpa internet)        ┌──────────────────┐
│   HP Kasir       │◄────────── WebSocket ──────────────►│   HP Waiter 1    │
│   (Server)       │                                           ├──────────────────┤
│                  │◄──────────────────────────────────────►│   HP Waiter 2    │
│  • Terima order  │         auto-reconnect                    ├──────────────────┤
│  • Proses & bayar│◄──────────────────────────────────────►│   HP Waiter N    │
│  • Broadcast     │         message queue                     └──────────────────┘
└──────────────────┘
```

- **Kasir** = 1 device utama, menjalankan WebSocket server (`LocalSocketServer`)
- **Waiter** = device lain (bisa banyak), connect sebagai client (`LocalSocketClient`)
- Semua komunikasi lewat **WiFi lokal**, tidak butuh internet
- Teknologi: **Pure Dart WebSocket** (`dart:io`) — tanpa package tambahan

## Fitur Aplikasi

### Kasir (Server)
- Otomatis menjalankan WebSocket server saat dibuka
- Menampilkan IP server untuk waiter connect
- Menerima order dari waiter secara real-time
- Membuat order langsung dari kasir
- Mengelola status order: **Masuk → Proses → Siap → Bayar**
- Pembayaran tunai dengan perhitungan kembalian
- Struk pembayaran
- Laporan penjualan & menu terlaris

### Waiter (Client)
- Connect ke kasir dengan memasukkan IP server dan nama waiter
- Pilih meja dan tambahkan item menu ke pesanan
- Kirim order ke kasir secara real-time
- Melihat status order yang di-update oleh kasir
- Laporan penjualan per waiter
- Auto-reconnect jika koneksi terputus
- Message queue — order tetap terkirim walau sempat offline

## Cara Pakai

### Langkah 1: Setup Jaringan
Pastikan **semua HP** terhubung ke **WiFi yang sama**. Tidak perlu akses internet.

### Langkah 2: Buka Kasir (di HP utama)
1. Buka aplikasi → pilih **"Kasir (Server)"**
2. Tunggu sampai muncul bar hijau: `Server aktif • IP: 192.168.x.x:8080`
3. **Catat IP tersebut** — waiter butuh IP ini untuk connect

### Langkah 3: Buka Waiter (di HP lain)
1. Buka aplikasi → pilih **"Waiter (Client)"**
2. Masukkan **nama waiter** (misal: "Andi")
3. Masukkan **IP server** dari layar kasir (misal: `192.168.1.100`)
4. Tekan **Connect**
5. Jika berhasil, langsung masuk ke halaman menu

### Langkah 4: Buat Pesanan
1. **Waiter**: Pilih meja → tambahkan item → tekan **"Kirim"**
2. **Kasir**: Order muncul di tab **"Masuk"** → tekan **"Proses"**
3. **Kasir**: Setelah siap → tekan **"Siap Antar"**
4. **Kasir**: Setelah diantar → tekan **"Bayar Tunai"** → masukkan nominal
5. **Waiter**: Status order otomatis ter-update secara real-time

### Alur Status Order

```
[Masuk/Pending] → [Diproses] → [Siap Antar] → [Bayar/Lunas]
                                                     ↓
                 [Dibatalkan] ←─── (bisa tolak) ────┘
```

## Struktur Project

```
lib/
├── main.dart                          # Entry point
├── models/
│   ├── menu_item.dart                 # Model menu & daftar menu default
│   └── order.dart                     # Model order, status, formatter Rupiah
├── screens/
│   ├── role_selection_screen.dart      # Pilih Kasir / Waiter
│   ├── kasir_screen.dart              # Halaman kasir (server)
│   └── waiter_screen.dart             # Halaman waiter (client)
└── services/
    └── local_socket.dart              # WebSocket server & client (1 file)
```

## Protokol Komunikasi

Semua pesan berformat JSON (`Map<String, dynamic>`) dengan field `type` sebagai identifier.

### Pesan dari Waiter → Kasir

| Type | Deskripsi | Payload |
|---|---|---|
| `new_order` | Kirim pesanan baru | `{ order: Order.toJson() }` |

### Pesan dari Kasir → Waiter (broadcast)

| Type | Deskripsi | Payload |
|---|---|---|
| `order_confirmed` | Konfirmasi order diterima | `{ orderId, status }` |
| `order_status_update` | Update status order | `{ orderId, status }` |
| `order_paid` | Order sudah dibayar | `{ orderId, paidAmount, changeAmount, paidAt }` |

### Pesan dari Kasir → Waiter (unicast, saat reconnect)

| Type | Deskripsi | Payload |
|---|---|---|
| `state_sync` | Sinkronisasi order saat waiter reconnect | `{ orders: [Order.toJson()] }` |

### Pesan Internal (otomatis, jangan pakai)

| Type | Arah | Deskripsi |
|---|---|---|
| `_welcome` | Server → Client | Kirim clientId saat pertama connect |
| `_identify` | Client → Server | Kirim metadata (nama, role) waiter |

---

# Dokumentasi LocalSocket Service

> **File:** `lib/services/local_socket.dart`
>
> Library WebSocket plug & play untuk komunikasi real-time antar device via WiFi lokal.
> Hanya menggunakan `dart:io` bawaan Dart — **tanpa package tambahan**.

## Konsep

Satu device bertindak sebagai **Server**, device lain sebagai **Client**.
Server bisa mengirim pesan ke semua client (broadcast) atau ke 1 client tertentu (unicast).
Client mengirim pesan hanya ke server.

```
┌──────────────┐          WiFi Lokal           ┌──────────────┐
│  HP Server   │◄────── (tanpa internet) ─────►│  HP Client 1 │
│  (1 device)  │                               ├──────────────┤
│              │◄─────────────────────────────►│  HP Client 2 │
│  broadcast() │        auto-reconnect         ├──────────────┤
│  sendTo()    │◄─────────────────────────────►│  HP Client N │
└──────────────┘                               └──────────────┘
```

## Setup

### 1. Copy file
Taruh `local_socket.dart` di `lib/services/`, lalu import:
```dart
import 'services/local_socket.dart';
```

### 2. Permission Android
Di `android/app/src/main/AndroidManifest.xml`, tambahkan **sebelum** tag `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
```
Lalu di tag `<application>` tambahkan atribut:
```xml
<application android:usesCleartextTraffic="true" ...>
```

## API Reference — LocalSocketServer

### Membuat & Menjalankan Server

```dart
final server = LocalSocketServer();

// Jalankan server (default port 8080)
await server.start(port: 8080);

// Cek status
print(server.running);       // true
print(server.localIp);       // "192.168.1.100" — tampilkan ke user
print(server.clientCount);   // 3
print(server.clients);       // List<ConnectedClient>
```

### Mengirim Pesan

```dart
// Broadcast ke SEMUA client
server.broadcast({'type': 'notification', 'text': 'Pesanan siap!'});

// Broadcast ke semua KECUALI 1 client
server.broadcast({'type': 'chat', 'text': 'Halo'}, exclude: 'clientId');

// Kirim ke 1 client tertentu (unicast)
server.sendTo(clientId, {'type': 'init', 'data': {...}});
```

### Menerima Pesan & Event

```dart
// Pesan masuk dari client
server.onClientMessage = (clientId, message) {
  print('Dari $clientId: ${message['type']}');
};

// Client baru terhubung (sudah identify)
server.onClientConnected = (clientId, metadata) {
  print('${metadata?['name']} bergabung');
  // Kirim data terbaru ke client baru
  server.sendTo(clientId, {'type': 'state_sync', ...});
};

// Client disconnect
server.onClientDisconnected = (clientId) {
  print('$clientId pergi');
};

// Auto-update UI (ChangeNotifier)
server.addListener(() => setState(() {}));
```

### Stop & Dispose

```dart
await server.stop();   // Stop server, disconnect semua client
server.dispose();      // WAJIB dipanggil di dispose() widget
```

### Tabel Method & Property

| Method/Property | Tipe | Deskripsi |
|---|---|---|
| `start({port})` | `Future<void>` | Jalankan server |
| `stop()` | `Future<void>` | Matikan server |
| `broadcast(msg, {exclude})` | `int` | Kirim ke semua client, return jumlah penerima |
| `sendTo(clientId, msg)` | `bool` | Kirim ke 1 client, return sukses/gagal |
| `running` | `bool` | `true` jika server aktif |
| `localIp` | `String?` | IP lokal server |
| `clientCount` | `int` | Jumlah client terhubung |
| `clients` | `List<ConnectedClient>` | Daftar client |
| `logs` | `List<SocketLogEntry>` | Log aktivitas (max 200) |
| `onClientMessage` | `Function(clientId, message)` | Callback: pesan masuk |
| `onClientConnected` | `Function(clientId, metadata)` | Callback: client baru |
| `onClientDisconnected` | `Function(clientId)` | Callback: client pergi |

## API Reference — LocalSocketClient

### Membuat & Connect

```dart
final client = LocalSocketClient(
  maxReconnectDelay: Duration(seconds: 15),  // opsional
  connectTimeout: Duration(seconds: 5),      // opsional
);

// Connect ke server
bool success = await client.connect(
  '192.168.1.100',         // IP server
  port: 8080,              // port (default 8080)
  metadata: {'name': 'Andi', 'role': 'waiter'},  // identitas
);
```

### Mengirim Pesan

```dart
// Kirim pesan — jika offline, otomatis masuk antrian
client.send({'type': 'new_order', 'order': {...}});

// Cek antrian
print(client.pendingCount);  // jumlah pesan yang belum terkirim
```

### Menerima Pesan & Event

```dart
// Pesan dari server
client.onMessage = (message) {
  switch (message['type']) {
    case 'order_confirmed':
      print('Order ${message['orderId']} diterima!');
    case 'notification':
      showAlert(message['text']);
  }
};

// Berhasil reconnect (bukan connect pertama)
client.onReconnected = () {
  print('Terhubung kembali!');
};

// Koneksi terputus
client.onDisconnected = () {
  print('Koneksi putus, mencoba reconnect...');
};

// Auto-update UI
client.addListener(() => setState(() {}));
```

### Disconnect & Dispose

```dart
await client.disconnect();  // Disconnect manual (tidak auto-reconnect)
client.dispose();           // WAJIB dipanggil di dispose() widget
```

### Tabel Method & Property

| Method/Property | Tipe | Deskripsi |
|---|---|---|
| `connect(ip, {port, metadata})` | `Future<bool>` | Connect ke server |
| `disconnect()` | `Future<void>` | Putus koneksi (manual) |
| `send(msg)` | `void` | Kirim pesan (otomatis antri jika offline) |
| `connected` | `bool` | `true` jika terhubung |
| `reconnecting` | `bool` | `true` jika sedang reconnect |
| `clientId` | `String?` | ID client dari server |
| `pendingCount` | `int` | Jumlah pesan di antrian |
| `logs` | `List<SocketLogEntry>` | Log aktivitas (max 200) |
| `onMessage` | `Function(message)` | Callback: pesan dari server |
| `onReconnected` | `Function()` | Callback: berhasil reconnect |
| `onDisconnected` | `Function()` | Callback: koneksi putus |

## Contoh Lengkap: Server Widget

```dart
class ServerPage extends StatefulWidget {
  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final server = LocalSocketServer();
  List<String> messages = [];

  @override
  void initState() {
    super.initState();

    server.onClientMessage = (clientId, message) {
      setState(() => messages.add('Dari $clientId: ${message['text']}'));
      server.broadcast({'type': 'chat', 'text': message['text']});
    };

    server.onClientConnected = (clientId, metadata) {
      server.sendTo(clientId, {
        'type': 'init',
        'allMessages': messages,
      });
    };

    server.addListener(() => setState(() {}));
    server.start(port: 8080);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Server | IP: ${server.localIp ?? "..."}')),
      body: Column(
        children: [
          Text('${server.clientCount} device terhubung'),
          Expanded(
            child: ListView(
              children: messages.map((m) => Text(m)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    server.dispose();
    super.dispose();
  }
}
```

## Contoh Lengkap: Client Widget

```dart
class ClientPage extends StatefulWidget {
  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  final client = LocalSocketClient();
  List<String> messages = [];

  @override
  void initState() {
    super.initState();

    client.onMessage = (message) {
      if (message['type'] == 'chat') {
        setState(() => messages.add(message['text']));
      }
      if (message['type'] == 'init') {
        setState(() => messages = List<String>.from(message['allMessages']));
      }
    };

    client.onReconnected = () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terhubung kembali!')),
      );
    };

    client.addListener(() => setState(() {}));
    client.connect('192.168.1.100', port: 8080, metadata: {'name': 'Andi'});
  }

  void _sendMessage(String text) {
    client.send({'type': 'chat', 'text': text});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(client.connected ? 'Online' : 'Offline')),
      body: ListView(
        children: messages.map((m) => Text(m)).toList(),
      ),
    );
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }
}
```

## Fitur Bawaan

| Fitur | Deskripsi |
|---|---|
| **Auto-reconnect** | Client otomatis coba connect ulang (1s → 2s → 4s → 8s → 15s max) |
| **Message queue** | Pesan yang dikirim saat offline tersimpan, terkirim saat reconnect |
| **State sync** | Server kirim data ke client baru via `onClientConnected` |
| **Client identity** | Client kirim metadata (nama, role) saat connect |
| **Log internal** | Semua aktivitas tercatat di `.logs` (max 200 entry) |
| **ChangeNotifier** | Tinggal `addListener(() => setState(() {}))` untuk auto-update UI |

## Troubleshooting

| Masalah | Solusi |
|---|---|
| **Connection refused** | Pastikan server & client di WiFi yang sama, IP benar, `usesCleartextTraffic="true"` sudah ditambahkan |
| **Connection lost terus** | Cek jarak ke router, pastikan server masih running. Client akan auto-reconnect |
| **Pesan tidak sampai** | Jangan pakai type diawali `_` (reserved). Cek `pendingCount` dan `logs` |
| **Performa lambat** | Jangan broadcast >10x/detik. Kirim data sekecil mungkin. Gunakan `sendTo()` untuk 1 client |

## Tech Stack

- **Flutter** (Dart SDK ^3.8.1)
- **dart:io** WebSocket (tanpa package tambahan)
- **Material Design 3**

## Menjalankan Aplikasi

```bash
# Clone
git clone https://github.com/prasproject/flutter-local-server.git
cd flutter-local-server

# Install dependencies
flutter pub get

# Jalankan
flutter run
```

## Lisensi

MIT
