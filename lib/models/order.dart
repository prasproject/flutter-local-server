import 'menu_item.dart';

enum OrderStatus { pending, processing, ready, completed, cancelled }

class OrderItem {
  final MenuItem menuItem;
  int quantity;

  OrderItem({required this.menuItem, this.quantity = 1});

  int get subtotal => menuItem.price * quantity;

  Map<String, dynamic> toJson() => {
        'menuItem': menuItem.toJson(),
        'quantity': quantity,
        'subtotal': subtotal,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        menuItem: MenuItem.fromJson(json['menuItem'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
      );
}

class Order {
  final String id;
  final int tableNumber;
  final List<OrderItem> items;
  final DateTime createdAt;
  OrderStatus status;
  final String waiterName;

  int paidAmount;
  int changeAmount;
  DateTime? paidAt;

  Order({
    required this.id,
    required this.tableNumber,
    required this.items,
    required this.waiterName,
    DateTime? createdAt,
    this.status = OrderStatus.pending,
    this.paidAmount = 0,
    this.changeAmount = 0,
    this.paidAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get total => items.fold(0, (sum, item) => sum + item.subtotal);
  bool get isPaid => status == OrderStatus.completed && paidAmount > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableNumber': tableNumber,
        'items': items.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'waiterName': waiterName,
        'total': total,
        'paidAmount': paidAmount,
        'changeAmount': changeAmount,
        'paidAt': paidAt?.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        tableNumber: json['tableNumber'] as int,
        items: (json['items'] as List)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: OrderStatus.values.byName(json['status'] as String),
        waiterName: json['waiterName'] as String,
        paidAmount: json['paidAmount'] as int? ?? 0,
        changeAmount: json['changeAmount'] as int? ?? 0,
        paidAt: json['paidAt'] != null
            ? DateTime.parse(json['paidAt'] as String)
            : null,
      );
}

String formatRupiah(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return 'Rp $buffer';
}
