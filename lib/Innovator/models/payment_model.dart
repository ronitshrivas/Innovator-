class PaymentModel {
  final String name;
  final bool active;
final  bool cod;
  final String qrImage;
  PaymentModel({
     required this.name,
   required this.active,
   required this.cod,
    required this.qrImage
  });
  factory PaymentModel.fromJson(Map<String,dynamic> json){
     return PaymentModel(name: json['name']??'', active: json['active']??false, cod: json['code']??false, qrImage: json['qrImage']);
  }
  Map<String,dynamic> toJson(){
     return{
      'name':name,
      'active':active,
      'cod':cod,
      'qrImage':qrImage
     };
  }
}