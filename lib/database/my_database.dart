import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:face_detection_app/database/dao/face_embeddings_dao.dart';
import 'package:face_detection_app/database/tables/face_embeddings_table.dart';
import 'package:face_detection_app/models/FaceData.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'my_database.g.dart';

@DriftDatabase(tables: [FaceEmbeddingsTable], daos: [FaceEmbeddingsDao])
// abstract class MyDatabase extends FloorDatabase {
//   DistrictDao get districtDao;
// }

class MyDatabase extends _$MyDatabase {
  // we tell the database where to store the data with this constructor
  MyDatabase() : super(_openConnection());

  //flutter packages pub run build_runner build --delete-conflicting-outputs
  // you should bump this number whenever you change or add a table definition.
  // Migrations are covered later in the documentation.
  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
