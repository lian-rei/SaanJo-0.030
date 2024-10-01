import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/terminal.dart'; // Ensure this is the correct import
import 'map_controller.dart'; // Import the MapController

class RoutingController {
  final List<Terminal> terminals = [];
  final MapController mapController; // Use MapController instance
  final String foursquareApiKey = "fsq3rgV6402ofALVKftiTn0po1al4GQstY7LOErKP+J0x9w=";

  RoutingController(this.mapController);

  Future<void> fetchTerminals() async {
    try {
      QuerySnapshot terminalsSnapshot = await FirebaseFirestore.instance.collection('terminals').get();
      
      for (var doc in terminalsSnapshot.docs) {
        var terminal = Terminal.fromFirestore(doc.data() as Map<String, dynamic>);
        terminal.routes = await fetchRoutesForTerminal(doc.id); // Fetch routes for each terminal
        terminals.add(terminal);
      }

      print('Fetched ${terminals.length} terminals from Firestore.');

      // Debug: Print details for each terminal
      for (var terminal in terminals) {
        print('Terminal: ${terminal.name}');
        print('Landmark Coordinates: (${terminal.landmarkCoordinates.latitude}, ${terminal.landmarkCoordinates.longitude})');
        if (terminal.routes.isNotEmpty) {
          for (var route in terminal.routes) {
            print('Route: ${route.name} with ${route.points.length} points:');
            for (var point in route.points) {
              print('  Point: (${point.latitude}, ${point.longitude})');
            }
          }
        } else {
          print('  No routes available for this terminal.');
        }
      }
    } catch (e) {
      print('Error fetching terminals: $e');
    }
  }

  Future<List<Route>> fetchRoutesForTerminal(String terminalId) async {
    List<Route> routes = [];
    try {
      QuerySnapshot routesSnapshot = await FirebaseFirestore.instance
          .collection('terminals')
          .doc(terminalId)
          .collection('routes')
          .get();

      for (var routeDoc in routesSnapshot.docs) {
        routes.add(Route.fromFirestore(routeDoc.data() as Map<String, dynamic>));
      }
    } catch (e) {
      print('Error fetching routes for terminal $terminalId: $e');
    }
    return routes;
  }

  Future<Terminal?> findNearestTerminal(LatLng currentPosition) async {
    double closestDistance = double.infinity;
    Terminal? nearestTerminal;

    for (var terminal in terminals) {
      double distance = calculateDistance(currentPosition, terminal.landmarkCoordinates);
      print('Distance to terminal ${terminal.name}: $distance meters');
      if (distance < closestDistance) {
        closestDistance = distance;
        nearestTerminal = terminal;
      }
    }

    if (nearestTerminal != null) {
      print('Nearest terminal found: ${nearestTerminal.name} at distance: $closestDistance meters');
    } else {
      print('No nearest terminal found.');
    }
    
    return nearestTerminal;
  }

  Future<bool> canTerminalReachDestination(Terminal terminal, LatLng destination) async {
    const double radiusInMeters = 100.0; // Define your radius

    print('Checking if terminal ${terminal.name} can reach destination at ${destination.latitude}, ${destination.longitude}');

    for (var route in terminal.routes) {
      print('Checking route with ${route.points.length} points.');

      for (var point in route.points) {
        double distance = calculateDistance(point, destination);
        print('Distance to point (${point.latitude}, ${point.longitude}): $distance meters');

        if (distance <= radiusInMeters) {
          print('Terminal ${terminal.name} can reach the destination within the radius.');
          return true; // Destination is within the radius of this point
        }
      }
    }

    print('Terminal ${terminal.name} cannot reach the destination within the radius.');
    return false; // No route point is within the radius
  }

  Future<void> driveToDestination(LatLng terminalPosition, LatLng destination, String accessToken) async {
  String url =
      "https://api.mapbox.com/directions/v5/mapbox/driving/${terminalPosition.longitude},${terminalPosition.latitude};${destination.longitude},${destination.latitude}?geometries=geojson&access_token=$accessToken";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isNotEmpty) {
        var route = data['routes'][0];
        print('Driving route data: ${jsonEncode(route)}'); // Log the route data
        await mapController.displayDrivingRoute(route); // Call displayDrivingRoute method
      } else {
        print('No routes found in driving response.');
      }
    } else {
      print("Failed to fetch driving route: ${response.statusCode}");
    }
  } catch (e) {
    print("Error while fetching driving route: $e");
  }
}


  Future<void> walkToDestination(LatLng currentPosition, LatLng destination, String accessToken) async {
  String url =
      "https://api.mapbox.com/directions/v5/mapbox/walking/${currentPosition.longitude},${currentPosition.latitude};${destination.longitude},${destination.latitude}?geometries=geojson&access_token=$accessToken";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isNotEmpty) {
        var route = data['routes'][0];
        print('Walking route data: ${jsonEncode(route)}'); // Log the route data
        await mapController.displayWalkingRoute(route); // Call displayWalkingRoute method
      } else {
        print('No routes found in walking response.');
      }
    } else {
      print("Failed to fetch walking route: ${response.statusCode}");
    }
  } catch (e) {
    print("Error while fetching walking route: $e");
  }
}

  Future<void> displayRoute(Route route) async {
    try {
      await mapController.displayRoute(route); // Call mapController if necessary
      print('Route displayed successfully.');
    } catch (e) {
      print('Error displaying route: $e');
    }
  }

  double calculateDistance(LatLng start, LatLng end) {
    const R = 6371000; // Radius of the earth in meters
    double dLat = (end.latitude - start.latitude) * (pi / 180);
    double dLon = (end.longitude - start.longitude) * (pi / 180);

    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(start.latitude * (pi / 180)) * cos(end.latitude * (pi / 180)) *
            sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in meters
  }

  Future<void> routeToDestination(LatLng currentPosition, LatLng destination, String accessToken) async {
    Terminal? nearestTerminal = await findNearestTerminal(currentPosition);

    if (nearestTerminal == null) {
        print('No terminals found nearby.');
        return;
    }

    // Step 1: Walk to the nearest terminal
    await walkToDestination(currentPosition, nearestTerminal.landmarkCoordinates, accessToken);

    // Step 2: Check if the terminal can reach the destination
    bool canReachDestination = await canTerminalReachDestination(nearestTerminal, destination);

    if (canReachDestination) {
        // Step 3: Simulate driving to the destination from the terminal
        await driveToDestination(nearestTerminal.landmarkCoordinates, destination, accessToken); 

        // Step 4: Walk from the last driving point to the final destination (if needed)
        await walkToDestination(destination, destination, accessToken); // Adjust if you have a specific end point after driving
    } else {
        print('The nearest terminal cannot reach the destination: ${nearestTerminal.name}');
    }
}




  Future<List<dynamic>> fetchPlaceSuggestions(String query, LatLng location) async {
    final String nearLocation = "San Jose Del Monte, Bulacan, Philippines";
    final encodedQuery = Uri.encodeComponent(query); // URL-encode the query

    final String url =
        "https://api.foursquare.com/v3/places/search?query=$encodedQuery&near=$nearLocation&limit=10";

    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Authorization": foursquareApiKey,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results']
            .map((place) => {
                  'place_name': place['name'],
                  'geometry': {
                    'coordinates': [
                      place['geocodes']['main']['longitude'],
                      place['geocodes']['main']['latitude'],
                    ],
                  },
                })
            .toList();
      } else {
        print("Failed to fetch suggestions: ${response.statusCode}");
        print("Response body: ${response.body}"); // Log the response body for more details
        return [];
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
      return [];
    }
  }

  Future<LatLng?> getUserLocation() async {
    if (kIsWeb) {
      // For web, you might want to show a dialog to manually set the location.
      return await _getManualLocation();
    } else {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        return LatLng(position.latitude, position.longitude);
      } catch (e) {
        print("Error getting user location: $e");
        return null;
      }
    }
  }

  Future<LatLng?> _getManualLocation() async {
    // Implement a dialog or similar UI to allow the user to input latitude and longitude.
    // Return the manually set LatLng here.
    return LatLng(14.795935,121.030774); // Placeholder for manual input
  }
}
