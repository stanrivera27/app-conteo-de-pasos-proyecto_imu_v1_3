import 'dart:math';

class POI {
  final Point<int> cell; //posicion del POI
  final String name; //nombre del POI
  final String description;//descripcion del POI

  POI({
    required this.cell,
    required this.name,
    required this.description,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      cell: Point(json['x'], json['y']),
      name: json['name'],
      description: json['description'],
    );
  }
}

