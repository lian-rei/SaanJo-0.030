import 'dart:convert';
import 'dart:math';

import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
class Terminal {
  final String name;
  final String iconImage;
  final List<LatLng> points;
  final LatLng landmarkCoordinates; 
  List<Route> routes; // Make routes mutable

  Terminal({
    required this.name,
    required this.iconImage,
    required this.points,
    required this.routes,
    required this.landmarkCoordinates,
  });

  // Factory constructor to create a Terminal from Firestore data
  factory Terminal.fromFirestore(Map<String, dynamic> data) {
    var pointsData = data['points'] ?? [];
    var routesData = data['routes'] ?? [];
    var landmarkSpecificData = data ['landmarkCoordinates'] ?? {'latitude': 0.0, 'longitude': 0.0};

    return Terminal(
      name: data['name'] ?? 'Unnamed Terminal',
      iconImage: data['iconImage'] ?? '',
      points: (pointsData is List && pointsData.isNotEmpty)
          ? pointsData.map((point) {
              if (point is GeoPoint) {
                return LatLng(point.latitude, point.longitude);
              }
              return LatLng(0, 0); // Fallback for invalid point
            }).toList()
          : [],
      landmarkCoordinates: LatLng(
        landmarkSpecificData['latitude'] ?? 0.0,
        landmarkSpecificData['longitude'] ?? 0.0,
      ),
      routes: (routesData is List)
          ? routesData.map((routeData) => Route.fromFirestore(routeData)).toList()
          : [],
    );
  }

  Future<Map<String, dynamic>?> fetchPlaceDetails(String accessToken, {double? latitude, double? longitude}) async {
    // Use provided latitude and longitude or default to the first point
    final LatLng location = (latitude != null && longitude != null)
        ? LatLng(latitude, longitude)
        : points.isNotEmpty ? points.first : LatLng(0, 0); // Fallback

    final String url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitude},${location.latitude}.json?access_token=$accessToken';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['features'].isNotEmpty ? data['features'][0] : null;
    } else {
      throw Exception('Failed to load place details');
    }
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

  // Factory constructor to create a Route from Firestore data
  factory Route.fromFirestore(Map<String, dynamic> data) {
    var pointsData = data['points'] ?? [];
    var color = data['color'] ?? '#000000'; // Default to black if color is not provided

    return Route(
      name: data['name'] ?? 'Unnamed Route',
      points: (pointsData is List && pointsData.isNotEmpty)
          ? pointsData.map((point) {
              if (point is GeoPoint) {
                return LatLng(point.latitude, point.longitude);
              }
              return LatLng(0, 0); // Fallback for invalid point
            }).toList()
          : [],
      color: color,
    );
  }

  // Add fromMap method to handle generic Map<String, dynamic> input
  factory Route.fromMap(Map<String, dynamic> data) {
    var pointsData = data['points'] ?? [];
    var color = data['color'] ?? '#000000'; // Default to black if color is not provided

    return Route(
      name: data['name'] ?? 'Unnamed Route',
      points: (pointsData is List && pointsData.isNotEmpty)
          ? pointsData.map((point) {
              if (point is GeoPoint) {
                return LatLng(point.latitude, point.longitude);
              }
              return LatLng(0, 0); // Fallback for invalid point
            }).toList()
          : [],
      color: color,
    );
  }

   List<LatLng> calculateDropOffPoints(double interval) {
    List<LatLng> dropOffPoints = [];
    double totalDistance = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      LatLng start = points[i];
      LatLng end = points[i + 1];

      double segmentDistance = calculateDistance(start, end);
      totalDistance += segmentDistance;

      // Calculate number of drop-off points in this segment
      int numPoints = (segmentDistance / interval).floor();

      for (int j = 1; j <= numPoints; j++) {
        double fraction = j / (numPoints + 1);
        double lat = start.latitude + (end.latitude - start.latitude) * fraction;
        double lng = start.longitude + (end.longitude - start.longitude) * fraction;
        dropOffPoints.add(LatLng(lat, lng));
      }
    }

    return dropOffPoints;
  }

  double calculateDistance(LatLng start, LatLng end) {
    const R = 6371000; // Radius of the earth in meters
    double dLat = (end.latitude - start.latitude) * (3.14159 / 180);
    double dLon = (end.longitude - start.longitude) * (3.14159 / 180);
    
    double a = 
      (sin(dLat / 2) * sin(dLat / 2)) +
      (cos(start.latitude * (3.14159 / 180)) * cos(end.latitude * (3.14159 / 180)) * 
      sin(dLon / 2) * sin(dLon / 2)); 
    double c = 2 * atan2(sqrt(a), sqrt(1 - a)); 
    return R * c; // Distance in meters
  }
}
