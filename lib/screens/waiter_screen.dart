import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/local_socket.dart';

class WaiterScreen extends StatefulWidget {
  const WaiterScreen({super.key});

  @override
  State<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends State<WaiterScreen> {
  final LocalSocketClient _client = LocalSocketClient();
  final _ipController = TextEditingController(text: '192.168.');
  final _nameController = TextEditingController();
  final Map<String, int> _cart = {};
  int _selectedTable = 1;
  final List<Order> _myOrders = [];
  int _currentNav = 0;
  int _orderCounter = 0;

  @override
  void initState() {
    super.initState();
    _client.onMessage = _handleMessage;
    _client.onReconnected = () {
      _showSnack('Terhubung kembali ke server!');
    };
    _client.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _handleMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'order_confirmed':
        _showSnack('Order #${message['orderId']} diterima kasir');
      case 'order_status_update':
        final orderId = message['orderId'] as String;
        final status = OrderStatus.values.byName(message['status'] as String);
        setState(() {
          final order = _myOrders.where((o) => o.id == orderId).firstOrNull;
          if (order != null) order.status = status;
        });
        final label = switch (status) {
          OrderStatus.processing => 'sedang diproses',
          OrderStatus.ready => 'SIAP ANTAR!',
          OrderStatus.cancelled => 'DIBATALKAN',
          _ => status.name,
        };
        _showSnack('Order #$orderId $label');
      case 'order_paid':
        final orderId = message['orderId'] as String;
        setState(() {
          final order = _myOrders.where((o) => o.id == orderId).firstOrNull;
          if (order != null) {
            order.status = OrderStatus.completed;
            order.paidAmount = message['paidAmount'] as int;
            order.changeAmount = message['changeAmount'] as int;
            order.paidAt = DateTime.parse(message['paidAt'] as String);
          }
        });
        _showSnack('Order #$orderId LUNAS!');
      case 'state_sync':
        _handleStateSync(message);
    }
  }

  void _handleStateSync(Map<String, dynamic> message) {
    final serverOrders = (message['orders'] as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();

    setState(() {
      for (final serverOrder in serverOrders) {
        final existing =
            _myOrders.where((o) => o.id == serverOrder.id).firstOrNull;
        if (existing != null) {
          existing.status = serverOrder.status;
          existing.paidAmount = serverOrder.paidAmount;
          existing.changeAmount = serverOrder.changeAmount;
          existing.paidAt = serverOrder.paidAt;
        } else {
          _myOrders.add(serverOrder);
        }
      }
    });
    _showSnack('${serverOrders.length} order di-sync dari server');
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _client.dispose();
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_client.connected && !_client.reconnecting) {
      return _buildConnectScreen();
    }
    return _buildMainScreen();
  }

  // ─── Connect Screen ────────────────────────────────

  Widget _buildConnectScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF16213E),
      appBar: AppBar(
        title: const Text('Waiter'),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.room_service, size: 80, color: Colors.white54),
              const SizedBox(height: 24),
              const Text('Hubungkan ke Kasir',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nama Waiter',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.person, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'IP Server (lihat di HP kasir)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.wifi, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.link),
                  label:
                      const Text('Connect', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE94560),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Masukkan nama waiter');
      return;
    }
    final success = await _client.connect(
      _ipController.text.trim(),
      metadata: {'name': _nameController.text.trim()},
    );
    if (!success && mounted) {
      _showSnack('Gagal connect. Cek IP dan pastikan server aktif.');
    }
  }

  // ─── Main Screen ───────────────────────────────────

  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Waiter: ${_nameController.text}'),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: () => _client.disconnect(),
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          _connectionStatusBar(),
          Expanded(
            child: IndexedStack(
              index: _currentNav,
              children: [
                _buildMenuView(),
                _buildOrdersView(),
                _buildReportView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNav,
        onDestinationSelected: (i) => setState(() => _currentNav = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.restaurant_menu), label: 'Menu'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _myOrders
                  .where((o) =>
                      o.status != OrderStatus.completed &&
                      o.status != OrderStatus.cancelled)
                  .isNotEmpty,
              label: Text(
                  '${_myOrders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).length}'),
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Order',
          ),
          const NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'Laporan'),
        ],
      ),
      floatingActionButton: _currentNav == 0 && _cart.isNotEmpty
          ? _buildCartFab()
          : null,
    );
  }

  Widget _connectionStatusBar() {
    if (_client.reconnecting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.orange[100],
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Menghubungkan ulang ke server...'
                '${_client.pendingCount > 0 ? ' (${_client.pendingCount} pesan tertunda)' : ''}',
                style: TextStyle(color: Colors.orange[900], fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    if (!_client.connected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.red[100],
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 16, color: Colors.red[800]),
            const SizedBox(width: 8),
            Text('Tidak terhubung',
                style: TextStyle(color: Colors.red[800], fontSize: 13)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ─── Menu ──────────────────────────────────────────

  Widget _buildMenuView() {
    return Column(
      children: [
        _tableSelector(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _categorySection('Makanan'),
              _categorySection('Minuman'),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableSelector() {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: 10,
        itemBuilder: (context, index) {
          final table = index + 1;
          final isSelected = table == _selectedTable;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Meja $table'),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedTable = table),
              selectedColor: const Color(0xFFE94560),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _categorySection(String category) {
    final items = defaultMenu.where((m) => m.category == category).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(category,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...items.map(_menuItemTile),
      ],
    );
  }

  Widget _menuItemTile(MenuItem item) {
    final qty = _cart[item.id] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(formatRupiah(item.price),
            style: const TextStyle(color: Color(0xFFE94560))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qty > 0)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() {
                  if (qty <= 1) {
                    _cart.remove(item.id);
                  } else {
                    _cart[item.id] = qty - 1;
                  }
                }),
                color: Colors.red,
              ),
            if (qty > 0)
              Text('$qty',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () => setState(() => _cart[item.id] = qty + 1),
              color: const Color(0xFF0F3460),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartFab() {
    int totalItems = _cart.values.fold(0, (a, b) => a + b);
    int totalPrice = 0;
    _cart.forEach((id, qty) {
      final item = defaultMenu.firstWhere((m) => m.id == id);
      totalPrice += item.price * qty;
    });

    return FloatingActionButton.extended(
      onPressed: _sendOrder,
      backgroundColor: const Color(0xFFE94560),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.send),
      label: Text(
        'Kirim $totalItems item • ${formatRupiah(totalPrice)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _sendOrder() {
    if (_cart.isEmpty) return;

    _orderCounter++;
    final name = _nameController.text.trim();
    final prefix =
        name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'WT';
    final orderId = '$prefix${_orderCounter.toString().padLeft(3, '0')}';

    final items = <OrderItem>[];
    _cart.forEach((id, qty) {
      final menuItem = defaultMenu.firstWhere((m) => m.id == id);
      items.add(OrderItem(menuItem: menuItem, quantity: qty));
    });

    final order = Order(
      id: orderId,
      tableNumber: _selectedTable,
      items: items,
      waiterName: name,
    );

    _client.send({
      'type': 'new_order',
      'order': order.toJson(),
    });

    setState(() {
      _myOrders.insert(0, order);
      _cart.clear();
    });

    _showSnack('Order #$orderId terkirim! (Meja $_selectedTable)');
  }

  // ─── Orders ────────────────────────────────────────

  Widget _buildOrdersView() {
    if (_myOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Belum ada order',
                style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
      );
    }

    final active = _myOrders
        .where((o) =>
            o.status != OrderStatus.completed &&
            o.status != OrderStatus.cancelled)
        .toList();
    final done = _myOrders
        .where((o) =>
            o.status == OrderStatus.completed ||
            o.status == OrderStatus.cancelled)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (active.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text('Aktif (${active.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...active.map(_orderCard),
        ],
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
            child: Text('Selesai (${done.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...done.map(_orderCard),
        ],
      ],
    );
  }

  Widget _orderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(order.status).withValues(alpha: 0.1),
          child: Text('${order.tableNumber}',
              style: TextStyle(
                  color: _statusColor(order.status),
                  fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Text('#${order.id}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _statusBadge(order.status),
          ],
        ),
        subtitle: Text(formatRupiah(order.total)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
            child: Column(
              children: [
                ...order.items.map((item) => Row(
                      children: [
                        Text('${item.quantity}x ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(item.menuItem.name)),
                        Text(formatRupiah(item.subtotal)),
                      ],
                    )),
                if (order.isPaid) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bayar'),
                      Text(formatRupiah(order.paidAmount)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kembali'),
                      Text(formatRupiah(order.changeAmount)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Report ────────────────────────────────────────

  Widget _buildReportView() {
    final paid =
        _myOrders.where((o) => o.status == OrderStatus.completed).toList();
    final totalRevenue = paid.fold(0, (sum, o) => sum + o.total);
    final cancelled =
        _myOrders.where((o) => o.status == OrderStatus.cancelled).length;

    final Map<String, int> itemQty = {};
    for (final order in paid) {
      for (final item in order.items) {
        itemQty[item.menuItem.name] =
            (itemQty[item.menuItem.name] ?? 0) + item.quantity;
      }
    }
    final sortedItems = itemQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Laporan Saya',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(_nameController.text,
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 16),
        Row(
          children: [
            _summaryCard('Penjualan', formatRupiah(totalRevenue),
                Icons.account_balance_wallet, Colors.green),
            const SizedBox(width: 12),
            _summaryCard(
                'Transaksi', '${paid.length}', Icons.receipt, Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _summaryCard('Total Order', '${_myOrders.length}',
                Icons.shopping_cart, Colors.orange),
            const SizedBox(width: 12),
            _summaryCard(
                'Dibatalkan', '$cancelled', Icons.cancel, Colors.red),
          ],
        ),
        if (sortedItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Item Terjual',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...sortedItems.map((e) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      const Color(0xFF0F3460).withValues(alpha: 0.1),
                  child: Text('${e.value}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F3460),
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(e.key),
                trailing: Text('${e.value}x',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
        ],
        if (paid.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Belum ada transaksi selesai',
                      style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.pending => Colors.blue,
        OrderStatus.processing => Colors.orange,
        OrderStatus.ready => Colors.green,
        OrderStatus.completed => Colors.teal,
        OrderStatus.cancelled => Colors.red,
      };

  Widget _statusBadge(OrderStatus status) {
    final label = switch (status) {
      OrderStatus.pending => 'Menunggu',
      OrderStatus.processing => 'Diproses',
      OrderStatus.ready => 'Siap!',
      OrderStatus.completed => 'Lunas',
      OrderStatus.cancelled => 'Batal',
    };
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
