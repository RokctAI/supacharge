import 'dart:convert';

class RepeatData {
  String? id;
  String? orderId;
  String? from;
  String? to;
  String? createdAt;
  String? updatedAt;
  int? isActive;
  String? paymentMethod;
  String? savedCard;

  RepeatData({
    this.id,
    this.orderId,
    this.from,
    this.to,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.paymentMethod,
    this.savedCard,
  });

  RepeatData copyWith({
    String? id,
    String? orderId,
    String? from,
    String? to,
    String? createdAt,
    String? updatedAt,
    int? isActive,
    String? paymentMethod,
    String? savedCard,
  }) =>
      RepeatData(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        from: from ?? this.from,
        to: to ?? this.to,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isActive: isActive ?? this.isActive,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        savedCard: savedCard ?? this.savedCard,
      );

  factory RepeatData.fromRawJson(String str) =>
      RepeatData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory RepeatData.fromJson(Map<String, dynamic> json) => RepeatData(
        id: json["id"]?.toString(),
        orderId: json["order_id"]?.toString(),
        from: json["from"],
        to: json["to"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        isActive: json["is_active"],
        paymentMethod: json["payment_method"],
        savedCard: json["saved_card"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "order_id": orderId,
        "from": from,
        "to": to,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "is_active": isActive,
        "payment_method": paymentMethod,
        "saved_card": savedCard,
      };
}
