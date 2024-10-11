import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../models/terminal.dart' as tmodel;
import '../services/map_controller.dart';
import '../tokens/tokens.dart';
import 'image_picker_web.dart' if (dart.library.io) 'image_picker_io.dart';

class ModifyTerminalPage extends StatefulWidget {
  final MapController mapController;

  const ModifyTerminalPage({Key? key, required this.mapController}) : super(key: key);
  
  @override
  _ModifyTerminalPageState createState() => _ModifyTerminalPageState();
}

class _ModifyTerminalPageState extends State<ModifyTerminalPage> {
  late MapboxMapController _mapboxMapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _terminals = [];
  List<String> _routes = [];
  List<LatLng> _dropOffPoints = [];
  List<LatLng> _routePoints = [];
  String? _selectedTerminal;
  String? _selectedRoute;
  String? _selectedTerminalType;
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newTypeController = TextEditingController();
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _routeColorController = TextEditingController();
  final TextEditingController _terminalImageController = TextEditingController();
  final TextEditingController _routeImageController = TextEditingController();
  
  List<LatLng> _markerCoordinates = [];
  List<Symbol>? _markers = [];
  List<Circle> _dropOffPointCircles = [];
  
  final List<LatLng> _circles = [];
  bool _isAddingMarkers = false; 
  bool _isAddingDropOffPoints = false;
  bool _showMarkerManagementButtons = false; 
  bool _showDropOffButtons = false; 
  Color _routeColor = Colors.red; 
  bool _isAddingRoute = false;
  bool _isModifyingRoute = false;
  LatLng? _terminalLocation; // Store the terminal location


  final AccessToken _accessToken = AccessToken();

  @override
  void initState() {
    super.initState();
    _fetchTerminals();
  }

  void _onMapCreated(MapboxMapController controller) async {
    _mapboxMapController = controller;
    widget.mapController.setMapController(controller); 
    final Uint8List image = await _loadImage("assets/pin.png");
    _mapboxMapController.addImage("custom-pin", image);
  }

  Future<Uint8List> _loadImage(String path) async {
    ByteData byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
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

  Future<void> _addCircle(LatLng location) async {
    await _mapboxMapController.addCircle(
      CircleOptions(
        geometry: location,
        circleColor: _routeColor.value.toRadixString(16).substring(2, 8),
        circleRadius: 10,
        circleStrokeColor: _routeColor.value.toRadixString(16).substring(2, 8), 
        circleStrokeWidth: 2,
      ),
    );
    _circles.add(location);
  }

  Future<void> _clearCircles() async {
    
    _dropOffPointCircles.clear();
    _dropOffPoints.clear();
    
  }

  void _addDropOffPoint() {
  setState(() {
    _isAddingDropOffPoints = !_isAddingDropOffPoints; // Toggle the flag
  });

  if (_isAddingDropOffPoints) {
    print("You can now click on the polyline to add drop-off points.");
  } else {
    print("Drop-off point adding mode disabled.");
  }
}


  void _addMarker(LatLng tappedPoint) {
  if (_markerCoordinates.isEmpty || _markerCoordinates.first != tappedPoint) {
    setState(() {
      _markerCoordinates.add(tappedPoint);
    });

    _mapboxMapController.addSymbol(SymbolOptions(
      geometry: tappedPoint,
      iconImage: "custom-pin",
      iconSize: 0.1,
    )).then((symbol) {
      _markers?.add(symbol);
      _createPolyline(); // Update polyline with each marker added
    });
  }
}

 Future<void> _undoLastMarker() async {
  if (_markerCoordinates.isNotEmpty && _markers!.isNotEmpty) {
    setState(() {
      // Remove the last marker coordinate
      _markerCoordinates.removeLast();
    });

    Symbol lastMarker = _markers!.removeLast();
    await _mapboxMapController.removeSymbol(lastMarker);

    // Clear all existing polylines on the map
    await _mapboxMapController.clearLines();

    // Recreate the polyline with the updated marker list, always starting from terminal location
    await _createPolyline();
  } else {
    print("No markers to undo.");
  }
}

void _clearMarkers() async {
  setState(() {
    _markerCoordinates.clear();
    for (Symbol marker in _markers!) {
      _mapboxMapController.removeSymbol(marker);
    }
    _markers!.clear();
  });
  await _mapboxMapController.clearLines();
  // Create polyline with the terminal location as the starting point
  await _createPolyline();
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
  void _fetchTerminals() async {
    final snapshot = await _firestore.collection('terminals').get();
    setState(() {
      _terminals = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  void _fetchTerminalDetails(String terminalId) async {
  final terminalDoc = await _firestore.collection('terminals').doc(terminalId).get();
  final terminalData = terminalDoc.data();

  if (terminalData != null) {
    setState(() {
      _newNameController.text = terminalData['name'] ?? '';
      _newTypeController.text = terminalData['iconImage'] ?? '';
      
      // Store terminal location
      var pointsData = terminalData['points'] ?? [];
      if (pointsData is List && pointsData.isNotEmpty) {
        GeoPoint firstPoint = pointsData[0];
        _terminalLocation = LatLng(firstPoint.latitude, firstPoint.longitude);
      }
    });

    final routesSnapshot = await _firestore.collection('terminals').doc(terminalId).collection('routes').get();
    setState(() {
      _routes = routesSnapshot.docs.map((doc) => doc.id).toList();
    });

    var pointsData = terminalData['points'] ?? [];
    if (pointsData is List && pointsData.isNotEmpty) {
      GeoPoint firstPoint = pointsData[0];
      LatLng terminalLatLng = LatLng(firstPoint.latitude, firstPoint.longitude);

      await _clearCircles();
      await _addCircle(terminalLatLng); // Create circle at terminal location

      // Add terminal location as the first marker
      _markerCoordinates.insert(0, terminalLatLng);

      await _mapboxMapController.animateCamera(
        CameraUpdate.newLatLngZoom(terminalLatLng, 14),
      );

      for (var point in pointsData) {
        if (point is GeoPoint) {
          LatLng latLng = LatLng(point.latitude, point.longitude);
          await _addCircle(latLng);
        }
      }
    }
  }
}

  

  void _onTerminalSelected(String? terminalId) {
    setState(() {
      _selectedTerminal = terminalId;
      if (terminalId != null) {
        widget.mapController.clearCurrentPolylines();
        _clearCircles();
        _fetchTerminalDetails(terminalId);
      } else {
        _routes.clear();
        widget.mapController.clearCurrentPolylines();
        _clearCircles();
      }
    });
  }

  void _onRouteSelected(String? routeId) {
    setState(() {
      _selectedRoute = routeId;
      if (_selectedTerminal != null && routeId != null) {
        _fetchRouteDetails(_selectedTerminal!, routeId);
      }
    });
  }

  Future<void> _fetchRouteDetails(String terminalId, String routeId) async {
    final routeDoc = await _firestore
        .collection('terminals')
        .doc(terminalId)
        .collection('routes')
        .doc(routeId)
        .get();

    final routeData = routeDoc.data();
    if (routeData != null) {
      tmodel.Route route = tmodel.Route.fromFirestore(routeData);
      await widget.mapController.displayRoute(route);

      if (route.points.isNotEmpty) {
        double totalLat = 0;
        double totalLng = 0;
        for (LatLng point in route.points) {
          totalLat += point.latitude;
          totalLng += point.longitude;
        }
        double centerLat = totalLat / route.points.length;
        double centerLng = totalLng / route.points.length;
        LatLng centerPoint = LatLng(centerLat, centerLng);

        await _mapboxMapController.animateCamera(
          CameraUpdate.newLatLngZoom(centerPoint, 14),
        );
      }
    }
  }



  void _onMapTapped(LatLng latLng) {
  if (_isAddingMarkers) {
    _addMarker(latLng);
  } else if (_isAddingDropOffPoints) {
    _onPolylineClicked(latLng); // Call to add drop-off point
  } 
}

  void _toggleAddMarkersMode() {
  setState(() {
    _isAddingMarkers = !_isAddingMarkers;
  });
}


  void _finishAddingMarkers() async {
    setState(() {
      _isAddingMarkers = false;
      _showDropOffButtons = true; // Show drop-off buttons after finishing adding markers
    });

    await _createPolyline(); // Use current marker coordinates
  }



  // Method to create a polyline on the map from added markers
 Future<void> _createPolyline() async {
  if (_markerCoordinates.isEmpty) return; 


  List<LatLng> routePoints = [_terminalLocation!];
  routePoints.addAll(_markerCoordinates);

  // Clear any existing polyline
  await widget.mapController.clearCurrentPolylines();

  try {
    List<LatLng> finalRoutePoints = await widget.mapController.routeService.getRoute(routePoints);

    // Assign the route points to the _routePoints variable
    _routePoints = finalRoutePoints;
    print("Final route points are $_routePoints");

    if (finalRoutePoints.isNotEmpty) {
      await _mapboxMapController.addLine(LineOptions(
        geometry: finalRoutePoints,
        lineColor: _routeColor.value.toRadixString(16).substring(2, 8),
        lineWidth: 5.0,
      ));
    }
  } catch (e) {
    print("Error creating polyline: $e");
  }
}




void _clearLastDropOffPoint() {
  if (_dropOffPoints.isNotEmpty) {
    _mapboxMapController.removeCircle(_dropOffPointCircles.removeLast());
    _dropOffPoints.removeLast();
    setState(() {});
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No drop-off points to undo!')),
    );
  }
}

void _clearAllDropOffPoints() {
  setState(() {
    _dropOffPointCircles.forEach((circle) => _mapboxMapController.removeCircle(circle));
    _dropOffPointCircles.clear();
    _dropOffPoints.clear();
  });
}

void _onPolylineClicked(LatLng tappedPoint) {
  if (_routePoints.isNotEmpty) {
    LatLng nearestPoint = _findNearestPointOnPolyline(tappedPoint, _routePoints);

    // Check if the distance to the nearest point is within a specified threshold
    double distanceToNearest = _calculateDistance(tappedPoint, nearestPoint);
    print("Tapped Point: $tappedPoint, Nearest Point: $nearestPoint, Distance: $distanceToNearest");

    if (distanceToNearest < 20 ) { // Adjust threshold as necessary
      _mapboxMapController.addCircle(CircleOptions(
        geometry: nearestPoint,
        circleRadius: 8.0,
        circleColor: '#${_routeColor.value.toRadixString(16).substring(2, 8)}',
        circleOpacity: 1,
      )).then((circle) {
        setState(() {
          _dropOffPoints.add(nearestPoint); 
          _dropOffPointCircles.add(circle); 
          print (_dropOffPoints);
        });
      });
    } else {
      print("Tap not near any polyline point.");
    }
  }
}

  LatLng _findNearestPointOnPolyline(LatLng point, List<LatLng> polyline) {
  double minDistance = double.infinity;
  LatLng nearestPoint = polyline.first;

  for (LatLng p in polyline) {
    double distance = _calculateDistance(point, p);
    print("Checking Point: $p, Distance: $distance");
    if (distance < minDistance) {
      minDistance = distance;
      nearestPoint = p;
    }
  }

  return nearestPoint;
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
  });
}



 void _toggleAddingRoute() {
    setState(() {
      _isAddingRoute = true;
      _isModifyingRoute = false;
      _showMarkerManagementButtons = true; // Show marker buttons
    });
  }

  void _toggleModifyingRoute() {
    setState(() {
      _isModifyingRoute = true;
      _isAddingRoute = false;
      _showMarkerManagementButtons = true; // Show marker buttons
    });
  }

 Future<void> _saveOrUpdateTerminalAndRoute(String terminalId, {String? routeId}) async {
  try {
    // Prepare terminal data
    Map<String, dynamic> terminalData = {
      'name': _newNameController.text,
      'terminalImage': _terminalImageController.text, // Include terminal image URL
      'iconImage': _terminalTypeImageUrls[_selectedTerminalType], // Get icon image based on selected terminal type
    };

    // Update or create terminal data
    await _firestore.collection('terminals').doc(terminalId).set(terminalData, SetOptions(merge: true));

    // Prepare route points
    List<GeoPoint> routePoints = _routePoints.map((point) => GeoPoint(point.latitude, point.longitude)).toList();

    // Prepare drop-off points based on route points
    List<GeoPoint> dropOffPoints = [];
    if (routePoints.isNotEmpty) {
      dropOffPoints.add(routePoints.first); // First point from route as first drop-off point
      dropOffPoints.add(routePoints.last);  // Last point from route as last drop-off point
    }

    // Save drop-off points to Firestore
    await _firestore.collection('terminals').doc(terminalId).set({
      'dropOffPoints': dropOffPoints, // Store drop-off points based on route points
    }, SetOptions(merge: true));

    // Prepare route data
    Map<String, dynamic> routeData = {
      'name': _routeNameController.text,
      'color': _routeColor.value.toRadixString(16).substring(2, 8),
      'dropOffPoints': dropOffPoints, // Include drop-off points in route data if needed
      'routeImage': _routeImageController.text, // Include route image URL
      'routePoints': routePoints, // Save route points
    };

    if (routeId != null) {
      // Overwrite existing route data if routeId is provided
      await _firestore.collection('terminals').doc(terminalId).collection('routes').doc(routeId).set(routeData);
      print("Terminal and route data overwritten successfully.");
    } else {
      // Add new route if no routeId is provided
      await _firestore.collection('terminals').doc(terminalId).collection('routes').add(routeData);
      print("Terminal updated and new route added successfully.");
    }
  } catch (e) {
    print("Error saving or updating terminal and route data: $e");
  }
}


void _onSavePressed() async {
  if (_selectedTerminal != null) {
    // Save or update terminal and route data
    await _saveOrUpdateTerminalAndRoute(_selectedTerminal!, routeId: _selectedRoute);
    
    // Clear all fields
    _newNameController.clear();
    _newTypeController.clear();
    _routeNameController.clear();
    _routeColorController.clear();
    _dropOffPoints.clear(); // Clear drop-off points

    await _clearMarkers; 
    await _clearAllDropOffPoints; 

    setState(() {
      _selectedTerminal = null;
      _selectedRoute = null;
      _markerCoordinates.clear(); 
    });

    // Feedback for successful save
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data saved successfully!')),
    );
  } else {
    // Handle case where no terminal is selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please select a terminal first.')),
    );
  }
}



 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Modify Terminal'),
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
                  // Terminal Dropdown
                  DropdownButton<String>(
                    value: _selectedTerminal,
                    hint: Text('Select Terminal'),
                    onChanged: (value) {
                      _onTerminalSelected(value);
                    },
                    items: _terminals.map((terminal) {
                      return DropdownMenuItem(
                        value: terminal,
                        child: Text(terminal),
                      );
                    }).toList(),
                  ),

                  // New Name
                  TextField(
                    controller: _newNameController,
                    decoration: InputDecoration(labelText: 'New Name'),
                  ),

                  // Terminal Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedTerminalType,
                    decoration: InputDecoration(labelText: 'Terminal Type'),
                    items: [
                      DropdownMenuItem(value: 'jeep', child: Text('Jeep')),
                      DropdownMenuItem(value: 'ejeep', child: Text('E-Jeep')),
                      DropdownMenuItem(value: 'jeepejeep', child: Text('Jeep & E-Jeep')),
                      DropdownMenuItem(value: 'bus', child: Text('Bus')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTerminalType = value;
                      });
                    },
                  ),

                  SizedBox(height: 20),

                    // Route Image Upload Button
                    ElevatedButton(
                      onPressed: _pickImageForTerminal,
                      child: Text('Upload Terminal Image'),
                    ),

                    TextField(
                      controller: _terminalImageController,
                      decoration: InputDecoration(labelText: 'Terminal Image URL (auto-filled)'),
                      readOnly: true, // Make it read-only
                    ),
                    SizedBox(height: 20),
                    // Add Polyline Button

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _toggleAddingRoute,
                        child: Text('Add Route'),
                      ),
                      ElevatedButton(
                        onPressed: _toggleModifyingRoute,
                        child: Text('Modify Existing Route'),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Conditional UI for adding/modifying routes
                  if (_isModifyingRoute) ...[
                    // Route Dropdown
                    DropdownButton<String>(
                      value: _selectedRoute,
                      hint: Text('Select Route'),
                      onChanged: (value) {
                        _onRouteSelected(value);
                      },
                      items: _routes.map((route) {
                        return DropdownMenuItem(
                          value: route,
                          child: Text(route),
                        );
                      }).toList(),
                    ),

                    // Route Name
                    TextField(
                      controller: _routeNameController,
                      decoration: InputDecoration(labelText: 'Route Name'),
                    ),
                    Row (
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                      onPressed: _selectColor,
                      child: Text('Select Route Color'),
                    ),

                    // Modify Polyline Button
                    ElevatedButton(
                      onPressed: () {
                        _mapboxMapController.clearLines();
                        _toggleAddMarkersMode();
                      },
                      child: Text('Modify Existing Polyline'),
                    ),
                      ],
                    )
                    // Route Color
                    
                  ] else if (_isAddingRoute) ...[
                    // Route Name for Adding
                    TextField(
                      controller: _routeNameController,
                      decoration: InputDecoration(labelText: 'Route Name'),
                    ),
                     SizedBox(height: 20),
                    // Route Color
                    ElevatedButton(
                      onPressed: _selectColor,
                      child: Text('Select Route Color'),
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
                    SizedBox(height: 20),
                    // Add Polyline Button
                    ElevatedButton(
                      onPressed: () {
                        _mapboxMapController.clearLines();
                        _toggleAddMarkersMode();
                      },
                      child: Text('Add New Polyline'),
                    ),
                  ],
                  SizedBox(height: 20),
                  // Marker Management Buttons
                  if (_showMarkerManagementButtons && !_isAddingDropOffPoints) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _markerCoordinates.isNotEmpty ? _undoLastMarker : null,
                          child: Text('Undo Last Marker'),
                        ),
                        ElevatedButton(
                          onPressed: _clearMarkers, // Clear all markers from the map
                          child: Text('Remove All Markers'),
                        ),
                        ElevatedButton(
                          onPressed: _finishAddingMarkers,
                          child: Text('Finish Adding Markers'),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 20),
                  // Drop Off Management Buttons
                  if (_showDropOffButtons) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _addDropOffPoint,
                          child: Text(_isAddingDropOffPoints ? 'Stop Adding Drop-Off Points' : 'Add Drop-Off Point'),
                        ),
                        ElevatedButton(
                          onPressed: _clearLastDropOffPoint,
                          child: Text('Clear Last Drop-Off Point'),
                        ),
                        ElevatedButton(
                          onPressed: _clearAllDropOffPoints,
                          child: Text('Clear All Drop-Off Points'),
                        ),
                      ],
                    ),

                    Row (
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _onSavePressed,
                          child: Text ('Save Data')
                        )
                      ]
                    )
                  ],

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
