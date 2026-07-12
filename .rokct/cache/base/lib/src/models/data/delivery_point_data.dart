import 'dart:convert';

DeliveryPointData deliveryPointDataFromJson(String str) =>
    DeliveryPointData.fromJson(json.decode(str));

String deliveryPointDataToJson(DeliveryPointData data) =>
    json.encode(data.toJson());

class DeliveryPointData {
  String? id;
  String? name;
  String? address;
  double? latitude;
  double? longitude;
  String? img;
  double? distance;

  DeliveryPointData({
    this.id,
    this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.img,
    this.distance,
  });

  factory DeliveryPointData.fromJson(Map<String, dynamic> json) =>
      DeliveryPointData(
        id: json["name"],
        name: json["name"],
        address: json["address"],
        latitude: (json["latitude"] as num?)?.toDouble(),
        longitude: (json["longitude"] as num?)?.toDouble(),
        img: json["img"],
        distance: (json["distance"] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "address": address,
        "latitude": latitude,
        "longitude": longitude,
        "img": img,
        "distance": distance,
      };
}
