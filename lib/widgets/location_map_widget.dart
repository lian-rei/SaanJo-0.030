import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../tokens/tokens.dart';

class MapLocationPicker extends StatefulWidget {
  @override
  _MapLocationPickerState createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  LatLng? _selectedLocation;
  MapboxMapController? _mapController;
  final AccessToken _accessToken = AccessToken();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Your Location'),
      ),
      body: Center( // Center the entire content
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Make the map smaller
            Container(
              width: MediaQuery.of(context).size.width * 0.9, // Adjust width here
              height: MediaQuery.of(context).size.height * 0.6, // Adjust height here
              child: MapboxMap(
                accessToken: _accessToken.mapboxaccesstoken,
                onMapCreated: _onMapCreated,
                onMapClick: (point, LatLng latLng) {
                  _onMapTapped(latLng);
                },
                styleString: "mapbox://styles/mapbox/streets-v11",
                initialCameraPosition: CameraPosition(
                  target: LatLng(14.7954, 121.0524),
                  zoom: 12,
                ),
              ),
            ),
            // Space between the map and the button
            SizedBox(height: 20),
            // Button centered below the map
            if (_selectedLocation != null)
              ElevatedButton(
                onPressed: _confirmLocation,
                child: Text('Confirm Location'),
              ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
  }

  void _onMapTapped(LatLng point) async {
    setState(() {
      _selectedLocation = point;
    });

    // Clear all existing circles
    await _mapController?.clearCircles(); // If this method exists to clear circles

    // Add a new circle
    await _mapController!.addCircle(
      CircleOptions(
        geometry: point,
        circleColor: '#FF0000',
        circleRadius: 10.0,
        circleOpacity: 0.8,
      ),
    );
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Confirm Location'),
            content: Text('You selected: (${_selectedLocation!.latitude}, ${_selectedLocation!.longitude})'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(_selectedLocation);
                },
                child: Text('Confirm'),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a location on the map.')),
      );
    }
  }
}
