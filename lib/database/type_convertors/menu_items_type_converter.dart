// import 'dart:convert';
//
// import 'package:drift/drift.dart';
// import 'package:paf_skyview/models/sync/MenuItemCategories.dart';
//
// class MenuCategoriesTypeConvertor
//     extends TypeConverter<List<MenuItemCategories>?, String?> {
//   @override
//   List<MenuItemCategories>? fromSql(String? fromDb) {
//     if (fromDb == null) {
//       return null;
//     }
//     final jsonFile = json.decode(fromDb) as List<dynamic>;
//     List<MenuItemCategories> menuCategories = [];
//     for (dynamic item in jsonFile) {
//       menuCategories.add(MenuItemCategories.fromJson(item));
//     }
//     return menuCategories;
//   }
//
//   @override
//   String? toSql(List<MenuItemCategories>? value) {
//     if (value == null) {
//       return null;
//     }
//     List<dynamic> data = [];
//     for (MenuItemCategories item in value) {
//       data.add(item.toJson());
//     }
//
//     return json.encode(data);
//   }
// }
