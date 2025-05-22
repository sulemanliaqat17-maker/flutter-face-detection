import 'package:drift/drift.dart';
import 'package:face_detection_app/models/FaceData.dart';

@UseRowClass(FaceData, constructor: "fromDb")
class FaceEmbeddingsTable extends Table {
  IntColumn get id => integer().autoIncrement()(); // Unique ID
  TextColumn get name => text()(); // Face name or label
  TextColumn get embedding => text()(); // Embedding as a binary blob
}
