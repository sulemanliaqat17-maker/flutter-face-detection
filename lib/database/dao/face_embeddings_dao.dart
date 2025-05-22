import 'package:drift/drift.dart';
import 'package:face_detection_app/database/my_database.dart';
import 'package:face_detection_app/models/FaceData.dart';
import 'package:face_detection_app/utils/utils.dart';

import '../tables/face_embeddings_table.dart';

part 'face_embeddings_dao.g.dart';

@DriftAccessor(tables: [FaceEmbeddingsTable])
class FaceEmbeddingsDao extends DatabaseAccessor<MyDatabase>
    with _$FaceEmbeddingsDaoMixin
    implements IFaceEmbeddingsTableTable {
  FaceEmbeddingsDao(super.db);

  @override
  Future<void> deleteAll() {
    return (delete(faceEmbeddingsTable)).go();
  }

  // Insert face data
  @override
  Future<int> insertFace(String name, List<double> embedding) async {
    return into(faceEmbeddingsTable).insert(FaceEmbeddingsTableCompanion(
      name: Value(name),
      embedding: Value(Utils.embeddingToString(embedding)),
    ));
  }

  // Get all faces
  @override
  Future<List<FaceData>> getAllFaces() => select(faceEmbeddingsTable).get();

  // Delete a face
  @override
  Future<int> deleteFace(int id) =>
      (delete(faceEmbeddingsTable)..where((tbl) => tbl.id.equals(id))).go();

  // Update face embedding
  @override
  Future<int> updateFace(int id, List<double> newEmbedding) async {
    return (update(faceEmbeddingsTable)..where((tbl) => tbl.id.equals(id)))
        .write(FaceEmbeddingsTableCompanion(
      embedding: Value(Utils.embeddingToString(newEmbedding)),
    ));
  }
}

abstract class IFaceEmbeddingsTableTable {
  Future<int> insertFace(String name, List<double> embedding);
  Future<List<FaceData>> getAllFaces();
  Future<int> deleteFace(int id);
  Future<int> updateFace(int id, List<double> newEmbedding);
  Future<void> deleteAll();
}
