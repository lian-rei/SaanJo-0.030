import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/terminal.dart' as custom;
import '../tokens/tokens.dart';
import '../services/route_service.dart';
import 'image_picker_web.dart' if (dart.library.io) 'image_picker_io.dart';


class AddTerminalPage extends StatefulWidget {
  @override
  _AddTerminalPageState createState() => _AddTerminalPageState();
}

class _AddTerminalPageState extends State<AddTerminalPage> {
  final TextEditingController _terminalNameController = TextEditingController();
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _terminalTypeController = TextEditingController();
  final TextEditingController _terminalImageController = TextEditingController();
  final TextEditingController _routeImageController = TextEditingController();
  final AccessToken _accessToken = AccessToken();
  final RouteService _routeService = RouteService();


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Circle> _dropOffPoints = [];
  List<LatLng> _dropOffCoordinates = [];
  List<Circle> _circles = [];
  List<custom.Route> _routes = [];
  List<LatLng> _markerCoordinates = [];
  List<LatLng> _routePoints = [];
  MapboxMapController? _mapController;
  Color _routeColor = Colors.red; 
  List<Symbol>? _markers = []; 
  String? _selectedTerminalType;
  bool _isColorPickerOpen = false;


  @override
  void initState() {
    super.initState();
    

  }


   final Map<String, String> _terminalTypeImageUrls = {
  'jeep': 'https://firebasestorage.googleapis.com/v0/b/saan-jo.appspot.com/o/terminal%20types%2Fjeep.png?alt=media&token=dd658b30-c4e5-48e3-afbc-256fe241c201',
  'ejeep': 'https://firebasestorage.googleapis.com/v0/b/saan-jo.appspot.com/o/terminal%20types%2Fejeeppng.png?alt=media&token=2fc513c3-fa77-4e37-8bef-b0bed0806bf1',
  'jeepejeep': 'https://firebasestorage.googleapis.com/v0/b/saan-jo.appspot.com/o/terminal%20types%2Fjeepejeep.png?alt=media&token=a693adbe-cf32-4424-847e-cd32a67e8ad6',
  'bus': 'https://firebasestorage.googleapis.com/v0/b/saan-jo.appspot.com/o/terminal%20types%2Fbus.png?alt=media&token=3ef46bc9-b861-4aed-9ce1-0ca124ab6c12',
  };


Future<void> _pickImageForTerminal() async {
  String downloadUrl = await uploadImage(context);
  _terminalImageController.text = downloadUrl;
}

Future<void> _pickImageForRoute() async {
  String downloadUrl = await uploadImage(context);
  _routeImageController.text = downloadUrl;
}

  void _addMarker(LatLng tappedPoint) {
  setState(() {
    _routePoints.add(tappedPoint);
    _markerCoordinates.add(tappedPoint);
  });

  _mapController!.addSymbol(SymbolOptions(
    geometry: tappedPoint,
    iconImage: "custom-pin",
    iconSize: 0.1,
  )).then((symbol) {
    _markers?.add(symbol);
    if (_markerCoordinates.length >= 2) {
      _calculateRoutes(_markerCoordinates); 
    }
  });


  if (_markerCoordinates.length == 1) {
    _mapController?.addCircle(CircleOptions(
      geometry: tappedPoint,
      circleRadius: 10.0,
      circleColor: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
      circleOpacity: 1,
    )).then((circle) {
      _circles.add(circle); 
    });
  }
}



void _onPolylineClicked(LatLng tappedPoint) {
  if (_routePoints.isNotEmpty) {
    LatLng nearestPoint = _findNearestPointOnPolyline(tappedPoint, _routePoints);

    _mapController?.addCircle(CircleOptions(
      geometry: nearestPoint,
      circleRadius: 8.0,
      circleColor: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
      circleOpacity: 1,
    )).then((circle) {
      setState(() {
        _dropOffPoints.add(circle); 
        _dropOffCoordinates.add(nearestPoint); 
      });
    });
  }
}


LatLng _findNearestPointOnPolyline(LatLng point, List<LatLng> polyline) {
  double minDistance = double.infinity;
  LatLng nearestPoint = polyline.first;

  for (LatLng p in polyline) {
    double distance = _calculateDistance(point, p);
    if (distance < minDistance) {
      minDistance = distance;
      nearestPoint = p;
    }
  }

  return nearestPoint;
}


double _calculateDistance(LatLng p1, LatLng p2) {
  const double earthRadius = 6371000; 
  double dLat = (p2.latitude - p1.latitude) * (3.141592653589793 / 180);
  double dLon = (p2.longitude - p1.longitude) * (3.141592653589793 / 180);
  
  double a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(p1.latitude * (3.141592653589793 / 180)) * cos(p2.latitude * (3.141592653589793 / 180)) *
      sin(dLon / 2) * sin(dLon / 2); 
  double c = 2 * atan2(sqrt(a), sqrt(1 - a)); 
  return earthRadius * c; 
}

 Future<void> _calculateRoutes(List<LatLng> markers) async {
  if (markers.length < 2) return; 

  try {
    List<LatLng> routePoints = await _routeService.getRouteForCreation(markers);
    
    setState(() {
      _routePoints = routePoints; 
      _drawRoutes(); 
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching route: $e')),
    );
  }
}



  void _drawRoutes() {
  _mapController?.clearLines(); 

  if (_routePoints.length < 2) return; 

  _mapController?.addLine(LineOptions(
    geometry: _routePoints,
    lineColor: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
    lineWidth: 5.0,
    lineOpacity: 0.8,
  ));
}




void _saveTerminal() async {
  final terminalName = _terminalNameController.text.trim();

  // Create routes from markers
  await _createRouteFromMarkers();

  final hasRoutes = _routes.isNotEmpty;
  final hasRoutePoints = hasRoutes && _routes.first.points.isNotEmpty;

  // Debugging prints
  print('Terminal Name: $terminalName');
  print('Has Routes: $hasRoutes');
  if (hasRoutes) {
    print('First Route Points: ${_routes.first.points}');
  }

  if (terminalName.isNotEmpty && hasRoutes && hasRoutePoints) {
    GeoPoint firstPoint = GeoPoint(
      _routes.first.points.first.latitude,
      _routes.first.points.first.longitude,
    );

    // Get the image URL for the selected terminal type
    String terminalImageUrl = _terminalTypeImageUrls[_selectedTerminalType] ?? '';

    // Prepare terminal data
    final terminalData = {
      'name': terminalName,
      'iconImage': terminalImageUrl,
      'landmarkCoordinates': {
        'latitude': firstPoint.latitude,
        'longitude': firstPoint.longitude,
      },
      'points': [firstPoint],
      'terminalImage': '', // Placeholder for terminal image URL
    };

    // Save terminal data first
    await _firestore.collection('terminals').doc(terminalName).set(terminalData);

    // Check if terminal image URL is provided
    if (_terminalImageController.text.isNotEmpty) {
      String terminalImageUrl = _terminalImageController.text.trim();
      await _firestore.collection('terminals').doc(terminalName).update({
        'terminalImage': terminalImageUrl, // Update with the existing URL
      });
    } else {
      // Throw an error if no terminal image URL is provided
      print('Error: No terminal image URL provided.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a terminal image URL.')),
      );
      return; // Exit the method early
    }

    // Upload routes to Firestore under the terminal
    final terminalRef = _firestore.collection('terminals').doc(terminalName);

    for (var route in _routes) {
      // Ensure route.name is not empty
      if (route.name.isEmpty) {
        print('Error: Route name is empty, skipping this route.');
        continue; // Skip saving this route if the name is empty
      }

      // Create route data
      List<GeoPoint> routePoints = route.points.map((p) => GeoPoint(p.latitude, p.longitude)).toList();

      // Only include the first point, user-defined drop-off points, and the last point
      List<GeoPoint> dropOffPoints = [
        GeoPoint(routePoints.first.latitude, routePoints.first.longitude),
        ..._dropOffCoordinates.map((coord) => GeoPoint(coord.latitude, coord.longitude)),
        GeoPoint(routePoints.last.latitude, routePoints.last.longitude),
      ];

      // Create route data
      Map<String, dynamic> routeData = {
        'name': route.name, // Store the route name in the document
        'color': route.color,
        'points': routePoints,
        'dropOffPoints': dropOffPoints, // Updated drop-off points
      };

      // Debugging
      print('Saving route: ${route.name}, Points: ${routeData['points']}, Drop-Off Points: $dropOffPoints');

      // Check if route image URL is provided
      if (_routeImageController.text.isNotEmpty) {
        String routeImageUrl = _routeImageController.text.trim();
        routeData['routeImage'] = routeImageUrl; // Use existing URL
      } else {
        // Throw an error if no route image URL is provided
        print('Error: No route image URL is provided for route ${route.name}.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please provide a route image URL for ${route.name}.')),
        );
        return; // Exit the method early
      }

      // Save route data in a sub-collection named 'routes'
      await terminalRef.collection('routes').doc(route.name).set(routeData);
    }

    // Clear inputs and reset state
    setState(() {
      _terminalNameController.clear();
      _terminalTypeController.clear();
      _terminalImageController.clear(); // Clear terminal image URL
      _routeImageController.clear(); // Clear route image URL
      _routes.clear();
      _routePoints.clear();
      _markers?.clear();
      _dropOffCoordinates.clear(); // Clear user-defined drop-off coordinates
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Terminal saved successfully!')),
    );
  } else {
    // Add detailed logging for debugging
    if (terminalName.isEmpty) {
      print('Error: Terminal name is empty.');
    }
    if (!hasRoutes) {
      print('Error: No routes available.');
    }
    if (hasRoutes && !hasRoutePoints) {
      print('Error: First route has no points.');
    }

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
  if (_isColorPickerOpen) return; // Prevent map tapping if the color picker is open

  // Existing functionality for markers and polylines
  if (_routePoints.isNotEmpty) {
    bool isNearPolyline = _isPointNearPolyline(tappedPoint, _routePoints, 20.0);
    
    if (isNearPolyline) {
      _onPolylineClicked(tappedPoint);
    } else {
      _addMarker(tappedPoint);
    }
  } else {
    _addMarker(tappedPoint);
  }
}





  bool _isPointNearPolyline(LatLng point, List<LatLng> polyline, double threshold) {
  for (LatLng polyPoint in polyline) {
    if (_calculateDistance(point, polyPoint) <= threshold) {
      return true; // The point is near the polyline
    }
  }
  return false; // The point is not near the polyline
}

  void _undoLastMarker() {
  if (_markerCoordinates.isNotEmpty) {
    // Check if any markers are on the polyline
    bool hasMarkersOnPolyline = _markerCoordinates.any((marker) => _routePoints.contains(marker));

    if (hasMarkersOnPolyline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please clear drop-off points first!')),
      );
      return;
    }

    // Remove the last marker and circle
    _markerCoordinates.removeLast();
    if (_markers!.isNotEmpty) {
      _mapController?.removeSymbol(_markers!.removeLast());
    }

    // Update _routePoints based on the remaining markers
    _routePoints.clear();
    _routePoints.addAll(_markerCoordinates);

    if (_markerCoordinates.isNotEmpty) {
      _drawRoutes();
      if (_markerCoordinates.length >= 2) {
        _calculateRoutes(_markerCoordinates);
      } else {
        _mapController?.clearLines();
      }
    } else {
      _mapController?.clearLines();
    }
  }
}

  Future<void> _createRouteFromMarkers() async {
  if (_markerCoordinates.length < 2) return; // Need at least two points for a route

  try {
    // Request the route using the route service
    List<LatLng> routePoints = await _routeService.getRouteForCreation(_markerCoordinates);

    // Create a new route object with drop-off points
    custom.Route newRoute = custom.Route(
      name: _routeNameController.text.trim(),
      color: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
      points: routePoints,
      dropOffPoints: _dropOffCoordinates, // Include drop-off points
    );

    // Add the newly created route to the _routes list
    setState(() {
      _routes.add(newRoute);
    });

    // Optionally draw the route on the map
    _drawRoutes();
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error creating route: $e')),
    );
  }
}


  void _clearAllMarkers() {
  if (_markerCoordinates.isNotEmpty) {
    bool hasMarkersOnPolyline = _markerCoordinates.any((marker) => _routePoints.contains(marker));

    if (hasMarkersOnPolyline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please clear drop-off points first!')),
      );
    } else {
      setState(() {
        _markerCoordinates.clear();
        _routePoints.clear();
        _markers?.forEach((marker) => _mapController?.removeSymbol(marker));
        _markers?.clear();
        _mapController?.clearLines();
      });
    }
  }
}


void _undoLastDropOff() {
  if (_dropOffCoordinates.isNotEmpty) {
    _mapController?.removeCircle(_dropOffPoints.removeLast());
    _dropOffCoordinates.removeLast();
    setState(() {});
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No drop-off points to undo!')),
    );
  }
}


void _clearAllDropOffPoints() {
  setState(() {
    _dropOffPoints.forEach((circle) => _mapController?.removeCircle(circle));
    _dropOffPoints.clear();
    _dropOffCoordinates.clear();
  });
}


  void _selectColor() async {
  setState(() {
    _isColorPickerOpen = true; // Set the flag to true when opening the color picker
  });

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
    _isColorPickerOpen = false; // Reset the flag after closing the picker
    _drawRoutes();
  });
}


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Add Terminal'),
    ),
    body: Row(
      children: [
        // Map View Section
        Expanded(
          flex: 3,
          child: Container(
            child: MapboxMap(
              accessToken: _accessToken.mapboxaccesstoken,
              onMapCreated: _onMapCreated,
              onMapClick: (point, latLng) => _onMapTapped(latLng),
              styleString: "mapbox://styles/mapbox/streets-v11",
              initialCameraPosition: CameraPosition(
                target: LatLng(14.7954, 121.0524),
                zoom: 12,
              ),
            ),
          ),
        ),

        // Form and Controls Section
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add the image above the Terminal Name field
                Center(
                  child: Image.asset(
                    'assets/logo2.png',
                    height: 250,
                  ),     
                ),
                SizedBox(height: 5),
                Center (
                  child: Text(
                    'Add a terminal',
                    style: TextStyle(fontSize: 18),
                  ),
                  ),
                SizedBox(height: 20), // Space between the image and Terminal Name field

                // Terminal Name
                TextField(
                  controller: _terminalNameController,
                  decoration: InputDecoration(labelText: 'Terminal Name'),
                ),

                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _pickImageForTerminal,
                  child: Text('Upload Terminal Image'),
                ),

                TextField(
                  controller: _terminalImageController,
                  decoration: InputDecoration(labelText: 'Terminal Image URL (auto-filled)'),
                  readOnly: true, // Make it read-only
                ),

                DropdownButtonFormField<String>(
                    value: _selectedTerminalType,
                    decoration: InputDecoration(labelText: 'Terminal Type'),
                    items: [
                      DropdownMenuItem(
                        value: 'jeep',
                        child: Text('Jeep'),
                      ),
                      DropdownMenuItem(
                        value: 'ejeep',
                        child: Text('E-Jeep'),
                      ),
                      DropdownMenuItem(
                        value: 'jeepejeep',
                        child: Text('Jeep & E-Jeep'),
                      ),
                      DropdownMenuItem(
                        value: 'bus',
                        child: Text('Bus'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTerminalType = value;
                      });
                    },
                  ),

                // Route Name
                TextField(
                  controller: _routeNameController,
                  decoration: InputDecoration(labelText: 'Route Name'),
                ),

                SizedBox(height: 20),

                // Route Image Upload Button
                ElevatedButton(
                  onPressed: _pickImageForRoute,
                  child: Text('Upload PUV Image'),
                ),

                TextField(
                  controller: _routeImageController,
                  decoration: InputDecoration(labelText: 'PUV Image URL (auto-filled)'),
                  readOnly: true, // Make it read-only
                ),

                // Create two columns for buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Left Column
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _saveTerminal,
                          child: Text('Save Terminal'),
                        ),
                        SizedBox(height: 10), // Space between buttons
                        ElevatedButton(
                          onPressed: _selectColor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _routeColor, // Set button color based on selected color
                          ),
                          child: Text('Select Route Color'),
                        ),
                      ],
                    ),
                    SizedBox(width: 20), // Space between columns
                    // Right Column
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _undoLastMarker,
                          child: Text('Undo Last Marker'),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _clearAllMarkers,
                          child: Text('Clear All Markers'),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _undoLastDropOff,
                          child: Text('Undo Last Drop-off'),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _clearAllDropOffPoints,
                          child: Text('Clear Drop-off Points'),
                        ),
                      ],
                    ),
                  ],
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