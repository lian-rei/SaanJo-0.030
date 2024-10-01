import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/terminal.dart' as custom;
import '../tokens/tokens.dart';
import '../services/route_service.dart';

class AddTerminalPage extends StatefulWidget {
  @override
  _AddTerminalPageState createState() => _AddTerminalPageState();
}

class _AddTerminalPageState extends State<AddTerminalPage> {
  final TextEditingController _terminalNameController = TextEditingController();
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _terminalTypeController = TextEditingController();
  final TextEditingController _landmarkLatitudeController = TextEditingController();
  final TextEditingController _landmarkLongitudeController = TextEditingController();
  final AccessToken _accessToken = AccessToken();
  final RouteService _routeService = RouteService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<custom.Route> _routes = [];
  List<LatLng> _routePoints = [];
  MapboxMapController? _mapController;
  Color _routeColor = Colors.red; // Default color
  List<Symbol>? _markers = []; // List to keep track of added markers

  void _addMarker(LatLng tappedPoint) {
  setState(() {
    _routePoints.add(tappedPoint);
  });

  _mapController!.addSymbol(SymbolOptions(
    geometry: tappedPoint,
    iconImage: "custom-pin",
    iconSize: 0.1,
  )).then((symbol) {
    _markers?.add(symbol);
    // Only calculate the route if there are at least two points
    if (_routePoints.length >= 2) {
      _calculateRoute(_routePoints.first, tappedPoint);
    }
  });
}

Future<void> _calculateRoute(LatLng start, LatLng end) async {
  try {
    List<LatLng> routePoints = await _routeService.calculateRoute(start, end, mode: 'driving');
    setState(() {
      _routePoints = routePoints; // Update routePoints with fetched route
      _drawRoutes(); // Draw the updated route on the map
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching route: $e')),
    );
  }
}



  void _drawRoutes() {
  _mapController?.clearLines(); // Clear existing lines

  if (_routePoints.length < 2) return; // Ensure at least two points to draw a route

  _mapController?.addLine(LineOptions(
    geometry: _routePoints,
    lineColor: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
    lineWidth: 5.0,
    lineOpacity: 0.8,
  ));
}


  Future<void> _addRoute() async {
  final routeName = _routeNameController.text.trim();

  if (routeName.isNotEmpty && _routePoints.length >= 2) {
    // Get the start and end points from the markers
    LatLng start = _routePoints.first;
    LatLng end = _routePoints.last;

    try {
      // Fetch the route using the RouteService
      List<LatLng> routePoints = await _routeService.calculateRoute(start, end, mode: 'driving');
      setState(() {
        _routes.add(custom.Route(
          name: routeName,
          points: routePoints,
          color: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
        ));
        // Draw the fetched route on the map
        _mapController?.addLine(LineOptions(
          geometry: routePoints,
          lineColor: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ));
      });

      _routeNameController.clear();
      _routePoints.clear();
      _markers?.clear(); // Clear markers as well
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching route: $e')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please add at least two points to create a route!')),
    );
  }
}

  void _saveTerminal() {
    final terminalName = _terminalNameController.text.trim();
    final landmarkLatitude = double.tryParse(_landmarkLatitudeController.text.trim());
    final landmarkLongitude = double.tryParse(_landmarkLongitudeController.text.trim());

    if (terminalName.isNotEmpty && landmarkLatitude != null && landmarkLongitude != null) {
      _firestore.collection('terminals').doc(terminalName).set({
        'name': terminalName,
        'iconImage': _terminalTypeController.text.trim(),
        'landmarkCoordinates': {
          'latitude': landmarkLatitude,
          'longitude': landmarkLongitude,
        },
      }).then((_) {
        final terminalRef = _firestore.collection('terminals').doc(terminalName);

        for (var route in _routes) {
          terminalRef.collection('routes').doc(route.name).set({
            'name': route.name,
            'points': route.points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
            'color': route.color,
          });
        }

        setState(() {
          _terminalNameController.clear();
          _landmarkLatitudeController.clear();
          _landmarkLongitudeController.clear();
          _terminalTypeController.clear();
          _routes.clear();
          _markers?.clear(); // Clear markers as well
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terminal saved successfully!')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all the fields correctly!')),
      );
    }
  }

  void _onMapCreated(MapboxMapController controller) async {
    _mapController = controller;

    final Uint8List image = await _loadImage("assets/pin.png");
    _mapController?.addImage("custom-pin", image);
  }

  Future<Uint8List> _loadImage(String path) async {
    ByteData byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  void _onMapTapped(LatLng tappedPoint) {
    _addMarker(tappedPoint);
  }

  void _undoLastMarker() {
  if (_routePoints.isNotEmpty) {
    // Remove the last point and marker
    _routePoints.removeLast();
    
    // Remove the last marker from the map
    if (_markers!.isNotEmpty) {
      _mapController?.removeSymbol(_markers!.removeLast());
    }

    // Check how many points are left
    if (_routePoints.length >= 2) {
      // Recalculate the route for remaining points
      _calculateRoute(_routePoints.first, _routePoints.last);
    } else if (_routePoints.length == 1) {
      // Draw a route to the single remaining point if needed
      _drawRoutes();
    } else {
      // Clear lines if no points left
      _mapController?.clearLines();
    }
  }
}




  void _selectColor() async {
    Color pickedColor = await showDialog<Color>(context: context, builder: (context) {
      Color tempColor = _routeColor;
      return AlertDialog(
        title: Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (color) {
              tempColor = color;
            },
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: Text('Select'),
            onPressed: () {
              Navigator.of(context).pop(tempColor);
            },
          ),
        ],
      );
    }) ?? _routeColor;

    setState(() {
      _routeColor = pickedColor;
      _drawRoutes(); // Redraw the route with the new color
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Terminal'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MapboxMap(
                  accessToken: _accessToken.mapboxaccesstoken,
                  onMapCreated: _onMapCreated,
                  onMapClick: (point, latLng) => _onMapTapped(latLng),
                  styleString: "mapbox://styles/mapbox/streets-v11",
                  initialCameraPosition: CameraPosition(
                    target: LatLng(14.7954, 121.0524),
                    zoom: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _undoLastMarker,
            child: Icon(Icons.undo),
            tooltip: 'Undo Last Marker',
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 300,
              child: ListView(
                children: [
                  TextField(
                    controller: _terminalNameController,
                    decoration: InputDecoration(labelText: 'Terminal Name'),
                  ),
                  TextField(
                    controller: _landmarkLatitudeController,
                    decoration: InputDecoration(labelText: 'Landmark Latitude'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _landmarkLongitudeController,
                    decoration: InputDecoration(labelText: 'Landmark Longitude'),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    value: _terminalTypeController.text.isEmpty ? null : _terminalTypeController.text,
                    items: [
                      DropdownMenuItem(child: Text('Jeep'), value: 'jeep.png'),
                      DropdownMenuItem(child: Text('E-Jeep'), value: 'ejeep.png'),
                      DropdownMenuItem(child: Text('Jeep + E-Jeep'), value: 'jeepejeep.png'),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _terminalTypeController.text = value ?? '';
                      });
                    },
                    decoration: InputDecoration(labelText: 'Terminal Type'),
                  ),
                  Divider(),
                  Text('Add Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _routeNameController,
                    decoration: InputDecoration(labelText: 'Route Name'),
                  ),
                  GestureDetector(
                    onTap: _selectColor,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Route Color:'),
                          Container(
                            width: 40,
                            height: 40,
                            color: _routeColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addRoute,
                    child: Text('Add Route'),
                  ),
                  Divider(),
                  ElevatedButton(
                    onPressed: _saveTerminal,
                    child: Text('Save Terminal'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
