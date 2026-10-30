import 'dart:convert';

import 'package:flutter/painting.dart';

String normalizeRoomQuery(String value) => value
    .replaceAll(RegExp('[Сс]'), 'C')
    .replaceAll(RegExp(r'\s+'), '')
    .toUpperCase();

class MapRoom {
  MapRoom(this.number, this.outline);

  final String number;
  final List<Offset> outline;

  String get building => number.split('.')[0];
  int get block => int.parse(number.split('.')[1]);
  int get floor => int.parse(number.split('.')[2][0]);
  String get room => number.split('.')[2].substring(1);

  Rect get bounds {
    final xs = outline.map((point) => point.dx);
    final ys = outline.map((point) => point.dy);
    return Rect.fromLTRB(
      xs.reduce((a, b) => a < b ? a : b),
      ys.reduce((a, b) => a < b ? a : b),
      xs.reduce((a, b) => a > b ? a : b),
      ys.reduce((a, b) => a > b ? a : b),
    );
  }

  bool contains(Offset point) {
    var inside = false;
    for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
      final a = outline[i];
      final b = outline[j];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }
}

class MapFloor {
  MapFloor(
    this.building,
    this.block,
    this.floor,
    this.width,
    this.height,
    this.footprint,
    this.rooms,
    this.stairs,
  );

  final String building;
  final int block;
  final int floor;
  final double width;
  final double height;
  final List<Offset> footprint;
  final List<MapRoom> rooms;
  final List<List<Offset>> stairs;
}

class MapCatalog {
  MapCatalog(this.floors);

  final List<MapFloor> floors;

  factory MapCatalog.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    return MapCatalog(
      (data['floors'] as List<dynamic>).map((item) {
        final value = item as Map<String, dynamic>;
        List<Offset> outline(dynamic points) => (points as List<dynamic>)
            .map(
              (point) => Offset(
                ((point as List<dynamic>)[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              ),
            )
            .toList();
        return MapFloor(
          value['building'] as String,
          value['block'] as int,
          value['floor'] as int,
          (value['width'] as num).toDouble(),
          (value['height'] as num).toDouble(),
          outline(value['footprint']),
          (value['rooms'] as List<dynamic>)
              .map(
                (room) => MapRoom(
                  (room as Map<String, dynamic>)['number'] as String,
                  outline(room['outline']),
                ),
              )
              .toList(),
          (value['stairs'] as List<dynamic>).map(outline).toList(),
        );
      }).toList(),
    );
  }

  Iterable<String> get buildings =>
      floors.map((floor) => floor.building).toSet();

  List<int> blocksFor(String building) =>
      floors
          .where((floor) => floor.building == building)
          .map((floor) => floor.block)
          .toSet()
          .toList()
        ..sort();

  List<int> floorsFor(String building, int block) =>
      floors
          .where((floor) => floor.building == building && floor.block == block)
          .map((floor) => floor.floor)
          .toSet()
          .toList()
        ..sort();

  MapFloor plan(String building, int block, int floor) => floors.firstWhere(
    (value) =>
        value.building == building &&
        value.block == block &&
        value.floor == floor,
  );

  MapRoom? exact(String query) {
    final normalized = normalizeRoomQuery(query);
    for (final floor in floors) {
      for (final room in floor.rooms) {
        if (room.number == normalized) return room;
      }
    }
    return null;
  }

  List<MapRoom> search(String query, {int limit = 8}) {
    final normalized = normalizeRoomQuery(query);
    if (normalized.isEmpty) return [];
    final matches = <String, MapRoom>{};
    for (final floor in floors) {
      for (final room in floor.rooms) {
        if (room.number.contains(normalized)) {
          matches.putIfAbsent(room.number, () => room);
        }
      }
    }
    final sorted = matches.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return sorted.take(limit).toList();
  }
}
