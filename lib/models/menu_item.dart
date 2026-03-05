class MenuItem {
  final String id;
  final String name;
  final int price;
  final String category;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category': category,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        price: json['price'] as int,
        category: json['category'] as String,
      );
}

const List<MenuItem> defaultMenu = [
  MenuItem(id: 'MK01', name: 'Nasi Goreng', price: 25000, category: 'Makanan'),
  MenuItem(id: 'MK02', name: 'Mie Goreng', price: 22000, category: 'Makanan'),
  MenuItem(id: 'MK03', name: 'Ayam Bakar', price: 30000, category: 'Makanan'),
  MenuItem(id: 'MK04', name: 'Ayam Geprek', price: 20000, category: 'Makanan'),
  MenuItem(id: 'MK05', name: 'Nasi Campur', price: 28000, category: 'Makanan'),
  MenuItem(id: 'MN01', name: 'Es Teh Manis', price: 5000, category: 'Minuman'),
  MenuItem(id: 'MN02', name: 'Es Jeruk', price: 8000, category: 'Minuman'),
  MenuItem(id: 'MN03', name: 'Kopi Hitam', price: 8000, category: 'Minuman'),
  MenuItem(id: 'MN04', name: 'Jus Alpukat', price: 15000, category: 'Minuman'),
  MenuItem(id: 'MN05', name: 'Air Mineral', price: 4000, category: 'Minuman'),
];
