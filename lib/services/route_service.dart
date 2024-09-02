import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';

class RouteService {
  final String accessToken = 'pk.eyJ1IjoicmVpamkyMDAyIiwiYSI6ImNsdnV6c2hhZzFxZTAybG1oMzJoeDNtOGQifQ.0hCQ02IhCilBVh-DhFDioQ';

     Future<List<LatLng>> getRoute(List<LatLng> points) async {
    final coordinates = points.map((point) => '${point.longitude},${point.latitude}').join(';');
    
    // Use driving profile with adjustments for ignoring restrictions
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates?access_token=$accessToken&geometries=geojson&overview=full&steps=false&annotations=maxspeed';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'];
      return route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    } else {
      throw Exception('Failed to load route');
    }
  }

  Future<List<LatLng>> getWalkingRoute(LatLng start, LatLng end) async {
    final coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    
    // Similarly, use walking profile and adjust for geometry only
    final url = 'https://api.mapbox.com/directions/v5/mapbox/walking/$coordinates?access_token=$accessToken&geometries=geojson&overview=full&steps=false';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'];
      return route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    } else {
      throw Exception('Failed to load walking route');
    }
  }

  Future<List<LatLng>> getTerminalRoute(LatLng start, LatLng end) async {
    final coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    
    // Adjust for terminal routes as well
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates?access_token=$accessToken&geometries=geojson&overview=full&steps=false';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'];
      return route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
    } else {
      throw Exception('Failed to load terminal route');
    }
  }

  Future<List<LatLng>> calculateRoute(LatLng start, LatLng end, {String mode = 'driving'}) async {
    try {
      switch (mode) {
        case 'walking':
          return await getWalkingRoute(start, end);
        case 'driving':
          return await getRoute([start, end]);
        case 'terminal':
          return await getTerminalRoute(start, end);
        default:
          throw Exception('Unsupported mode of transportation: $mode');
      }
    } catch (e) {
      print('Error calculating route: $e');
      rethrow;
    }
  }
}
