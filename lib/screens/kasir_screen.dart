import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/local_socket.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen>
    with SingleTickerProviderStateMixin {
  final LocalSocketServer _server = LocalSocketServer();
  final List<Order> _orders = [];
  late TabController _tabController;
  int _kasirOrderCounter = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _server.onClientMessage = (clientId, message) {
      if (message['type'] == 'new_order') {
        final order = Order.fromJson(message['order'] as Map<String, dynamic>);
        setState(() => _orders.insert(0, order));
        _server.broadcast({
          'type': 'order_confirmed',
          'orderId': order.id,
          'status': 'pending',
        });
      }
    };

    _server.onClientConnected = (clientId, metadata) {
      final waiterName = metadata?['name'] as String?;
      if (waiterName == null) return;
      final waiterOrders = _orders
          .where((o) =>
              o.waiterName == waiterName &&
              o.status != OrderStatus.cancelled)
          .map((o) => o.toJson())
          .toList();
      if (waiterOrders.isEmpty) return;
      _server.sendTo(clientId, {
        'type': 'state_sync',
        'orders': waiterOrders,
      });
    };

    _server.addListener(() {
      if (mounted) setState(() {});
    });

    _startServer();
  }

  Future<void> _startServer() async {
    await _server.start();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _server.dispose();
    super.dispose();
  }

  List<Order> get _pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();
  List<Order> get _processingOrders =>
      _orders.where((o) => o.status == OrderStatus.processing).toList();
  List<Order> get _readyOrders =>
      _orders.where((o) => o.status == OrderStatus.ready).toList();
  List<Order> get _paidOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();

  void _updateStatus(Order order, OrderStatus newStatus) {
    setState(() => order.status = newStatus);
    _server.broadcast({
      'type': 'order_status_update',
      'orderId': order.id,
      'status': newStatus.name,
    });
  }

  void _showPaymentDialog(Order order) {
    final cashController = TextEditingController();
    int? cashAmount;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final change = (cashAmount ?? 0) - order.total;
          final canPay = cashAmount != null && cashAmount! >= order.total;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.payments, color: Color(0xFFE94560)),
                const SizedBox(width: 8),
                Text('Bayar #${order.id}'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Meja ${order.tableNumber}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${order.items.length} item',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                      const Divider(height: 16),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text('${item.quantity}x ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Expanded(child: Text(item.menuItem.name)),
                                Text(formatRupiah(item.subtotal)),
                              ],
                            ),
                          )),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatRupiah(order.total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Color(0xFFE94560))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cashController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Uang Diterima',
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      cashAmount = int.tryParse(val.replaceAll('.', ''));
                    });
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _quickCashChip(order.total, cashController, setDialogState,
                        (v) => cashAmount = v),
                    _quickCashChip(
                        _roundUp(order.total, 10000),
                        cashController,
                        setDialogState,
                        (v) => cashAmount = v),
                    _quickCashChip(
                        _roundUp(order.total, 50000),
                        cashController,
                        setDialogState,
                        (v) => cashAmount = v),
                    _quickCashChip(100000, cashController, setDialogState,
                        (v) => cashAmount = v),
                  ],
                ),
                const SizedBox(height: 16),
                if (cashAmount != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: canPay ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kembalian',
                            style: TextStyle(
                                color:
                                    canPay ? Colors.green[800] : Colors.red)),
                        Text(
                          canPay ? formatRupiah(change) : 'Kurang!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: canPay ? Colors.green[800] : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                onPressed: canPay
                    ? () {
                        Navigator.pop(ctx);
                        _processPayment(order, cashAmount!, change);
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Bayar Tunai'),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[700]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickCashChip(int amount, TextEditingController controller,
      StateSetter setDialogState, void Function(int) onSet) {
    return ActionChip(
      label: Text(formatRupiah(amount)),
      onPressed: () {
        controller.text = amount.toString();
        setDialogState(() => onSet(amount));
      },
    );
  }

  int _roundUp(int value, int multiple) {
    return ((value / multiple).ceil()) * multiple;
  }

  void _processPayment(Order order, int paidAmount, int change) {
    setState(() {
      order.status = OrderStatus.completed;
      order.paidAmount = paidAmount;
      order.changeAmount = change;
      order.paidAt = DateTime.now();
    });

    _server.broadcast({
      'type': 'order_paid',
      'orderId': order.id,
      'paidAmount': paidAmount,
      'changeAmount': change,
      'paidAt': order.paidAt!.toIso8601String(),
    });

    _showReceipt(order);
  }

  void _showNewOrderSheet() {
    final Map<String, int> cart = {};
    int selectedTable = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          int totalItems = cart.values.fold(0, (a, b) => a + b);
          int totalPrice = 0;
          cart.forEach((id, qty) {
            final item = defaultMenu.firstWhere((m) => m.id == id);
            totalPrice += item.price * qty;
          });

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (ctx, scrollController) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE94560),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white54,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text('Order Baru (Kasir)',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: 10,
                    itemBuilder: (_, i) {
                      final t = i + 1;
                      final sel = t == selectedTable;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Meja $t'),
                          selected: sel,
                          onSelected: (_) =>
                              setSheetState(() => selectedTable = t),
                          selectedColor: const Color(0xFFE94560),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontWeight:
                                sel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final category in ['Makanan', 'Minuman']) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(category,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        for (final item in defaultMenu
                            .where((m) => m.category == category))
                          _menuTile(item, cart, setSheetState),
                      ],
                    ],
                  ),
                ),
                if (cart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: FilledButton(
                        onPressed: () {
                          _createKasirOrder(cart, selectedTable);
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE94560),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Buat Order  •  $totalItems item  •  ${formatRupiah(totalPrice)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _menuTile(
      MenuItem item, Map<String, int> cart, StateSetter setSheetState) {
    final qty = cart[item.id] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(formatRupiah(item.price),
            style: const TextStyle(color: Color(0xFFE94560), fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qty > 0)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 22),
                onPressed: () => setSheetState(() {
                  if (qty <= 1) {
                    cart.remove(item.id);
                  } else {
                    cart[item.id] = qty - 1;
                  }
                }),
                color: Colors.red,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (qty > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$qty',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            IconButton(
              icon: const Icon(Icons.add_circle, size: 22),
              onPressed: () =>
                  setSheetState(() => cart[item.id] = qty + 1),
              color: const Color(0xFF0F3460),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _createKasirOrder(Map<String, int> cart, int tableNumber) {
    if (cart.isEmpty) return;

    _kasirOrderCounter++;
    final orderId =
        'KS${_kasirOrderCounter.toString().padLeft(3, '0')}';

    final items = <OrderItem>[];
    cart.forEach((id, qty) {
      final menuItem = defaultMenu.firstWhere((m) => m.id == id);
      items.add(OrderItem(menuItem: menuItem, quantity: qty));
    });

    final order = Order(
      id: orderId,
      tableNumber: tableNumber,
      items: items,
      waiterName: 'Kasir',
      status: OrderStatus.processing,
    );

    setState(() => _orders.insert(0, order));

    _server.broadcast({
      'type': 'order_status_update',
      'orderId': order.id,
      'status': OrderStatus.processing.name,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #$orderId dibuat (Meja $tableNumber)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showReceipt(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.green),
            SizedBox(width: 8),
            Text('Struk Pembayaran'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('POS RESTO',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Center(
                child: Text(
                    '${order.paidAt!.day}/${order.paidAt!.month}/${order.paidAt!.year} ${order.paidAt!.hour}:${order.paidAt!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12))),
            const Divider(height: 20),
            Text('No: #${order.id}  |  Meja ${order.tableNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Waiter: ${order.waiterName}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const Divider(height: 20),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('${item.quantity}x '),
                      Expanded(child: Text(item.menuItem.name)),
                      Text(formatRupiah(item.subtotal)),
                    ],
                  ),
                )),
            const Divider(height: 20),
            _receiptRow('Subtotal', formatRupiah(order.total)),
            _receiptRow('Bayar', formatRupiah(order.paidAmount), bold: true),
            _receiptRow('Kembali', formatRupiah(order.changeAmount),
                bold: true),
            const SizedBox(height: 12),
            const Center(
              child: Text('— Terima Kasih —',
                  style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Kasir',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE94560),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _server.running ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _server.running
                      ? '${_server.clientCount} device'
                      : 'Offline',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Masuk (${_pendingOrders.length})'),
            Tab(text: 'Proses (${_processingOrders.length})'),
            Tab(text: 'Bayar (${_readyOrders.length})'),
            Tab(
                icon: const Icon(Icons.bar_chart, size: 18),
                text: 'Laporan'),
          ],
        ),
      ),
      body: Column(
        children: [
          _serverInfoBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(_pendingOrders, OrderStatus.pending),
                _buildOrderList(_processingOrders, OrderStatus.processing),
                _buildOrderList(_readyOrders, OrderStatus.ready),
                _buildReportView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewOrderSheet,
        backgroundColor: const Color(0xFFE94560),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Order Baru',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _serverInfoBar() {
    if (!_server.running) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.orange[100],
        child: const Text('Starting server...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.green[50],
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Server aktif  •  IP: ${_server.localIp}:8080',
              style: TextStyle(color: Colors.green[800], fontSize: 13),
            ),
          ),
          Text('${_server.clientCount} waiter',
              style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Report ──────────────────────────────────────────

  Widget _buildReportView() {
    final paid = _paidOrders;
    final totalRevenue = paid.fold(0, (sum, o) => sum + o.total);
    final totalOrders = paid.length;
    final cancelled =
        _orders.where((o) => o.status == OrderStatus.cancelled).length;

    final Map<String, int> itemSales = {};
    final Map<String, int> itemQty = {};
    for (final order in paid) {
      for (final item in order.items) {
        itemSales[item.menuItem.name] =
            (itemSales[item.menuItem.name] ?? 0) + item.subtotal;
        itemQty[item.menuItem.name] =
            (itemQty[item.menuItem.name] ?? 0) + item.quantity;
      }
    }
    final sortedItems = itemSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _summaryCard('Total Penjualan', formatRupiah(totalRevenue),
                Icons.account_balance_wallet, Colors.green),
            const SizedBox(width: 12),
            _summaryCard('Transaksi', '$totalOrders',
                Icons.receipt, Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _summaryCard(
                'Rata-rata',
                totalOrders > 0
                    ? formatRupiah(totalRevenue ~/ totalOrders)
                    : 'Rp 0',
                Icons.trending_up,
                Colors.orange),
            const SizedBox(width: 12),
            _summaryCard(
                'Dibatalkan', '$cancelled', Icons.cancel, Colors.red),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Menu Terlaris',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (sortedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Belum ada transaksi',
                  style: TextStyle(color: Colors.grey[400])),
            ),
          ),
        ...sortedItems.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE94560).withValues(alpha: 0.1),
                  child: Text('${itemQty[entry.key]}x',
                      style: const TextStyle(
                          color: Color(0xFFE94560),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                title: Text(entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(formatRupiah(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )),
        const SizedBox(height: 20),
        const Text('Riwayat Transaksi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...paid.map((order) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _showReceipt(order),
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  child: Text('${order.tableNumber}',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                ),
                title: Text('#${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${order.waiterName} • ${order.items.length} item'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatRupiah(order.total),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (order.paidAt != null)
                      Text(
                          '${order.paidAt!.hour}:${order.paidAt!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
            )),
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
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ─── Order list ──────────────────────────────────────

  Widget _buildOrderList(List<Order> orders, OrderStatus? currentStatus) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Belum ada order',
                style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _buildOrderCard(orders[index], currentStatus),
    );
  }

  Widget _buildOrderCard(Order order, OrderStatus? currentStatus) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE94560),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Meja ${order.tableNumber}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('#${order.id}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const Spacer(),
                _statusBadge(order.status),
              ],
            ),
            const Divider(height: 20),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('${item.quantity}x ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(item.menuItem.name)),
                      Text(formatRupiah(item.subtotal),
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(order.waiterName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const Spacer(),
                Text('Total: ${formatRupiah(order.total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            if (currentStatus != null) ...[
              const SizedBox(height: 12),
              Row(children: _actionButtons(order, currentStatus)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actionButtons(Order order, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _updateStatus(order, OrderStatus.cancelled),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Tolak'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _updateStatus(order, OrderStatus.processing),
              icon: const Icon(Icons.local_fire_department, size: 18),
              label: const Text('Proses'),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange[700]),
            ),
          ),
        ];
      case OrderStatus.processing:
        return [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _updateStatus(order, OrderStatus.ready),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Siap Antar'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
        ];
      case OrderStatus.ready:
        return [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showPaymentDialog(order),
              icon: const Icon(Icons.payments, size: 18),
              label: const Text('Bayar Tunai'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3460)),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _statusBadge(OrderStatus status) {
    final (String label, Color color) = switch (status) {
      OrderStatus.pending => ('Masuk', Colors.blue),
      OrderStatus.processing => ('Diproses', Colors.orange),
      OrderStatus.ready => ('Siap', Colors.green),
      OrderStatus.completed => ('Lunas', Colors.teal),
      OrderStatus.cancelled => ('Batal', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
