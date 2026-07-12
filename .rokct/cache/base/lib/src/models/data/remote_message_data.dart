class RemoteMessageData {
  final String? id;
  final String? status;
  final String? type;

  RemoteMessageData({this.id, this.status, this.type});

  factory RemoteMessageData.fromJson(Map data) {
    return RemoteMessageData(
      id: data["id"]?.toString(),
      status: data["status"],
      type: data["type"],
    );
  }
}
