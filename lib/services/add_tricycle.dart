import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../tokens/tokens.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTricycleScreen extends StatefulWidget {
  @override
  _AddTricycleScreenState createState() => _AddTricycleScreenState();
}

class _AddTricycleScreenState extends State<AddTricycleScreen> {
  final TextEditingController _todaNameController = TextEditingController();
  List<LatLng> _polygonPoints = [];
  Color _todaColor = Colors.red; // Default color
  late MapboxMapController _mapController;
  List<Circle> _circles = [];
  List<LatLng> _terminalPoints = [];
  AccessToken _accessToken = AccessToken();
  
  int _step = 0; // Step tracker

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
  }

  void _onMapTapped(LatLng latLng) {
    if (_step == 2) { // Adding terminal points
      setState(() {
        _addTerminalPoint(latLng);
      });
    } else if (_step == 3) { // Adding polygon points
      setState(() {
        _polygonPoints.add(latLng);
        _addCircle(latLng);
        _updatePolygon();
      });
    }
  }

  void _addCircle(LatLng latLng) async {
    Circle circle = await _mapController.addCircle(
      CircleOptions(
        geometry: latLng,
        circleRadius: 5.0,
        circleColor: '#${_todaColor.value.toRadixString(16).substring(2, 8)}',
      ),
    );

    _circles.add(circle);
  }

  void _updatePolygon() {
    if (_polygonPoints.isNotEmpty) {
      List<List<LatLng>> coordinates = [_polygonPoints];
      _mapController.addFill(
        FillOptions(
          geometry: coordinates,
          fillColor: '#${_todaColor.value.toRadixString(16).substring(2, 8)}',
          fillOpacity: 0.1,
          fillOutlineColor: '#${_todaColor.value.toRadixString(16).substring(2, 8)}',
        ),
      );
    }
  }

  void _addTerminalPoint(LatLng latLng) {
    _addCircle(latLng);
    _terminalPoints.add(latLng);
  }

  void _undoLastPoint() {
    if (_step == 2 && _terminalPoints.isNotEmpty) {
      _terminalPoints.removeLast();
      _mapController.clearCircles(); // Clear all circles
      for (LatLng point in _terminalPoints) {
        _addCircle(point); // Re-add remaining terminal circles
      }
    } else if (_step == 3 && _polygonPoints.isNotEmpty) {
      _polygonPoints.removeLast();
      
      _updatePolygon(); // Redraw the polygon without the last point
    }
  }

  void _saveTODA() async {
    String todaName = _todaNameController.text.trim();

    if (todaName.isEmpty || _polygonPoints.isEmpty || _terminalPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a TODA name, color, and add points.')),
      );
      return;
    }

    CollectionReference tricycleTerminals = FirebaseFirestore.instance.collection('tricycleterminals');

    await tricycleTerminals.add({
      'name': todaName,
      'polygonPoints': _polygonPoints.map((point) => {'latitude': point.latitude, 'longitude': point.longitude}).toList(),
      'terminalPoints': _terminalPoints.map((point) => {'latitude': point.latitude, 'longitude': point.longitude}).toList(),
    }).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TODA saved successfully!')),
      );

      _resetForm();
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save TODA: $error')),
      );
    });
  }

  void _resetForm() {
    _todaNameController.clear();
    _polygonPoints.clear();
    _terminalPoints.clear();
    _mapController.clearCircles();
    _updatePolygon();
   
    setState(() {
      _circles.clear(); // Clear the circle list
      _step = 0; // Reset to the first step
    });
  }

  void _nextStep() {
    setState(() {
      _step++;
    });
  }

  void _selectColor(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _todaColor,
              onColorChanged: (Color color) {
                setState(() {
                  _todaColor = color;
                });
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _nextStep(); // Proceed to the next step after selecting color
              },
              child: Text('Confirm Color'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add TODA'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
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
          Expanded(
            flex: 2,
            child: Column(
              children: [
                if (_step == 0) ...[
                  TextField(
                    controller: _todaNameController,
                    decoration: InputDecoration(labelText: 'TODA Name'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_todaNameController.text.isNotEmpty) {
                        _nextStep();
                      }
                    },
                    child: Text('Next'),
                  ),
                ] else if (_step == 1) ...[
                  Text('Selected Color: ${_todaColor.toString()}'),
                  ElevatedButton(
                    onPressed: () => _selectColor(context),
                    child: Text('Select Color'),
                  ),
                ] else if (_step == 2) ...[
                  Text('Define Terminal Points (Click on the map to add)'),
                  ElevatedButton(
                    onPressed: _undoLastPoint, // Undo last terminal point
                    child: Text('Undo Last Terminal Point'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _nextStep();
                    },
                    child: Text('Finish Terminal Points and Draw Polygon'),
                  ),
                ] else if (_step == 3) ...[
                  Text('Draw Polygon (Click on the map to add points)'),
                  ElevatedButton(
                    onPressed: _undoLastPoint, // Undo last polygon point
                    child: Text('Undo Last Polygon Point'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _saveTODA();
                    },
                    child: Text('Save TODA'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
