// models/terminal.dart
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Terminal {
  final String name;
  final String iconImage;
  final List<LatLng> points;
  List<Route> routes; // Make routes mutable

  Terminal({
    required this.name,
    required this.iconImage,
    required this.points,
    required this.routes,
  });

  // Factory constructor to create a Terminal from Firestore data
  factory Terminal.fromFirestore(Map<String, dynamic> data) {
    var pointsData = data['points'];
    return Terminal(
      name: data['name'] ?? 'Unnamed',
      iconImage: data['iconImage'] ?? '',
      points: (pointsData is List && pointsData.isNotEmpty)
          ? pointsData.map((point) {
              if (point is GeoPoint) {
                return LatLng(point.latitude, point.longitude);
              } else {
                throw ArgumentError('Expected GeoPoint, but got ${point.runtimeType}');
              }
            }).toList()
          : [],
      routes: [], // Initialize with an empty list, will be filled later
    );
  }
}


class Route {
  final String name;
  final List<LatLng> points;
  final String color;

  Route({
    required this.name,
    required this.points,
    required this.color,
  });

  // Factory constructor to create a Route from a Map
  factory Route.fromMap(Map<String, dynamic> data) {
  var pointsData = data['points'];

  return Route(
    name: data['name'] ?? 'Unnamed',
    points: (pointsData is List && pointsData.isNotEmpty)
        ? pointsData.map((point) {
            if (point is GeoPoint) {
              return LatLng(point.latitude, point.longitude);
            } else {
              throw ArgumentError('Expected GeoPoint, but got ${point.runtimeType}');
            }
          }).toList()
        : [],
    color: data['color'] ?? '',
  );
}

}
