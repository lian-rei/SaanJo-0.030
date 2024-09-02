import 'package:flutter/foundation.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'location_service.dart';
import 'route_service.dart';
import '../models/terminal.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapController extends ChangeNotifier {
  MapboxMapController? mapController;
  final LocationService locationService = LocationService();
  final RouteService routeService = RouteService();
  Future<Position>? positionFuture;
  bool styleLoaded = false;
  bool isRoutingEnabled = false;
  Map<String, Terminal> terminalMarkers = {};
  Terminal? selectedTerminal;
  List<Line> currentPolylines = [];
  LatLng? startPoint;
  LatLng? endPoint;

  final ValueNotifier<Terminal?> selectedTerminalNotifier = ValueNotifier<Terminal?>(null);

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

    for (var terminalDoc in terminalsSnapshot.docs) {
      var terminalData = terminalDoc.data() as Map<String, dynamic>;
      var terminal = Terminal.fromFirestore(terminalData);

      print('Terminal name: ${terminal.name}');
      
      QuerySnapshot routesSnapshot = await FirebaseFirestore.instance
          .collection('terminals')
          .doc(terminalDoc.id)
          .collection('routes')
          .get();

      var routes = routesSnapshot.docs.map((routeDoc) {
        var routeData = routeDoc.data() as Map<String, dynamic>;
        return Route.fromMap(routeData);
      }).toList();

      terminal.routes.addAll(routes);

      print('Routes: ${terminal.routes.map((r) => r.name).toList()}');

      if (terminal.points.isEmpty) {
        print('No points available for terminal ${terminal.name}');
        continue;
      }

      var firstPoint = terminal.points.first;
      try {
        final ByteData bytes = await rootBundle.load(terminal.iconImage);
        final Uint8List list = bytes.buffer.asUint8List();
        final img.Image image = img.decodeImage(list)!;
        final Uint8List markerImage = Uint8List.fromList(img.encodePng(image));

        await mapController!.addImage(terminal.name, markerImage);
        var symbol = await mapController!.addSymbol(
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
      } catch (e) {
        print('Error adding symbol for ${terminal.name} at ($firstPoint): $e');
      }
    }

    mapController?.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onSymbolTapped(Symbol symbol) {
    selectedTerminal = terminalMarkers[symbol.id];
    selectedTerminalNotifier.value = selectedTerminal;
    notifyListeners();
  }

  void _clearCurrentPolylines() {
    mapController?.clearLines();
    currentPolylines.clear();
  }

  Future<void> drawRoute(Route route) async {
    if (mapController == null) return;

    try {
      _clearCurrentPolylines();

      List<LatLng> routePoints = await routeService.getRoute(route.points);
      Line line = await mapController!.addLine(
        LineOptions(
          geometry: routePoints,
          lineColor: route.color,
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );
      currentPolylines.add(line);
    } catch (e) {
      print('Error drawing route: $e');
    }
  }

  void enableRouting() {
    isRoutingEnabled = true;
    notifyListeners();
  }

  Future<void> displayRoute(Route route) async {
    if (mapController == null) return;

    try {
      _clearCurrentPolylines();

      List<LatLng> routePoints = await routeService.getRoute(route.points);

      Line line = await mapController!.addLine(
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

  @override
  void dispose() {
    mapController?.onSymbolTapped.remove(_onSymbolTapped);
    selectedTerminalNotifier.dispose();
    super.dispose();
  }
}
