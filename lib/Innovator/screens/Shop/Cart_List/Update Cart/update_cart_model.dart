class UpdateCartModel {
  final String product;
  final String quantity;
  UpdateCartModel({required this.product,required this.quantity});
  factory UpdateCartModel.fromJson(Map<String,dynamic> json) {
     return UpdateCartModel(product: json['product']??"", quantity: json['quantity']??"");
  }
  Map<String,dynamic> toJson(){
     return {
      'product':product,
      'quantity':quantity
     };
  }
}