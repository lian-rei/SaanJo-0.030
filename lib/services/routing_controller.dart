import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart' as widget;
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/terminal.dart'; // Ensure this is the correct import
import 'map_controller.dart'; // Import the MapController
import '../widgets/location_map_widget.dart';
import '../services/fare_service.dart';
import '../services/fare_data.dart';

class DrivingResult {
  final double? distance;
  final LatLng? lastPoint;


  DrivingResult({this.distance, this.lastPoint});
}

class RoutingController {
  final List<Terminal> terminals = [];
  final MapController mapController; // Use MapController instance
  final String foursquareApiKey = "fsq3rgV6402ofALVKftiTn0po1al4GQstY7LOErKP+J0x9w=";
  late LatLng currentlocation;
  

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

Future<Terminal?> findNearestTerminal(LatLng currentPosition, LatLng destination) async {
  double closestDistance = double.infinity;
  Terminal? nearestTerminal;
  currentlocation = currentPosition;

  print('Finding nearest terminal from position: $currentPosition to destination: $destination');
  print('Total terminals to check: ${terminals.length}');

  for (var terminal in terminals) {
    print('Checking terminal: ${terminal.name}'); // Print the name of the terminal being checked

    double terminalClosestDistance = double.infinity;
    bool canReachDestination = false;

    for (var route in terminal.routes) {
      print('  Route: ${route.name} with ${route.dropOffPoints.length} drop-off points');
      
      for (var dropOffPoint in route.dropOffPoints) {
        LatLng dropOffLatLng = LatLng(dropOffPoint.latitude, dropOffPoint.longitude);
        
        // Calculate distance to the drop-off point
        double distance = calculateDistance(currentPosition, dropOffLatLng);
        print('    Distance to drop-off point: $distance meters');

        if (distance < terminalClosestDistance) {
          terminalClosestDistance = distance;
        }

        if (await canTerminalReachDestination(terminal, dropOffLatLng, destination)) {
          canReachDestination = true;
          print('    Terminal ${terminal.name} can reach the destination from drop-off point');
        }
      }
    }

    if (canReachDestination && terminalClosestDistance < closestDistance) {
      closestDistance = terminalClosestDistance;
      nearestTerminal = terminal;
      print('    Nearest terminal updated to: ${nearestTerminal.name} at distance: $closestDistance meters');
    }
  }

  if (nearestTerminal != null) {
    print('Nearest terminal found: ${nearestTerminal.name} at distance: $closestDistance meters');
  } else {
    print('No nearest terminal found that can reach the destination.');
  }

  return nearestTerminal;
}




 Future<DrivingResult?> driveToDestinationUsingTerminalRoutes(
    Terminal terminal, LatLng closestDropOffPoint, LatLng destination, String accessToken) async {

  // Step 1: Get the route points from the terminal's routes
  List<LatLng> allRoutePoints = [];
  for (var route in terminal.routes) {
    allRoutePoints.addAll(route.points); // Collect all route points
  }

  // Step 2: Find the nearest route point to the destination
  LatLng? nearestRoutePoint = await findNearestRoutePoint(allRoutePoints, destination);
  
  if (nearestRoutePoint == null) {
    print('No route points found near the destination.');
    return null; // Early exit if no nearest route point found
  }

  // Step 3: Find the route points between the closest drop-off point and the nearest route point
  List<LatLng> routePointsToDisplay = await getRoutePointsBetween(closestDropOffPoint, nearestRoutePoint, terminal.routes);

  // Step 4: Filter the route points
  List<LatLng> filteredPoints = mapController.filterCoordinates(routePointsToDisplay);

  // Step 5: Construct the driving route from the closest drop-off point to the destination
  List<LatLng> pointsForRouting = [closestDropOffPoint] + filteredPoints;
  
  // Create the coordinates string for the Mapbox API call
  String coordinates = pointsForRouting
      .map((point) => '${point.longitude},${point.latitude}')
      .join(';');

  // Construct the Mapbox API URL
  String url = "https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates?geometries=geojson&access_token=$accessToken";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isNotEmpty) {
        var drivingRoute = data['routes'][0];
        print('Driving route data: ${jsonEncode(drivingRoute)}'); // Log the route data

        // Display the filtered driving route
        await mapController.displayDrivingRoute(drivingRoute);

        // Get the last point of the driving route
        var lastPoint = drivingRoute['geometry']['coordinates'].last;
        LatLng lastLatLng = LatLng(lastPoint[1], lastPoint[0]);

        // Return the distance and the last point reached
        return DrivingResult(distance: drivingRoute['distance'] / 1000, lastPoint: lastLatLng);
      } else {
        print('No routes found in driving response.');
        return null; // Return null if no routes found
      }
    } else {
      print("Failed to fetch driving route: ${response.statusCode}");
      return null; // Return null if there was an error
    }
  } catch (e) {
    print("Error while fetching driving route: $e");
    return null; // Return null if an exception occurred
  }
}


Future<List<LatLng>> getRoutePointsBetween(LatLng startPoint, LatLng endPoint, List<Route> routes) async {
  List<LatLng> points = [];

  for (var route in routes) {
    // Check if the route contains both start and end points
    if (route.points.contains(startPoint) && route.points.contains(endPoint)) {
      int startIndex = route.points.indexOf(startPoint);
      int endIndex = route.points.indexOf(endPoint);

      // Ensure the indices are in the correct order
      if (startIndex < endIndex) {
        points.addAll(route.points.sublist(startIndex, endIndex + 1));
      }
    }
  }

  return points; // Return the route points found
}


Future<LatLng?> findNearestRoutePoint(List<LatLng> routePoints, LatLng destination) async {
  LatLng? nearestPoint;
  double closestDistance = double.infinity;

  for (LatLng point in routePoints) {
    double distance = calculateDistance(point, destination); // Implement calculateDistance as needed
    if (distance < closestDistance) {
      closestDistance = distance;
      nearestPoint = point;
    }
  }

  return nearestPoint; // Return the nearest route point to the destination
}


  // Helper method to find the closest point on terminal routes to the destination
  Future<LatLng?> findClosestPointOnRoutes(List<Route> routes, LatLng destination) async {
    double closestDistance = double.infinity;
    LatLng? closestPoint;

    for (var route in routes) {
      for (var point in route.points) {
        double distance = calculateDistance(point, destination);
        if (distance < closestDistance) {
          closestDistance = distance;
          closestPoint = point; // Update closest point
        }
      }
    }

    if (closestPoint != null) {
      print('Closest point found: (${closestPoint.latitude}, ${closestPoint.longitude}) at distance: $closestDistance meters');
    }

    return closestPoint; // Return the closest point found
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

    Future<void> displayRoute(Route route, LatLng currentPosition, LatLng destination, String accessToken) async {
  // Call the method to display the route on the map
  await mapController.displayRoute(route);
  
  // Optionally, you can walk to the starting point of the selected route
  await walkToDestination(currentPosition, route.points.first, accessToken); // Adjust if necessary
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



Future<void> routeToDestination(LatLng currentPosition, LatLng destination, String accessToken, material.BuildContext context) async {
  List<Route> alternativeRoutes = []; // Store alternative routes
  List<Terminal> terminalsToCheck = [];

  Terminal? nearestTerminal = await findNearestTerminal(currentPosition, destination);
  
  if (nearestTerminal != null) {
    terminalsToCheck.add(nearestTerminal);
  } else {
    print('No terminals found nearby. Walking directly to destination.');
    await walkToDestination(currentPosition, destination, accessToken);
    return;
  }

  LatLng currentDropOffPoint = currentPosition;

  for (var terminal in terminalsToCheck) {
    LatLng? closestDropOffPoint = await findClosestDropOffPoint(terminal.routes, currentDropOffPoint);
    
    if (closestDropOffPoint == null) {
      print('No drop-off points found for terminal ${terminal.name}. Walking directly to destination.');
      await walkToDestination(currentDropOffPoint, destination, accessToken);
      return;
    }

    bool canReach = await canTerminalReachDestination(terminal, closestDropOffPoint, destination);
    
    if (canReach) {
      // Add routes to alternativeRoutes if the terminal can reach the destination
      alternativeRoutes.addAll(terminal.routes);

      await walkToDestination(currentDropOffPoint, closestDropOffPoint, accessToken);
      DrivingResult? drivingResult = await driveToDestinationUsingTerminalRoutes(terminal, closestDropOffPoint, destination, accessToken);
      
      if (drivingResult != null) {
        LatLng lastDrivingPoint = drivingResult.lastPoint ?? closestDropOffPoint;
        
        FareData fareData = await fetchFareData(
          terminal,
          closestDropOffPoint,
          lastDrivingPoint,
          destination,
          drivingResult.distance,
          accessToken,
        );

        _showFareWidget(context, fareData);
        await walkToDestination(lastDrivingPoint, destination, accessToken);
        return; // Successfully reached the destination
      } else {
        print('Failed to fetch driving distance or last point for terminal ${terminal.name}.');
        return;
      }
    } else {
      // If this terminal cannot reach the destination, check for an alternative terminal
      Terminal? alternativeTerminal = await findAnotherTerminal(currentDropOffPoint, destination, terminal);
      if (alternativeTerminal != null) {
        terminalsToCheck.add(alternativeTerminal);
      } else {
        print('No alternative terminals found. Walking directly to destination.');
        await walkToDestination(currentDropOffPoint, destination, accessToken);
        return;
      }
    }

    // Update current drop-off point for the next terminal check
    currentDropOffPoint = closestDropOffPoint;
  }

  // If we exhaust all terminals without reaching the destination
  print('All terminals checked. Walking directly to destination.');
  await walkToDestination(currentDropOffPoint, destination, accessToken);

  // Show alternative routes if available
  if (alternativeRoutes.isNotEmpty) {
    _showAlternativeRoutesWidget(context, alternativeRoutes, currentPosition, destination, accessToken);
  }
}


void _showAlternativeRoutesWidget(material.BuildContext context, List<Route> routes, LatLng currentPosition, LatLng destination, String accessToken) {
  material.showDialog(
    context: context,
    builder: (context) {
      return material.AlertDialog(
        title: widget.Text('Alternative Routes'),
        content: widget.SingleChildScrollView(
          child: widget.Column(
            children: routes.map((route) {
              return material.ElevatedButton(
                child: widget.Text(route.name),
                onPressed: () async {
                  // Display the routing polyline for the selected route
                  await displayRoute(route, currentPosition, destination, accessToken);
                 widget.Navigator.of(context).pop(); // Close the dialog
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}


// Function to display the FareWidget
void _showFareWidget(material.BuildContext context, FareData fareData) {
  material.showDialog(
    context: context,
    builder: (context) {
      return material.Dialog(
        child: FareWidget(fareData: fareData),
      );
    },
  );
}

// Function to fetch fare data
Future<FareData> fetchFareData(
  Terminal nearestTerminal,
  LatLng closestDropOffPoint,
  LatLng lastDrivingPoint,
  LatLng destination,
  double? drivingDistance,
  String accessToken,
) async {
  String dropOffAddress = await fetchAddressFromCoordinates(closestDropOffPoint, accessToken);
  String lastPointAddress = await fetchAddressFromCoordinates(lastDrivingPoint, accessToken);
  String destinationAddress = await fetchAddressFromCoordinates(destination, accessToken);
  
  double walkingDistanceToDropOff = await calculateWalkingDistance(currentlocation, closestDropOffPoint, accessToken);
  double walkingDistanceFromLastPoint = await calculateWalkingDistance(lastDrivingPoint, destination, accessToken);
  
  FareService fareService = FareService();
  List<double> totalFare = fareService.calculateFare(drivingDistance!);

  return FareData(
    terminalName: nearestTerminal.name,
    routeName: nearestTerminal.routes.first.name, // Adjust based on your routes structure
    dropOffAddress: dropOffAddress,
    lastPointAddress: lastPointAddress,
    walkingDistanceToDropOff: walkingDistanceToDropOff,
    walkingDistanceToDestination: walkingDistanceFromLastPoint,
    fareWithoutMarkup: totalFare[0],
    fareWithMarkup: totalFare[1],
    drivingDistance: drivingDistance,
    destinationAddress: destinationAddress,
    walkingDistanceFromLastPoint: walkingDistanceToDropOff
  );
}




Future<String> fetchAddressFromCoordinates(LatLng coordinates, String accessToken) async {
  final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/${coordinates.longitude},${coordinates.latitude}.json?access_token=$accessToken';
  
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['features'] != null && data['features'].isNotEmpty) {
      return data['features'][0]['place_name']; // Return the formatted address
    } else {
      return 'Address not found';
    }
  } else {
    throw Exception('Failed to load address: ${response.reasonPhrase}');
  }
}

Future<double> calculateWalkingDistance(LatLng start, LatLng end, String accessToken) async {
  final url = 'https://api.mapbox.com/directions/v5/mapbox/walking/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$accessToken';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['routes'] != null && data['routes'].isNotEmpty) {
      return data['routes'][0]['distance'] / 1000; // Convert meters to kilometers
    } else {
      throw Exception('No routes found');
    }
  } else {
    throw Exception('Failed to calculate distance: ${response.reasonPhrase}');
  }
}




// New method to find another terminal excluding the specified terminal
Future<Terminal?> findAnotherTerminal(LatLng currentPosition, LatLng destination, Terminal excludedTerminal) async {
  double closestDistance = double.infinity;
  Terminal? nearestTerminal;

  for (var terminal in terminals) {
    if (terminal == excludedTerminal) continue; // Skip the excluded terminal

    double terminalClosestDistance = double.infinity;
    bool canReachDestination = false;

    for (var route in terminal.routes) {
      for (var dropOffPoint in route.dropOffPoints) {
        LatLng dropOffLatLng = LatLng(dropOffPoint.latitude, dropOffPoint.longitude);
        double distance = calculateDistance(currentPosition, dropOffLatLng);
        
        if (distance < terminalClosestDistance) {
          terminalClosestDistance = distance;
        }

        // Check if the terminal can reach the destination from this drop-off point
        if (await canTerminalReachDestination(terminal, dropOffLatLng, destination)) {
          canReachDestination = true; // Terminal can reach the destination
          break; // No need to check other drop-off points for this terminal
        }
      }

      if (canReachDestination) break; // Break out of routes loop if we found a reachable terminal
    }

    if (canReachDestination && terminalClosestDistance < closestDistance) {
      closestDistance = terminalClosestDistance;
      nearestTerminal = terminal;
    }
  }

  if (nearestTerminal != null) {
    print('Alternative terminal found: ${nearestTerminal.name} at distance: $closestDistance meters');
  } else {
    print('No alternative terminals found that can reach the destination.');
  }

  return nearestTerminal;
}


  Future<LatLng?> findClosestDropOffPoint(List<Route> routes, LatLng currentPosition) async {
  double closestDistance = 500;
  LatLng? closestDropOffPoint;

  for (var route in routes) {
    for (var dropOffPoint in route.dropOffPoints) {
      LatLng dropOffLatLng = LatLng(dropOffPoint.latitude, dropOffPoint.longitude);
      double distance = calculateDistance(currentPosition, dropOffLatLng);

      // Print the distance of the current drop-off point from the user's position
      print('Distance to drop-off point (${dropOffLatLng.latitude}, ${dropOffLatLng.longitude}): $distance meters');

      if (distance < closestDistance) {
        closestDistance = distance;
        closestDropOffPoint = dropOffLatLng; // Update closest drop-off point
      }
    }
  }

  if (closestDropOffPoint != null) {
    print('Closest drop-off point found: (${closestDropOffPoint.latitude}, ${closestDropOffPoint.longitude}) at distance: $closestDistance meters');
  } else {
    print('No valid drop-off points found.');
  }

  return closestDropOffPoint; // Return the closest drop-off point found
}


bool isDropOffPointOnRoute(LatLng currentPosition, LatLng destination, LatLng dropOffPoint) {
  // Calculate the distances
  double totalDistance = calculateDistance(currentPosition, destination);
  double distanceToDropOff = calculateDistance(currentPosition, dropOffPoint);
  double distanceFromDropOffToDestination = calculateDistance(dropOffPoint, destination);

  // Check if the drop-off point is ahead of the current position towards the destination
  return (distanceToDropOff + distanceFromDropOffToDestination <= totalDistance + 1); // Adding a small tolerance
}

Future<bool> canTerminalReachDestination(Terminal terminal, LatLng entryPoint, LatLng destination) async {
  const double radiusInMeters = 100.0; // Define your radius

  print('Checking if terminal ${terminal.name} can reach destination at ${destination.latitude}, ${destination.longitude} from entry point at ${entryPoint.latitude}, ${entryPoint.longitude}');

  // Check all routes for this terminal
  for (var route in terminal.routes) {
    // Find the index of the entry point in the route
    int entryIndex = route.points.indexWhere((point) => point.latitude == entryPoint.latitude && point.longitude == entryPoint.longitude);

    // Ensure there are points after the entry point
    if (entryIndex != -1 && entryIndex < route.points.length - 1) {
      // Check subsequent points in the route
      for (var i = entryIndex + 1; i < route.points.length; i++) {
        LatLng routePoint = route.points[i];
        double distance = calculateDistance(routePoint, destination);
        print('Distance to route point (${routePoint.latitude}, ${routePoint.longitude}): $distance meters');

        // Check if this route point is within the radius of the destination
        if (distance <= radiusInMeters) {
          print('Terminal ${terminal.name} can reach the destination from entry point through point (${routePoint.latitude}, ${routePoint.longitude}) within the radius.');
          return true; // Destination is reachable from this point
        }
      }
    }
  }

  print('Terminal ${terminal.name} cannot reach the destination from the entry point within the radius.');
  return false; // No route point is reachable
}





  Future<List<dynamic>> fetchPlaceSuggestions(String query, LatLng location) async {
    final String nearLocation = "San Jose Del Monte, Bulacan, Philippines";
    final encodedQuery = Uri.encodeComponent(query); 

    final String url =
        "https://api.foursquare.com/v3/places/search?query=$encodedQuery&near=$nearLocation&limit=10"; //querry

    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Authorization": foursquareApiKey,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Suggestions fetched: ${data['results']}"); //debuuuuuuuug
        return data['results'].map((place) {
          final address = place['location'] != null ? place['location']['formatted_address'] : 'No address available';
          final category = place['categories'].isNotEmpty ? place['categories'][0]['name'] : 'Unknown';

          return {
            'place_name': place['name'],
            'address': address,
            'type': category,
            'geometry': {
              'coordinates': [
                place['geocodes']['main']['longitude'],
                place['geocodes']['main']['latitude'],
              ],
            },
          };
        }).toList();
      } else {
        print("Failed to fetch suggestions: ${response.statusCode}");
        print("Response body: ${response.body}"); //ANO BA PROBLMEA
        return [];
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
      return [];
    }
  }

  

  Future<LatLng?> getUserLocation(material.BuildContext context) async {
    if (kIsWeb) {
      // Use MapLocationPicker directly for web
      return await _getManualLocation(context);
    } else {

        print("Error getting user location: $e");
        // Prompt user for manual input if there was an error
        return await _getManualLocation(context);
      }
    }
  }

   Future<LatLng?> _getManualLocation(material.BuildContext context) async {
  LatLng? selectedLocation = await material.Navigator.push(
    context,
    material.MaterialPageRoute(
      builder: (context) => MapLocationPicker(), // Navigate to your location picker widget
    ),
  );
  return selectedLocation ?? LatLng(14.795935, 121.030774); // Default location if none selected
}




