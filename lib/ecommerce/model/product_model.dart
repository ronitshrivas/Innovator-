// class ProductModel {
//   final String id;
//   final String name;
//   final String? description;
//   final String price;
//   final int stock; 
//   final String? category;
//   final dynamic categoryDetails;
  
//   final List<dynamic> images;

//   ProductModel({
//     required this.id,
//     required this.name,
//     this.description,
//     required this.price,
//     required this.stock, 
//     this.category,
//     this.categoryDetails, 
//     required this.images,
//   });

//   factory ProductModel.fromJson(Map<String, dynamic> json) {
//     return ProductModel(
//       id: json['id'] as String,
//       name: json['name'] as String,
//       description: json['description'] as String?,
//       price: json['price'] as String,
//       stock: json['stock'] as int, 
//       category: json['category'] as String?,
//       categoryDetails: json['category_details'], 
//       images: json['images'] as List<dynamic>,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'name': name,
//       'description': description,
//       'price': price,
//       'stock': stock, 
//       'category': category,
//       'category_details': categoryDetails, 
//       'images': images,
//     };
//   }
 
//   static List<ProductModel> fromJsonList(List<dynamic> jsonList) {
//     return jsonList
//         .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
//         .toList();
//   }

//   @override
//   String toString() {
//     return 'ProductModel(id: $id, name: $name, price: $price, stock: $stock)';
//   }
// }


class ProductModel {
  final String id;
  final String name;
  final String? description;
  final String price;
  final int stock;
  final bool isActive;
  final String? category;
  final dynamic categoryDetails;
  final String? image; 

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.isActive = true,
    this.category,
    this.categoryDetails,
    this.image,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: json['price'] as String,
      stock: json['stock'] as int,
      isActive: json['is_active'] as bool? ?? true,
      category: json['category'] as String?,
      categoryDetails: json['category_details'],
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'is_active': isActive,
      'category': category,
      'category_details': categoryDetails,
      'image': image,
    };
  }

  static List<ProductModel> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, price: $price, stock: $stock)';
  }
}