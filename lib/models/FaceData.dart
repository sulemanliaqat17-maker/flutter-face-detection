import 'dart:typed_data';

class FaceData {
  FaceData({
    int? id,
    String? name,
    String? embedding,
    int? faceHeight,
    int? faceWidth,
    Uint8List? faceBytes,
  }) {
    _id = id;
    _name = name;
    _embedding = embedding;
    _faceHeight = faceHeight;
    _faceWidth = faceWidth;
    _faceBytes = faceBytes;
  }

  FaceData.fromDb({
    int? id,
    String? name,
    String? embedding,
    int? faceHeight,
    int? faceWidth,
    Uint8List? faceBytes,
  }) {
    _id = id;
    _name = name;
    _embedding = embedding;
    _faceHeight = faceHeight;
    _faceWidth = faceWidth;
    _faceBytes = faceBytes;
  }

  FaceData.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
    _embedding = json['embedding'];
    _faceHeight = json['faceHeight'];
    _faceWidth = json['faceWidth'];
    _faceBytes = json['faceBytes'];
  }
  int? _id;
  String? _name;
  String? _embedding;
  int? _faceHeight;
  int? _faceWidth;
  Uint8List? _faceBytes;

  int? get id => _id;
  String? get name => _name;
  String? get embedding => _embedding;
  int? get faceHeight => _faceHeight;
  int? get faceWidth => _faceWidth;
  Uint8List? get faceBytes => _faceBytes;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    map['embedding'] = _embedding;
    map['faceHeight'] = _faceHeight;
    map['faceWidth'] = _faceWidth;
    map['faceBytes'] = _faceBytes;
    return map;
  }
}
