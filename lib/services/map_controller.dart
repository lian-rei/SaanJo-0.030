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
import 'dart:js' as js;

class MapController extends ChangeNotifier {
  MapboxMapController? mapController;
  final LocationService locationService = LocationService();
  final RouteService routeService = RouteService();
  Future<Position>? positionFuture;
  bool styleLoaded = false;
  bool isRoutingEnabled = false;
  List<Circle> _dropOffCircles = [];

  Map<String, tmodel.Terminal> terminalMarkers = {}; // Store terminal markers
  Set<Symbol> dynamicMarkers = {};  // Store dynamically added (user/routing) markers
  tmodel.Terminal? selectedTerminal;
  List<Line> currentPolylines = [];
  final AccessToken _accessToken = AccessToken();
  
  final ValueNotifier<tmodel.Terminal?> selectedTerminalNotifier = ValueNotifier<tmodel.Terminal?>(null);

  void setMapController(MapboxMapController controller) {
    mapController = controller;
  }

  void clearSelectedTerminal() {
    selectedTerminal = null;
    selectedTerminalNotifier.value = null;
    notifyListeners();
  }

Future<Position> initializeLocationService(BuildContext context) async {
  if (kIsWeb) {
    final geolocationSupported = await _checkGeolocationSupport();
    if (geolocationSupported) {
      try {
        // Attempt to get the user's position
        Position position = await locationService.determinePosition();
        print("Current position: ${position.latitude}, ${position.longitude}");
        positionFuture = Future.value(position); // Set positionFuture
        return position;
      } catch (e) {
        print('Error determining position: $e');
      }
    } else {
      print('Geolocation is not supported on this browser.');
    }
  } else {
    try {
      // Attempt to get the user's position
      Position position = await locationService.determinePosition();
      print("Current position: ${position.latitude}, ${position.longitude}");
      positionFuture = Future.value(position); // Set positionFuture
      return position;
    } catch (e) {
      print('Error determining position: $e');
    }
  }

  // Default fallback coordinates
  Position fallbackPosition = Position(
    latitude: 14.808227,
    longitude: 121.047535,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: 0.0,
    altitudeAccuracy: 5.0,
    heading: 0.0,
    headingAccuracy: 5.0,
    speed: 0.0,
    speedAccuracy: 5.0,
  );

  positionFuture = Future.value(fallbackPosition); // Set positionFuture
  return fallbackPosition;
}




  Future<bool> _checkGeolocationSupport() async {
    return js.context['navigator']['geolocation'] != null;
  }






  void onMapCreated(MapboxMapController controller) {
    mapController = controller;
    
  }
  
  void onStyleLoaded() {
    styleLoaded = true;
    _addMarkers();

  }

Map<String, tmodel.Terminal> _terminalSymbols = {}; // Store terminals by symbol ID

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
  final String firebaseStorageUrl = terminal.iconImage; 
  final http.Response response = await http.get(Uri.parse(firebaseStorageUrl));

  // Check for response status
  if (response.statusCode == 200) {
    final Uint8List list = response.bodyBytes;
    final img.Image image = img.decodeImage(list)!;
    final Uint8List markerImage = Uint8List.fromList(img.encodePng(image));

    await mapController!.addImage(terminal.name, markerImage);
    
    var symbol = await addSymbol(
      SymbolOptions(
        geometry: firstPoint,
        iconImage: terminal.name,
        iconSize: 0.15,
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
    print('Added symbol for ${terminal.name} at ${firstPoint.latitude}, ${firstPoint.longitude}.');
  } else {
    print('Error fetching image for ${terminal.name}: ${response.statusCode} ${response.reasonPhrase}');
  }
} catch (e) {
  print('Error adding symbol for ${terminal.name}: $e ');
}
}

  mapController?.onSymbolTapped.add(_onSymbolTapped);
}


  void _onSymbolTapped(Symbol symbol) {
    selectedTerminal = terminalMarkers[symbol.id];
    selectedTerminalNotifier.value = selectedTerminal;
    notifyListeners();
  }

 Future<void> createDropOffCircles(List<LatLng> dropOffPoints, String color) async {
    for (LatLng point in dropOffPoints) {
      final circle = await mapController?.addCircle(
        CircleOptions(
          geometry: point,
          circleColor: color,
          circleRadius: 5.0, // Circle radius in meters
          circleOpacity: 1, // Circle opacity
        ),
      );
      _dropOffCircles.add(circle!); // Store the circle for later use
    }
  }

  // Method to clear drop-off circles
  Future<void> clearDropOffCircles() async {
    for (Circle circle in _dropOffCircles) {
      await mapController?.removeCircle(circle);
    }
    _dropOffCircles.clear(); // Clear the list of circles
  }


  
  // Clear dynamic markers only (leaving terminal markers intact)
  Future<void> clearDynamicMarkers() async {
    if (mapController == null) return;

    for (var marker in dynamicMarkers) {
      await mapController!.removeSymbol(marker);
    }
    dynamicMarkers.clear(); // Clear the set of dynamic markers
  }

   clearCurrentPolylines() {
    for (var line in currentPolylines) {
    mapController?.removeLine(line);
  }
  currentPolylines.clear();
  }

  Future<void> removeSymbol (Symbol symbol) async {
    await mapController!.removeSymbol(symbol);
  }

  Future<void> addImage(String id, String assetPath) async {
    final Uint8List image = await _loadImage(assetPath);
    await mapController!.addImage(id, image);
  }

    Future<Uint8List> _loadImage(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }


  Future<void> drawRoute(tmodel.Route route) async {
  if (mapController == null) {
    print('Map controller is null. Cannot draw route.');
    return;
  }

  try {
    // Clear existing dynamic markers if necessary
    await clearDynamicMarkers(); 

    List<LatLng> routePoints = await routeService.getRoute(route.points);
    Line line = await addLine(
      LineOptions(
        geometry: routePoints,
        lineColor: route.color,
        lineWidth: 5.0,
        lineOpacity: 0.8,
      ),
    );
    currentPolylines.add(line);

    // Debugging drop-off points
    print('Drop-off Points: ${route.dropOffPoints}');
    
    // Use the dropOffPoints directly from the route
    for (var point in route.dropOffPoints) {
      print('Adding drop-off point at: ${point.latitude}, ${point.longitude}');
      await addCircle(point);
    }
  } catch (e) {
    print('Error drawing route: $e');
  }
}
  void _addPolygon() {
  if (mapController != null) {
    mapController!.addFill(
      FillOptions(
        geometry: [
          [
            LatLng(14.7969574, 121.0446596),
            LatLng(14.7975176, 121.0443807),
            LatLng(14.7985756, 121.0441232),
            LatLng(14.7997996, 121.0440588),
            LatLng(14.8010029, 121.0442519),
            LatLng(14.8014800, 121.0443377),
            LatLng(14.8016253, 121.0429001),
            LatLng(14.8022476, 121.0426855),
            LatLng(14.8029322, 121.0434151),
            LatLng(14.8037206, 121.0440159),
            LatLng(14.8045504, 121.0442519),
            LatLng(14.8045504, 121.0442734),
            LatLng(14.8081393, 121.0428357),
            LatLng(14.8089691, 121.0427713),
            LatLng(14.8102968, 121.0429430),
            LatLng(14.8116452, 121.0415483),
            LatLng(14.8127446, 121.0406685),
            LatLng(14.8131180, 121.0390162),
            LatLng(14.8139478, 121.0388231),
            LatLng(14.8153999, 121.0379648),
            LatLng(14.8172254, 121.0360336),
            LatLng(14.8177440, 121.0327077),
            LatLng(14.8186360, 121.0318065),
            LatLng(14.8188020, 121.0297251),
            LatLng(14.8190509, 121.0286307),
            LatLng(14.8202540, 121.0275578),
            LatLng(14.8213327, 121.0252833),
            LatLng(14.8214364, 121.0235023),
            LatLng(14.8200051, 121.0212922),
            LatLng(14.8191961, 121.0199618),
            LatLng(14.8186775, 121.0187173),
            LatLng(14.8186982, 121.0178375),
            LatLng(14.8185738, 121.0170221),
            LatLng(14.8180552, 121.0167861),
            LatLng(14.8173084, 121.0176873),
            LatLng(14.8175366, 121.0182452),
            LatLng(14.8166861, 121.0186958),
            LatLng(14.8153792, 121.0179448),
            LatLng(14.8137196, 121.0170436),
            LatLng(14.8128484, 121.0175371),
            LatLng(14.8105457, 121.0175157),
            LatLng(14.8088861, 121.0181165),
            LatLng(14.8066871, 121.0191679),
            LatLng(14.8062100, 121.0191035),
            LatLng(14.8050483, 121.0188031),
            LatLng(14.8037621, 121.0188460),
            LatLng(14.8029737, 121.0184169),
            LatLng(14.8020817, 121.0179663),
            LatLng(14.8010651, 121.0184383),
            LatLng(14.7998826, 121.0198975),
            LatLng(14.7964180, 121.0234809),
            LatLng(14.7949866, 121.0253692),
            LatLng(14.7955052, 121.0265493),
            LatLng(14.7950695, 121.0268283),
            LatLng(14.7944264, 121.0271716),
            LatLng(14.7935758, 121.0272360),
            LatLng(14.7926837, 121.0274935),
            LatLng(14.7915634, 121.0280728),
            LatLng(14.7910032, 121.0292530),
            LatLng(14.7902356, 121.0289097),
            LatLng(14.7897169, 121.0292959),
            LatLng(14.7875178, 121.0300684),
            LatLng(14.7858580, 121.0297465),
            LatLng(14.7850074, 121.0300040),
            LatLng(14.7842397, 121.0305405),
            LatLng(14.7831194, 121.0314631),
            LatLng(14.7836173, 121.0337162),
            LatLng(14.7846132, 121.0342956),
            LatLng(14.7853808, 121.0344028),
            LatLng(14.7858165, 121.0351539),
            LatLng(14.7867086, 121.0350895),
            LatLng(14.7871028, 121.0356474),
            LatLng(14.7882024, 121.0358834),
            LatLng(14.7892398, 121.0362697),
            LatLng(14.7904846, 121.0373211),
            LatLng(14.7923310, 121.0382652),
            LatLng(14.7926630, 121.0385013),
            LatLng(14.7924763, 121.0389090),
            LatLng(14.7920406, 121.0389519),
            LatLng(14.7915634, 121.0404754),
            LatLng(14.7906298, 121.0427284),
            LatLng(14.7920198, 121.0435009),
            LatLng(14.7938870, 121.0440159),
            LatLng(14.7952148, 121.0448742),
            LatLng(14.7969574, 121.0446596), // Closing the polygon
          ]
        ],
        fillColor: '#ff0000', // Red color
        fillOpacity: 0.1,
        fillOutlineColor: '#ff0000', // Outline color for the border
      ),
    );
  }
}




Future<void> addCircle(LatLng point) async {
  if (mapController == null) {
    print('Map controller is null. Cannot add circle.');
    return;
  }

  CircleOptions circleOptions = CircleOptions(
    geometry: point,
    circleRadius: 4.0, 
    circleColor: '#FF0000', 
    circleOpacity: 0.8, 
  );

  try {
    await mapController!.addCircle(circleOptions);
    print('Circle added at: ${point.latitude}, ${point.longitude}');
  } catch (e) {
    print('Error adding circle at ${point.latitude}, ${point.longitude}: $e');
  }
}



  void enableRouting() {
    isRoutingEnabled = true;
    notifyListeners();
  }

  List<LatLng> filterRouteCoordinates(List<LatLng> fullRoute, LatLng startPoint, LatLng endPoint) {
  // Find indices for start and end points
  int startIndex = fullRoute.indexWhere((point) => point.latitude == startPoint.latitude && point.longitude == startPoint.longitude);
  int endIndex = fullRoute.indexWhere((point) => point.latitude == endPoint.latitude && point.longitude == endPoint.longitude);
  
  if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
    return [];
  }
  
  // Get the sublist between start and end points
  List<LatLng> subRoute = fullRoute.sublist(startIndex, endIndex + 1); // Include end point

  // Now filter this subRoute to a maximum of 25 points
  return filterCoordinates(subRoute);
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
  if (mapController == null) {
    print('Map controller is null. Cannot display route.');
    return;
  }

  try {
    // Filter the original route points before fetching the route
    List<LatLng> filteredPoints = filterCoordinates(route.points);
    print('Filtered Points: $filteredPoints');

    if (filteredPoints.isEmpty) {
      print('No valid filtered points found. Cannot display route.');
      return;
    }

    List<LatLng> routePoints = await routeService.getRoute(filteredPoints);
    print('Route Points from service: $routePoints');

    if (routePoints.isEmpty) {
      print('No route points returned. Cannot display route.');
      return;
    }

    Line line = await addLine(
      LineOptions(
        geometry: routePoints,
        lineColor: route.color,
        lineWidth: 5.0,
        lineOpacity: 0.8,
      ),
    );

    currentPolylines.add(line);
    print('Polyline added: $line');
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
