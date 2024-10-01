import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'location_service.dart';
import 'route_service.dart';
import '../models/terminal.dart' as tmodel;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../tokens/tokens.dart';

class MapController extends ChangeNotifier {
  MapboxMapController? mapController;
  final LocationService locationService = LocationService();
  final RouteService routeService = RouteService();
  Future<Position>? positionFuture;
  bool styleLoaded = false;
  bool isRoutingEnabled = false;

  Map<String, tmodel.Terminal> terminalMarkers = {}; // Store terminal markers
  Set<Symbol> dynamicMarkers = {};  // Store dynamically added (user/routing) markers
  tmodel.Terminal? selectedTerminal;
  List<Line> currentPolylines = [];
  final AccessToken _accessToken = AccessToken();
  
  final ValueNotifier<tmodel.Terminal?> selectedTerminalNotifier = ValueNotifier<tmodel.Terminal?>(null);

  void clearSelectedTerminal() {
    selectedTerminal = null;
    selectedTerminalNotifier.value = null;
    notifyListeners();
  }

  void initializeLocationService() {
    if (kIsWeb) {
      positionFuture = Future.value(Position.fromMap({
        'latitude': 14.808227,
        'longitude': 121.047535,
      }));
    } else {
      positionFuture = locationService.determinePosition();
    }
  }

  void onMapCreated(MapboxMapController controller) {
    mapController = controller;
  }

  void onStyleLoaded() {
    styleLoaded = true;
    _addMarkers();
  }

  Future<void> _addMarkers() async {
  if (mapController == null || !styleLoaded) return;

  QuerySnapshot terminalsSnapshot = await FirebaseFirestore.instance.collection('terminals').get();
  print('Number of terminals fetched: ${terminalsSnapshot.docs.length}'); // Debug statement

  for (var terminalDoc in terminalsSnapshot.docs) {
    var terminalData = terminalDoc.data() as Map<String, dynamic>;
    var terminal = tmodel.Terminal.fromFirestore(terminalData);

    QuerySnapshot routesSnapshot = await FirebaseFirestore.instance
        .collection('terminals')
        .doc(terminalDoc.id)
        .collection('routes')
        .get();

    var routes = routesSnapshot.docs.map((routeDoc) {
      var routeData = routeDoc.data() as Map<String, dynamic>;
      return tmodel.Route.fromMap(routeData);
    }).toList();

    terminal.routes.addAll(routes);

    if (terminal.points.isEmpty) {
      print('Terminal ${terminal.name} has no points.'); // Debug statement
      continue;
    }

    var firstPoint = terminal.points.first;
    try {
      final ByteData bytes = await rootBundle.load(terminal.iconImage);
      final Uint8List list = bytes.buffer.asUint8List();
      final img.Image image = img.decodeImage(list)!;
      final Uint8List markerImage = Uint8List.fromList(img.encodePng(image));

      await mapController!.addImage(terminal.name, markerImage);
      var symbol = await addSymbol(
        SymbolOptions(
          geometry: firstPoint,
          iconImage: terminal.name,
          iconSize: 0.07,
          iconHaloWidth: 100,
          iconHaloBlur: 0.2,
          iconHaloColor: "#000000",
          textField: terminal.name,
          textOffset: Offset(0, 2.5),
          textSize: 12.0,
          textHaloColor: "#FFFFFF",
          textHaloWidth: 0.5,
        ),
      );
      terminalMarkers[symbol.id] = terminal;
      print('Added symbol for ${terminal.name} at ${firstPoint.latitude}, ${firstPoint.longitude}.'); // Debug statement
    } catch (e) {
      print('Error adding symbol for ${terminal.name}: $e'); // Catching specific errors
    }
  }

  mapController?.onSymbolTapped.add(_onSymbolTapped);
}


  void _onSymbolTapped(Symbol symbol) {
    selectedTerminal = terminalMarkers[symbol.id];
    selectedTerminalNotifier.value = selectedTerminal;
    notifyListeners();
  }

  // Clear dynamic markers only (leaving terminal markers intact)
  Future<void> clearDynamicMarkers() async {
    if (mapController == null) return;

    for (var marker in dynamicMarkers) {
      await mapController!.removeSymbol(marker);
    }
    dynamicMarkers.clear(); // Clear the set of dynamic markers
  }

  void clearCurrentPolylines() {
    // Only clear dynamic markers and polylines if necessary
    // mapController?.clearLines(); // Commenting this out to keep existing lines
    currentPolylines.clear();
  }

  Future<void> drawRoute(tmodel.Route route) async {
    if (mapController == null) return;

    try {
      // Optionally clear only specific markers if needed
      // clearCurrentPolylines(); 

      List<LatLng> routePoints = await routeService.getRoute(route.points);
      Line line = await addLine(
        LineOptions(
          geometry: routePoints,
          lineColor: route.color, // Ensure this is a valid hex string
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );
      currentPolylines.add(line);

      List<LatLng> dropOffPoints = route.calculateDropOffPoints(500);
      for (var point in dropOffPoints) {
        var symbol = await addSymbol(
          SymbolOptions(
            geometry: point,
            iconImage: "marker-icon",
            iconSize: 0.05,
          ),
        );
        dynamicMarkers.add(symbol); // Add the dynamic marker to the set
      }
    } catch (e) {
      print('Error drawing route: $e');
    }
  }

  void enableRouting() {
    isRoutingEnabled = true;
    notifyListeners();
  }

  List<LatLng> filterCoordinates(List<LatLng> originalPoints) {
  int maxPoints = 25;
  
  // Calculate the required skip count
  int totalPoints = originalPoints.length;
  int skipCount = totalPoints > maxPoints ? (totalPoints / (maxPoints - 1)).ceil() - 1 : 0;

  List<LatLng> filteredPoints = [];

  // Ensure there are points to process
  if (originalPoints.isEmpty) return filteredPoints;

  // Always add the first point
  filteredPoints.add(originalPoints.first);

  // Loop through points, skipping as needed
  for (int i = 1; i < totalPoints - 1; i++) {
    if ((i - 1) % (skipCount + 1) == 0) {
      filteredPoints.add(originalPoints[i]);
    }
  }

  // Always add the last point if not already included
  if (filteredPoints.last != originalPoints.last) {
    filteredPoints.add(originalPoints.last);
  }

  // Limit to 25 points
  return filteredPoints.length > maxPoints ? filteredPoints.sublist(0, maxPoints) : filteredPoints;
}


  Future<void> displayRoute(tmodel.Route route) async {
  if (mapController == null) return;

  try {
    // Filter the original route points before fetching the route
    List<LatLng> filteredPoints = filterCoordinates(route.points);
    List<LatLng> routePoints = await routeService.getRoute(filteredPoints);

    Line line = await addLine(
      LineOptions(
        geometry: routePoints,
        lineColor: route.color,
        lineWidth: 5.0,
        lineOpacity: 0.8,
      ),
    );

    currentPolylines.add(line);
  } catch (e) {
    print('Error displaying route: $e');
  }
}


  Future<List<Map<String, dynamic>>> fetchPlaceSuggestions(String query) async {
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=${_accessToken.mapboxaccesstoken}&proximity=121.047535,14.808227';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['features'].map<Map<String, dynamic>>((feature) => {
        'name': feature['place_name'],
        'coordinates': feature['geometry']['coordinates'],
      }).toList();
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  Future<Line> addLine(LineOptions options) async {
    if (mapController == null) {
      throw Exception("MapController is not initialized.");
    }

    return await mapController!.addLine(options);
  }

  Future<Symbol> addSymbol(SymbolOptions options) async {
    if (mapController == null) {
      throw Exception("MapController is not initialized.");
    }

    return await mapController!.addSymbol(options);
  }

  @override
  void dispose() {
    mapController?.onSymbolTapped.remove(_onSymbolTapped);
    selectedTerminalNotifier.dispose();
    super.dispose();
  }

  Future<void> displayWalkingRoute(Map<String, dynamic> walkingRoute) async {
    if (mapController == null) return;

    try {
      // Extract coordinates from the walking route data
      List<LatLng> routePoints = (walkingRoute['geometry']['coordinates'] as List)
          .map<LatLng>((coord) => LatLng(coord[1], coord[0])) // Map coordinates to LatLng
          .toList();

      // Create the line with specified options
      Line line = await addLine(
        LineOptions(
          geometry: routePoints,
          lineColor: '#00FF00', // Use hex string for green color
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );

      currentPolylines.add(line);
      print('Walking route displayed successfully.');
    } catch (e) {
      print('Error displaying walking route: $e');
    }
  }

  Future<void> displayDrivingRoute(Map<String, dynamic> drivingRoute) async {
    if (mapController == null) return;

    try {
      // Extract coordinates from the driving route data
      List<LatLng> routePoints = (drivingRoute['geometry']['coordinates'] as List)
          .map<LatLng>((coord) => LatLng(coord[1], coord[0])) // Map coordinates to LatLng
          .toList();

      // Create the line with specified options
      Line line = await addLine(
        LineOptions(
          geometry: routePoints,
          lineColor: '#FF0000', 
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );

      currentPolylines.add(line);
      print('Driving route displayed successfully.');
    } catch (e) {
      print('Error displaying driving route: $e');
    }
  }
}
