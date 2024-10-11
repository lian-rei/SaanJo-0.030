import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../services/map_controller.dart';
import '../tokens/tokens.dart';
import '../models/terminal.dart' as terminal_models;
import '../services/routing_controller.dart';
import '../services/fare_service.dart'; // Import the FareService
import 'dart:async';

class RoutingPage extends StatefulWidget {
  final MapController mapController;

  RoutingPage({Key? key, required this.mapController}) : super(key: key);

  @override
  _RoutingPageState createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  late MapController _mapController;
  late RoutingController _routingController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 2;
  List<terminal_models.Terminal> _terminals = [];
  List<dynamic> _placeSuggestions = [];
  TextEditingController _searchController = TextEditingController();
  LatLng? _userSelectedPosition;
  Position? _currentPosition;
  Timer? _debounce;
  bool _isSearchActive = false;
  terminal_models.Terminal? _selectedTerminal;
  double? _routeLength;
  List<double>? _fare; // Variable to hold the calculated fare
  final FareService _fareService = FareService(); // Instance of FareService
  String? _routeName; // Variable to hold the route name

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController;
    _routingController = RoutingController(_mapController);
    if (!kIsWeb) {
     
    }
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    Position position = kIsWeb
        ? Position(
            latitude: 14.8136,
            longitude: 121.0450,
            timestamp: DateTime.now(),
            accuracy: 5.0,
            altitude: 0.0,
            altitudeAccuracy: 5.0,
            heading: 0.0,
            headingAccuracy: 5.0,
            speed: 0.0,
            speedAccuracy: 5.0,
          )
        : await _mapController.locationService.determinePosition();

    setState(() {
      _currentPosition = position;
      _userSelectedPosition = LatLng(position.latitude, position.longitude);
    });

    await _routingController.fetchTerminals(); // Fetch terminals from Firestore

    // Find the nearest terminal after fetching terminals
   terminal_models.Terminal? nearestTerminal = await _routingController.findNearestTerminal(
  LatLng(_currentPosition!.latitude, _currentPosition!.longitude), // Convert Position to LatLng
  _userSelectedPosition!
  );
    if (nearestTerminal != null) {
      setState(() {
        _selectedTerminal = nearestTerminal; // Set the selected terminal
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.isNotEmpty && _currentPosition != null) {
        List<dynamic> suggestions = await _routingController.fetchPlaceSuggestions(
          query,
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );

        setState(() {
          _placeSuggestions = suggestions;
          _isSearchActive = true;
        });
      } else {
        setState(() {
          _placeSuggestions = [];
          _isSearchActive = false;
        });
      }
    });
  }

  Future<void> _routeToDestination(LatLng destination) async {
  // Get current location
  LatLng? currentLatLng = await _routingController.getUserLocation(context);

  if (currentLatLng == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to get your location.')),
    );
    return;
  }

  String accessToken = AccessToken().mapboxaccesstoken;

  print('Before calling routeToDestination');
  print('After calling routeToDestination');

}

  void _onMapClick(LatLng coordinates) async {
    if (_isSearchActive) {
      setState(() {
        _userSelectedPosition = coordinates;
      });

      // Find the nearest terminal to the clicked coordinates
      terminal_models.Terminal? terminal = await _routingController.findNearestTerminal(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude), // Convert Position to LatLng
      coordinates
    );

      
      if (terminal != null) {
        setState(() {
          _selectedTerminal = terminal; // Set the selected terminal
        });
        _routeToDestination(coordinates); // Continue to route to the destination
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No terminal found at this location.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text('Routing Page')),
      body: Stack(
        children: [
          // Mapbox Map
          Positioned.fill(
            child: MapboxMap(
              accessToken: AccessToken().mapboxaccesstoken,
              styleString: 'mapbox://styles/mapbox/streets-v11',
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 14.0,
              ),
              onMapCreated: (controller) {
                _mapController.onMapCreated(controller);
                _mapController.onStyleLoaded();
              },
              onMapClick: (point, coordinates) {
                _onMapClick(coordinates);
              },
            ),
          ),

          // Search Box
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4.0, offset: Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search places',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ),

          // Suggestion ListView
          if (_placeSuggestions.isNotEmpty)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _placeSuggestions.length,
                      itemBuilder: (context, index) {
                        var suggestion = _placeSuggestions[index];
                        return ListTile(
                          title: Text(suggestion['place_name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(suggestion['address'] ?? 'No address available', style: TextStyle(fontSize: 12)),
                              Text(suggestion['type'] ?? 'Unknown', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _userSelectedPosition = LatLng(
                                suggestion['geometry']['coordinates'][1],
                                suggestion['geometry']['coordinates'][0],
                              );
                              _placeSuggestions = [];
                              _isSearchActive = false; // Optionally set this to false
                            });
                            _routeToDestination(_userSelectedPosition!);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
                  // Floating Terminal Details
          if (_selectedTerminal != null && _routeLength != null && _fare != null)
            Positioned(
              right: 16,
              bottom: 100,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4.0, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedTerminal!.name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    if (_routeName != null)
                      Text(
                        _routeName!, // Display the route name
                        style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    if (_routeLength != null)
                      Text(
                        'Route Length: ${_routeLength!.toStringAsFixed(2)} km',
                        style: TextStyle(fontSize: 14),
                      ),
                    if (_fare != null) // Display fare range if available
                      Text(
                        'Fare: ${_fare![0].toStringAsFixed(2)} to ${_fare![1].toStringAsFixed(2)} pesos',
                        style: TextStyle(fontSize: 14, color: Colors.green),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (index == 1) { // When "Terminals" is selected
          Navigator.pop(context); // Navigate back to the map page
        } else {
          setState(() {
            _currentIndex = index; // Update the current index for other tabs
          });
        }
      },
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Catalog'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Terminals'),
        BottomNavigationBarItem(icon: Icon(Icons.directions), label: 'Routing'),
      ],
    ),
  );
}
}
