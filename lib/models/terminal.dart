import 'dart:convert';

import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
class Terminal {
  final String name;
  final String iconImage;
  final List<LatLng> points;
  final LatLng landmarkCoordinates; 
  final String terminalImage; // New field for terminal image
  List<Route> routes; 

  Terminal({
    required this.name,
    required this.iconImage,
    required this.points,
    required this.routes,
    required this.landmarkCoordinates,
    required this.terminalImage, // Include new field in constructor
  });

  // Factory constructor to create a Terminal from Firestore data
  factory Terminal.fromFirestore(Map<String, dynamic> data) {
    var pointsData = data['points'] ?? [];
    var routesData = data['routes'] ?? [];
    var landmarkSpecificData = data['landmarkCoordinates'] ?? {'latitude': 0.0, 'longitude': 0.0};

    return Terminal(
      name: data['name'] ?? 'Unnamed Terminal',
      iconImage: data['iconImage'] ?? '',
      points: (pointsData is List && pointsData.isNotEmpty)
          ? pointsData.map((point) {
              if (point is GeoPoint) {
                return LatLng(point.latitude, point.longitude);
              }
              return LatLng(0, 0);
            }).toList()
          : [],
      landmarkCoordinates: LatLng(
        landmarkSpecificData['latitude'] ?? 0.0,
        landmarkSpecificData['longitude'] ?? 0.0,
      ),
      routes: (routesData is List)
          ? routesData.map((routeData) => Route.fromFirestore(routeData)).toList()
          : [],
      terminalImage: data['terminalImage'] ?? '', // Include the new field
    );
  }

  Future<Map<String, dynamic>?> fetchPlaceDetails(String accessToken, String terminalName, {double? latitude, double? longitude}) async {
    // Use provided latitude and longitude or default to the first point
    final LatLng location = (latitude != null && longitude != null)
        ? LatLng(latitude, longitude)
        : points.isNotEmpty ? points.first : LatLng(0, 0); // Fallback

    // Foursquare API URL for searching venues
    final String url =
        'https://api.foursquare.com/v3/places/search?query=&ll=${location.latitude},${location.longitude}&limit=1';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'fsq3rgV6402ofALVKftiTn0po1al4GQstY7LOErKP+J0x9w=' // Add your API key here
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Return the first venue found
      return data['results'].isNotEmpty ? data['results'][0] : null;
    } else {
      throw Exception('Failed to load place details');
    }
  }
}

class Route {
  final String name;
  final List<LatLng> points;
  final String color;
  final List<LatLng> dropOffPoints; // New field for drop-off points

  Route({
    required this.name,
    required this.points,
    required this.color,
    required this.dropOffPoints, // Add to constructor
  });

  // Factory constructor to create a Route from Firestore data
  factory Route.fromFirestore(Map<String, dynamic> data) {
    var pointsData = data['points'] ?? [];
    var color = data['color'] ?? '#000000'; // Default to black if color is not provided
    var dropOffPointsData = data['dropOffPoints'] ?? []; // Fetch drop-off points

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
      dropOffPoints: (dropOffPointsData is List && dropOffPointsData.isNotEmpty)
          ? dropOffPointsData.map((point) {
              if (point is GeoPoint) {
                return LatLng(point.latitude, point.longitude);
              }
              return LatLng(0, 0); // Fallback for invalid point
            }).toList()
          : [], // Initialize drop-off points
    );
  }

  // Add fromMap method to handle generic Map<String, dynamic> input
  factory Route.fromMap(Map<String, dynamic> data) {
    var pointsData = data['points'] ?? [];
    var color = data['color'] ?? '#000000'; // Default to black if color is not provided
    var dropOffPointsData = data['dropOffPoints'] ?? []; // Fetch drop-off points

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
      dropOffPoints: (dropOffPointsData is List && dropOffPointsData.isNotEmpty)
          ? dropOffPointsData.map((point) {
              if (point is GeoPoint) {
                return LatLng(point.latitude, point.longitude);
              }
              return LatLng(0, 0); // Fallback for invalid point
            }).toList()
          : [], // Initialize drop-off points
    );
  }
  
}





