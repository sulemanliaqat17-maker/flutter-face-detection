class FaceData {
  FaceData({
    int? id,
    String? name,
    String? embedding,
  }) {
    _id = id;
    _name = name;
    _embedding = embedding;
  }

  FaceData.fromDb({
    int? id,
    String? name,
    String? embedding,
  }) {
    _id = id;
    _name = name;
    _embedding = embedding;
  }

  FaceData.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
    _embedding = json['embedding'];
  }
  int? _id;
  String? _name;
  String? _embedding;

  int? get id => _id;
  String? get name => _name;
  String? get embedding => _embedding;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    map['embedding'] = _embedding;
    return map;
  }
}
