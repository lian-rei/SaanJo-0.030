import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';

class RouteService {
  final String accessToken = 'pk.eyJ1IjoicmVpamkyMDAyIiwiYSI6ImNsdnV6c2hhZzFxZTAybG1oMzJoeDNtOGQifQ.0hCQ02IhCilBVh-DhFDioQ';

Future<List<LatLng>> getRoute(List<LatLng> points, {bool alternatives = false}) async {
  // Check if there are at least two points
  if (points.length < 2) {
    throw Exception('At least two points are required for routing');
  }

  // Constructing the waypoints string
  final waypoints = points.map((point) => '${point.longitude},${point.latitude}').join(';');
  print('Waypoints for route: $waypoints');

  // Constructing the URL with waypoints
  String url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$waypoints?access_token=$accessToken&geometries=geojson&overview=full&steps=false&annotations=maxspeed&alternatives=${alternatives ? 'true' : 'false'}';

  // Making the HTTP GET request
  final response = await http.get(Uri.parse(url));

  // Checking the response status
  if (response.statusCode == 200) {
    print('Response received successfully: ${response.statusCode}');
    try {
      final data = json.decode(response.body);
      print('Response body: ${response.body}'); // Log the full response body

      // Accessing the route geometry
      final route = data['routes'][0]['geometry']['coordinates'];
      return route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    } catch (e) {
      print('Error parsing response: $e');
      throw Exception('Failed to parse route data');
    }
  } else {
    print('Error: ${response.body}');
    throw Exception('Failed to load route');
  }
}


Future<List<LatLng>> getRouteForCreation(List<LatLng> points, {bool alternatives = false}) async {
  // Check if there are at least two points
  if (points.length < 2) {
    throw Exception('At least two points are required for routing');
  }

  // Constructing the waypoints string
  final waypoints = points.map((point) => '${point.longitude},${point.latitude}').join(';');
  print('Waypoints for route: $waypoints');

  // Constructing the URL with waypoints
  String url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$waypoints?access_token=$accessToken&geometries=geojson&overview=full&steps=false&annotations=maxspeed&alternatives=${alternatives ? 'true' : 'false'}';

  // Making the HTTP GET request
  final response = await http.get(Uri.parse(url));

  // Checking the response status
  if (response.statusCode == 200) {
    print('Response received successfully: ${response.statusCode}');
    try {
      final data = json.decode(response.body);
      print('Response body: ${response.body}'); // Log the full response body

      // Accessing the route geometry
      final route = data['routes'][0]['geometry']['coordinates'];
      return route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    } catch (e) {
      print('Error parsing response: $e');
      throw Exception('Failed to parse route data');
    }
  } else {
    print('Error: ${response.body}');
    throw Exception('Failed to load route');
  }
}






  Future<List<LatLng>> getWalkingRoute(LatLng start, LatLng end, {bool alternatives = false}) async {
    final coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    
    String url = 'https://api.mapbox.com/directions/v5/mapbox/walking/$coordinates?access_token=$accessToken&geometries=geojson&overview=full&steps=false&alternatives=${alternatives ? 'true' : 'false'}';

    // Add the fixed departure time to the URL



    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'];
      return route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    } else {
      throw Exception('Failed to load walking route');
    }
  }

  Future<List<LatLng>> getTerminalRoute(LatLng start, LatLng end, {bool alternatives = false}) async {
    final coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    
    String url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates?access_token=$accessToken&geometries=geojson&overview=full&steps=false&alternatives=${alternatives ? 'true' : 'false'}';

    // Add the fixed departure time to the URL


    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'];
      return route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    } else {
      throw Exception('Failed to load terminal route');
    }
  }

  Future<List<LatLng>> calculateRoute(LatLng start, LatLng end, {String mode = 'driving', bool alternatives = false}) async {
    try {
      switch (mode) {
        case 'walking':
          return await getWalkingRoute(start, end, alternatives: alternatives);
        case 'driving':
          return await getRoute([start, end], alternatives: alternatives);
        case 'terminal':
          return await getTerminalRoute(start, end, alternatives: alternatives);
        default:
          throw Exception('Unsupported mode of transportation: $mode');
      }
    } catch (e) {
      print('Error calculating route: $e');
      rethrow;
    }
  }
}
