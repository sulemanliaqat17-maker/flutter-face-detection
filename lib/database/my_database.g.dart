// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_database.dart';

// ignore_for_file: type=lint
class $FaceEmbeddingsTableTable extends FaceEmbeddingsTable
    with TableInfo<$FaceEmbeddingsTableTable, FaceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FaceEmbeddingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _faceHeightMeta =
      const VerificationMeta('faceHeight');
  @override
  late final GeneratedColumn<int> faceHeight = GeneratedColumn<int>(
      'face_height', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _faceWidthMeta =
      const VerificationMeta('faceWidth');
  @override
  late final GeneratedColumn<int> faceWidth = GeneratedColumn<int>(
      'face_width', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _faceBytesMeta =
      const VerificationMeta('faceBytes');
  @override
  late final GeneratedColumn<Uint8List> faceBytes = GeneratedColumn<Uint8List>(
      'face_bytes', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _embeddingMeta =
      const VerificationMeta('embedding');
  @override
  late final GeneratedColumn<String> embedding = GeneratedColumn<String>(
      'embedding', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, faceHeight, faceWidth, faceBytes, embedding];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'face_embeddings_table';
  @override
  VerificationContext validateIntegrity(Insertable<FaceData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('face_height')) {
      context.handle(
          _faceHeightMeta,
          faceHeight.isAcceptableOrUnknown(
              data['face_height']!, _faceHeightMeta));
    } else if (isInserting) {
      context.missing(_faceHeightMeta);
    }
    if (data.containsKey('face_width')) {
      context.handle(_faceWidthMeta,
          faceWidth.isAcceptableOrUnknown(data['face_width']!, _faceWidthMeta));
    } else if (isInserting) {
      context.missing(_faceWidthMeta);
    }
    if (data.containsKey('face_bytes')) {
      context.handle(_faceBytesMeta,
          faceBytes.isAcceptableOrUnknown(data['face_bytes']!, _faceBytesMeta));
    } else if (isInserting) {
      context.missing(_faceBytesMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(_embeddingMeta,
          embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta));
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FaceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FaceData.fromDb(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      embedding: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}embedding'])!,
      faceHeight: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}face_height'])!,
      faceWidth: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}face_width'])!,
      faceBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}face_bytes'])!,
    );
  }

  @override
  $FaceEmbeddingsTableTable createAlias(String alias) {
    return $FaceEmbeddingsTableTable(attachedDatabase, alias);
  }
}

class FaceEmbeddingsTableCompanion extends UpdateCompanion<FaceData> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> faceHeight;
  final Value<int> faceWidth;
  final Value<Uint8List> faceBytes;
  final Value<String> embedding;
  const FaceEmbeddingsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.faceHeight = const Value.absent(),
    this.faceWidth = const Value.absent(),
    this.faceBytes = const Value.absent(),
    this.embedding = const Value.absent(),
  });
  FaceEmbeddingsTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int faceHeight,
    required int faceWidth,
    required Uint8List faceBytes,
    required String embedding,
  })  : name = Value(name),
        faceHeight = Value(faceHeight),
        faceWidth = Value(faceWidth),
        faceBytes = Value(faceBytes),
        embedding = Value(embedding);
  static Insertable<FaceData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? faceHeight,
    Expression<int>? faceWidth,
    Expression<Uint8List>? faceBytes,
    Expression<String>? embedding,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (faceHeight != null) 'face_height': faceHeight,
      if (faceWidth != null) 'face_width': faceWidth,
      if (faceBytes != null) 'face_bytes': faceBytes,
      if (embedding != null) 'embedding': embedding,
    });
  }

  FaceEmbeddingsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<int>? faceHeight,
      Value<int>? faceWidth,
      Value<Uint8List>? faceBytes,
      Value<String>? embedding}) {
    return FaceEmbeddingsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      faceHeight: faceHeight ?? this.faceHeight,
      faceWidth: faceWidth ?? this.faceWidth,
      faceBytes: faceBytes ?? this.faceBytes,
      embedding: embedding ?? this.embedding,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (faceHeight.present) {
      map['face_height'] = Variable<int>(faceHeight.value);
    }
    if (faceWidth.present) {
      map['face_width'] = Variable<int>(faceWidth.value);
    }
    if (faceBytes.present) {
      map['face_bytes'] = Variable<Uint8List>(faceBytes.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<String>(embedding.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FaceEmbeddingsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('faceHeight: $faceHeight, ')
          ..write('faceWidth: $faceWidth, ')
          ..write('faceBytes: $faceBytes, ')
          ..write('embedding: $embedding')
          ..write(')'))
        .toString();
  }
}

abstract class _$MyDatabase extends GeneratedDatabase {
  _$MyDatabase(QueryExecutor e) : super(e);
  $MyDatabaseManager get managers => $MyDatabaseManager(this);
  late final $FaceEmbeddingsTableTable faceEmbeddingsTable =
      $FaceEmbeddingsTableTable(this);
  late final FaceEmbeddingsDao faceEmbeddingsDao =
      FaceEmbeddingsDao(this as MyDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [faceEmbeddingsTable];
}

typedef $$FaceEmbeddingsTableTableCreateCompanionBuilder
    = FaceEmbeddingsTableCompanion Function({
  Value<int> id,
  required String name,
  required int faceHeight,
  required int faceWidth,
  required Uint8List faceBytes,
  required String embedding,
});
typedef $$FaceEmbeddingsTableTableUpdateCompanionBuilder
    = FaceEmbeddingsTableCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> faceHeight,
  Value<int> faceWidth,
  Value<Uint8List> faceBytes,
  Value<String> embedding,
});

class $$FaceEmbeddingsTableTableTableManager extends RootTableManager<
    _$MyDatabase,
    $FaceEmbeddingsTableTable,
    FaceData,
    $$FaceEmbeddingsTableTableFilterComposer,
    $$FaceEmbeddingsTableTableOrderingComposer,
    $$FaceEmbeddingsTableTableCreateCompanionBuilder,
    $$FaceEmbeddingsTableTableUpdateCompanionBuilder> {
  $$FaceEmbeddingsTableTableTableManager(
      _$MyDatabase db, $FaceEmbeddingsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$FaceEmbeddingsTableTableFilterComposer(
              ComposerState(db, table)),
          orderingComposer: $$FaceEmbeddingsTableTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> faceHeight = const Value.absent(),
            Value<int> faceWidth = const Value.absent(),
            Value<Uint8List> faceBytes = const Value.absent(),
            Value<String> embedding = const Value.absent(),
          }) =>
              FaceEmbeddingsTableCompanion(
            id: id,
            name: name,
            faceHeight: faceHeight,
            faceWidth: faceWidth,
            faceBytes: faceBytes,
            embedding: embedding,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required int faceHeight,
            required int faceWidth,
            required Uint8List faceBytes,
            required String embedding,
          }) =>
              FaceEmbeddingsTableCompanion.insert(
            id: id,
            name: name,
            faceHeight: faceHeight,
            faceWidth: faceWidth,
            faceBytes: faceBytes,
            embedding: embedding,
          ),
        ));
}

class $$FaceEmbeddingsTableTableFilterComposer
    extends FilterComposer<_$MyDatabase, $FaceEmbeddingsTableTable> {
  $$FaceEmbeddingsTableTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get faceHeight => $state.composableBuilder(
      column: $state.table.faceHeight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get faceWidth => $state.composableBuilder(
      column: $state.table.faceWidth,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<Uint8List> get faceBytes => $state.composableBuilder(
      column: $state.table.faceBytes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get embedding => $state.composableBuilder(
      column: $state.table.embedding,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$FaceEmbeddingsTableTableOrderingComposer
    extends OrderingComposer<_$MyDatabase, $FaceEmbeddingsTableTable> {
  $$FaceEmbeddingsTableTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get faceHeight => $state.composableBuilder(
      column: $state.table.faceHeight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get faceWidth => $state.composableBuilder(
      column: $state.table.faceWidth,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<Uint8List> get faceBytes => $state.composableBuilder(
      column: $state.table.faceBytes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get embedding => $state.composableBuilder(
      column: $state.table.embedding,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $MyDatabaseManager {
  final _$MyDatabase _db;
  $MyDatabaseManager(this._db);
  $$FaceEmbeddingsTableTableTableManager get faceEmbeddingsTable =>
      $$FaceEmbeddingsTableTableTableManager(_db, _db.faceEmbeddingsTable);
}
