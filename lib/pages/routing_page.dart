import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../services/map_controller.dart';
import '../tokens/tokens.dart';
import '../models/terminal.dart' as terminal_models;
import '../services/routing_controller.dart'; // Import your RoutingController
import 'dart:async';

class RoutingPage extends StatefulWidget {
  final MapController mapController;

  RoutingPage({Key? key, required this.mapController}) : super(key: key);

  @override
  _RoutingPageState createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  late MapController _mapController;
  late RoutingController _routingController; // Create an instance of RoutingController
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 2;
  List<terminal_models.Terminal> _terminals = [];
  List<dynamic> _placeSuggestions = [];
  TextEditingController _searchController = TextEditingController();
  LatLng? _userSelectedPosition;
  Position? _currentPosition;
  Timer? _debounce;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController;
    _routingController = RoutingController(_mapController); // Initialize RoutingController
    if (!kIsWeb) {
      _mapController.initializeLocationService();
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

    // Fetch terminals after getting the current position
    await _routingController.fetchTerminals();
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
          _placeSuggestions = suggestions; // Update the suggestions list
          _isSearchActive = true; // Set search active
        });
      } else {
        setState(() {
          _placeSuggestions = []; // Clear suggestions if query is empty
          _isSearchActive = false; // Reset search active
        });
      }
    });
  }

  Future<void> _routeToDestination(LatLng destination) async {
    LatLng? currentLatLng = await _routingController.getUserLocation();

    if (currentLatLng == null) {
      // Show an error message if the location could not be obtained
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get your location.')),
      );
      return;
    }

    String accessToken = AccessToken().mapboxaccesstoken;
    await _routingController.routeToDestination(currentLatLng, destination, accessToken);
  }

  // Update the onMapClick to check if search is active
  void _onMapClick(LatLng coordinates) {
    if (_isSearchActive) {
      setState(() {
        _userSelectedPosition = coordinates; // Update selected position
      });
      // Optionally, route to the destination
      _routeToDestination(coordinates);
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
              child: Container(
                height: 200,
                child: ListView.builder(
                  itemCount: _placeSuggestions.length,
                  itemBuilder: (context, index) {
                    var suggestion = _placeSuggestions[index];
                    return ListTile(
                      title: Text(suggestion['place_name']),
                      onTap: () {
                        setState(() {
                          _userSelectedPosition = LatLng(suggestion['geometry']['coordinates'][1], suggestion['geometry']['coordinates'][0]);
                        });
                        _routeToDestination(_userSelectedPosition!); // Start routing
                      },
                    );
                  },
                ),
              ),
            ),

          // Mapbox Map positioned below the search box and suggestions
          Positioned(
            top: _placeSuggestions.isNotEmpty ? 280 : 80,
            left: 0,
            right: 0,
            bottom: 0,
            child: MapboxMap(
              accessToken: AccessToken().mapboxaccesstoken,
              styleString: 'mapbox://styles/mapbox/streets-v11',
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 14.0,
              ),
              onMapCreated: (controller) {
                _mapController.onMapCreated(controller);
                _mapController.onStyleLoaded(); // Load terminal markers
              },
              onMapClick: (point, coordinates) {
                _onMapClick(coordinates); // Call the new method
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Navigate based on the selected index if needed
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Catalog'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Terminals'),
          BottomNavigationBarItem(icon: Icon(Icons.directions), label: 'Routing'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
