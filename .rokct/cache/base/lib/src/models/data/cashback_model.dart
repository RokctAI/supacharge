class CashbackModel {
  CashbackModel({this.price});

  CashbackModel.fromJson(dynamic json) {
    price = json['price'];
  }

  num? price;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['price'] = price;
    return map;
  }
}
