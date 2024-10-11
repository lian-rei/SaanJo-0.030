import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/map_controller.dart';
import '../tokens/tokens.dart';
import '../services/routing_controller.dart'; // Ensure to import RoutingController
import '../services/fare_service.dart'; // Ensure to import FareService
import '../models/terminal.dart' as terminal_models;
import '../pages/place_detail_dialog.dart';
import 'dart:async';
import '../pages/ticket.dart';
class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class MarkerData {
  final Symbol symbol;
  final LatLng position;
  final String name;
  final String address;
  final String type;
  final String imageUrl;

  MarkerData(this.symbol, this.position, this.name, this.address, this.type, this.imageUrl);
}


class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  late MapboxMapController mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<DocumentSnapshot<Object?>>? _userData;
  bool _isDarkMode = false;
  Key _mapKey = UniqueKey();
  Map<String, dynamic> _markerData = {}; // Store marker data for tapped markers
  Map<String, String>? _guestUserData;
  bool _isFloatingWidgetVisible = false;
  Map<String, dynamic>? _floatingWidgetData;
  final AccessToken _accessToken = AccessToken();
  List<LatLng> places = [];
  List<MarkerData> _placeSymbols = [];
  bool _isTicketWidgetVisible = false;

  

  // Routing related variables
  late RoutingController _routingController;
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
    _initializeUserLocation();
    _routingController = RoutingController(_mapController); // Initialize RoutingController
    _mapController.addListener(() {
      setState(() {
        _isFloatingWidgetVisible = _mapController.selectedTerminal != null;
        if (_isFloatingWidgetVisible) {
          _showTerminalDetails();
        }
      });
    });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (arguments != null) {
      setState(() {
        _guestUserData = {'firstName': 'Guest', 'lastName': '', 'username': 'guest_user'};
        _userData = null;
      });
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userData = FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        });
      } else {
        _userData = null;
      }
    }
  });

  // Integrate initializeLocationService directly // This calls your existing method
}

void _toggleTicketWidget() {
    setState(() {
      _isTicketWidgetVisible = !_isTicketWidgetVisible;
    });
  }

Future<void> _initializeUserLocation() async {
  try {
    Position position = await _mapController.initializeLocationService(context);
    setState(() {
      _currentPosition = position;
      _userSelectedPosition = LatLng(position.latitude, position.longitude);
    });
  } catch (e) {
    print('Error initializing location: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to get your location.')),
    );
  }
}

 Future<Map<String, dynamic>?> fetchPlaceDetailsByName(String name) async {
  final String apiKey = 'fsq3rgV6402ofALVKftiTn0po1al4GQstY7LOErKP+J0x9w=';
  final String url = "https://api.foursquare.com/v3/places/search?query=${Uri.encodeComponent(name)}&limit=1";

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': apiKey,
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        final place = data['results'][0];
        return {
          'name': place['name'],
          'address': place['location'] != null ? place['location']['formatted_address'] : 'No address available',
          'type': place['categories'].isNotEmpty ? place['categories'][0]['name'] : 'Unknown',
          'image_url': place['photos'].isNotEmpty ? place['photos'][0]['prefix'] + '300x300' + place['photos'][0]['suffix'] : '',
        };
      }
    } else {
      print('Error fetching place details by name: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching place details by name: $e');
  }
  return null;
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
  LatLng? currentLatLng = await _routingController.getUserLocation(context);
  await _routingController.fetchTerminals();

  if (currentLatLng == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to get your location.')),
    );
    return;
  }

  String accessToken = AccessToken().mapboxaccesstoken;

  // Call the modified routeToDestination method with the context
  await _routingController.routeToDestination(
    currentLatLng,
    destination,
    accessToken,
    context, // Pass context here
  );
}




  Future<void> _showTerminalDetails() async {
    if (_mapController.selectedTerminal != null) {
      final terminal = _mapController.selectedTerminal!;
      try {
        // Fetch terminal address using landmark coordinates
        final address = await _fetchAddressFromCoordinates(terminal.landmarkCoordinates);

        // Set up floating widget data
        setState(() {
          _floatingWidgetData = {
            'name': terminal.name,
            'description': address ?? 'No address available',
            'imageUrl': terminal.terminalImage.isNotEmpty ? terminal.terminalImage : 'default_image_url.jpg',
          };
        });

      } catch (e) {
        print('Error fetching terminal details: $e');
      }
    }
  }

  // Helper method to fetch address from landmark coordinates
  Future<String?> _fetchAddressFromCoordinates(LatLng coordinates) async {
    final String accessToken = _accessToken.mapboxaccesstoken; // Your Mapbox access token
    final String url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/${coordinates.longitude},${coordinates.latitude}.json?access_token=$accessToken';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Check if results are available and return the first address found
      return data['features'].isNotEmpty ? data['features'][0]['place_name'] : null;
    } else {
      throw Exception('Failed to load address');
    }
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
      _mapKey = UniqueKey();
    });
  }

  void _closeFloatingWidget() {
    _mapController.clearCurrentPolylines();
    _mapController.clearSelectedTerminal();
    _mapController.clearDropOffCircles();
    setState(() {
      _isFloatingWidgetVisible = false;
      _floatingWidgetData = null;
    });
  }

    Future<List<LatLng>> fetchPlaces(String category) async {
  final String nearLocation = "San Jose Del Monte, Bulacan, Philippines";
  final String apiKey = 'fsq3rgV6402ofALVKftiTn0po1al4GQstY7LOErKP+J0x9w=';
  final encodedQuery = Uri.encodeComponent(category);

  final String url =
      "https://api.foursquare.com/v3/places/search?query=$encodedQuery&near=$nearLocation&limit=10";

  print('Fetching places for category: $category');
  print('Encoded query: $encodedQuery');
  print('Request URL: $url');

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': apiKey,
        'Accept': 'application/json',
      },
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<LatLng> fetchedMarkers = [];

      if (data['results'] != null && data['results'].isNotEmpty) {
        for (var venue in data['results']) {
          final lat = venue['geocodes']['main']['latitude'];
          final lng = venue['geocodes']['main']['longitude'];
          print('Fetched venue: ${venue['name']} at [$lat, $lng]');
          fetchedMarkers.add(LatLng(lat, lng));
        }
      } else {
        print('No results found for category: $category');
      }

      return fetchedMarkers;
    } else {
      print('Error: Received status code ${response.statusCode}');
      throw Exception('Failed to load places');
    }
  } catch (e) {
    print('Error fetching places: $e');
    return [];
  }
}


  Future<List<Map<String, dynamic>>> fetchButtonPlaces(String category) async {
  final String nearLocation = "San Jose Del Monte, Bulacan, Philippines";
  final String apiKey = 'fsq3rgV6402ofALVKftiTn0po1al4GQstY7LOErKP+J0x9w='; 
  final encodedQuery = Uri.encodeComponent(category);

  final String url =
      "https://api.foursquare.com/v3/places/search?query=$encodedQuery&near=$nearLocation&limit=10";

  print('Fetching button places for category: $category');
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': apiKey,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<Map<String, dynamic>> fetchedPlaces = [];

      if (data['results'] != null && data['results'].isNotEmpty) {
        for (var venue in data['results']) {
          final lat = venue['geocodes']['main']['latitude'];
          final lng = venue['geocodes']['main']['longitude'];
          final name = venue['name'];
          final address = venue['location'] != null ? venue['location']['formatted_address'] : 'No address available';
          
          String imageUrl = ''; // Default empty image URL
          if (venue['photos'] != null && venue['photos'].isNotEmpty) {
            // Get the first photo URL if available
            imageUrl = venue['photos'][0]['prefix'] + '300x300' + venue['photos'][0]['suffix'];
          }
          
          print('Fetched venue: $name at [$lat, $lng]');
          
          fetchedPlaces.add({
            'location': LatLng(lat, lng),
            'name': name,
            'address': address,
            'image_url': imageUrl, // Add the image URL to the data
          });
        }
      } else {
        print('No results found for category: $category');
      }

      return fetchedPlaces;
    } else {
      print('Error: Received status code ${response.statusCode}');
      throw Exception('Failed to load places');
    }
  } catch (e) {
    print('Error fetching button places: $e');
    return [];
  }
}




void updateMarkers(String category) async {
  print('Updating markers for category: $category');

  List<Map<String, dynamic>> newPlaces = await fetchButtonPlaces(category);
  print('Fetched new places: $newPlaces');

  // Clear previous markers
  for (var markerData in _placeSymbols) {
    await _mapController.removeSymbol(markerData.symbol);
    print('Removed symbol: ${markerData.symbol}');
  }
  _placeSymbols.clear();
  print('Cleared all previous markers.');

  await _mapController.addImage("custom-pin", "assets/pin.png");

  setState(() {
    places.clear();
    places.addAll(newPlaces.map((placeData) => placeData['location'] as LatLng));
  });
  print('Updated places in state: $places');

  for (var placeData in newPlaces) {
    LatLng place = placeData['location'];
    String name = placeData['name'];
    String address = placeData['address'];
    String imageUrl = placeData['image_url']; // Get the image URL
    
    print('Adding marker for place: $name at $place');
    
    final symbol = await _mapController.addSymbol(SymbolOptions(
      geometry: place,
      iconImage: "custom-pin",
      iconSize: 0.15,
    ));
    print('Created symbol: $symbol for place: $name');

    // Create and add MarkerData with all the required details
    _placeSymbols.add(MarkerData(
      symbol,
      place,
      name,
      address,
      'Unknown Type', // You can replace this with a relevant type if available
      imageUrl, // Use the fetched image URL
    ));

    // Save marker data associated with the symbol
    _markerData[symbol.id] = {
      'place': place,
      'info': 'Additional info about this place'
    };
    print('Saved marker data: ${_markerData[symbol.id]}');
  }

  print('Finished updating markers.');
}



  // New method to handle symbol taps
void _handleMapClick(LatLng clickedPosition) {
  for (var markerData in _placeSymbols) {
    _mapController.removeSymbol(markerData.symbol);
    print('Removed symbol: ${markerData.symbol}');
  }
  
  for (var markerData in _placeSymbols) {
    double distance = Geolocator.distanceBetween(
      clickedPosition.latitude,
      clickedPosition.longitude,
      markerData.position.latitude,
      markerData.position.longitude,
    );

    if (distance < 150) {
      // Use the stored data from markerData
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return PlaceDetailDialog(
            name: markerData.name,
            address: markerData.address,
            type: markerData.type,
            imageUrl: markerData.imageUrl,
            onCreateRoute: () {
              _routeToDestination(LatLng(markerData.position.latitude, markerData.position.longitude));
            } // Provide a valid image URL if available
          );
        },
      );
      break; // Exit the loop if a marker is found
    }
  }
}






@override
Widget build(BuildContext context) {
  if (_currentPosition == null) {
    return Center(child: CircularProgressIndicator()); // Loading state
  }

  return Scaffold(
    key: _scaffoldKey,
    appBar: AppBar(
      title: Text('Map Page'),
      leading: IconButton(
        icon: Icon(Icons.account_circle),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
    ),
    body: GestureDetector(
      onTap: () {
        if (_isFloatingWidgetVisible) {
          _closeFloatingWidget(); 
        }
      },
      child: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            child: MapboxMap(
              key: _mapKey,
              accessToken: _accessToken.mapboxaccesstoken,
              styleString: 'mapbox://styles/mapbox/streets-v11',
              onMapCreated: (controller) async {
                _mapController.onMapCreated(controller);
                
                },
              onStyleLoadedCallback: () {
                _mapController.onStyleLoaded();
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(14.807553, 121.047753),
                zoom: 14.0,
              ),
              onMapClick: (point, latLng) {
                  _handleMapClick(latLng); // Handle clicks on the map
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
                              _isSearchActive = false; 
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

          if (_isFloatingWidgetVisible) _buildFloatingWidget(context),
          // Floating Buttons
          _buildFloatingButtons(context),
        ],
      ),
    ),
    drawer: _buildUserDrawer(context),
  );
}

Widget _buildFloatingButtons(BuildContext context) {
  bool isSmallScreen = MediaQuery.of(context).size.width < 600;

  return Positioned(
    bottom: 16,
    left: 16,
    right: 16,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                updateMarkers("Food");
              },
              label: isSmallScreen ? SizedBox() : Text("Food Restaurant"), // Non-null fallback
              icon: Icon(Icons.fastfood),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                updateMarkers("Police Stations");
              },
              label: isSmallScreen ? SizedBox() : Text("Police Stations"), // Non-null fallback
              icon: Icon(Icons.local_police),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                updateMarkers("Landmarks");
              },
              label: isSmallScreen ? SizedBox() : Text("Landmarks Tourist Spots"), // Non-null fallback
              icon: Icon(Icons.place),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                updateMarkers("Hospitals");
              },
              label: isSmallScreen ? SizedBox() : Text("Hospitals"), // Non-null fallback
              icon: Icon(Icons.local_hospital),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                updateMarkers("Hotel, Motel, Convenience Store");
              },
              label: isSmallScreen ? SizedBox() : Text("Amenities"), // Non-null fallback
              icon: Icon(Icons.room_service),
            ),
          ),
        ),
      ],
    ),
  );
}




Color hexToColor(String hexColor) {

  hexColor = hexColor.replaceAll('#', '');


  if (hexColor.length == 6) {
    return Color(int.parse('FF$hexColor', radix: 16)); 
  } else if (hexColor.length == 8) {
    return Color(int.parse(hexColor, radix: 16));
  } else {
    throw FormatException("Invalid hex color format");
  }
}
Widget _buildFloatingWidget(BuildContext context) {
  double widgetWidth = MediaQuery.of(context).size.width * 0.4;
  double widgetHeight = MediaQuery.of(context).size.height * 0.6;

  return Positioned(
    top: MediaQuery.of(context).size.width < 600
        ? (MediaQuery.of(context).size.height - widgetHeight) / 2
        : 60,
    left: MediaQuery.of(context).size.width < 600
        ? (MediaQuery.of(context).size.width - widgetWidth) / 2
        : 16,
    child: GestureDetector(
      onTap: () {},
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: widgetWidth,
          constraints: BoxConstraints(
            minWidth: 300, // Minimum width for small screens
            minHeight: 400, // Minimum height for small screens
          ),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: SingleChildScrollView( // Add Scroll View
            child: Padding(
              padding: EdgeInsets.only(bottom: 15), // Add padding at the bottom
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Banner Section with Image
                      Container(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          image: DecorationImage(
                            image: NetworkImage(_floatingWidgetData?['imageUrl'] ?? 'default_image_url.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Terminal Name
                      Text(
                        _floatingWidgetData?['name'] ?? 'Terminal Name',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 2),
                      // Description Section
                      Text(
                        _floatingWidgetData?['description'] ?? 'No description available',
                        style: TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      // Routes Section
                      if (_mapController.selectedTerminal?.routes.isNotEmpty == true) ...[
                        Text(
                          'Available Routes:',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Column(
                          children: _mapController.selectedTerminal!.routes.map((route) {
                            final firstPoint = route.points.first;
                            final lastPoint = route.points.last;
                            final dropOffPoint = route.dropOffPoints;
                            final color = route.color;

                            return FutureBuilder<String?>(
                              future: _fetchAddressFromCoordinates(firstPoint),
                              builder: (context, firstAddressSnapshot) {
                                if (!firstAddressSnapshot.hasData) {
                                  return Container(); // or a loading indicator
                                }
                                return FutureBuilder<String?>(
                                  future: _fetchAddressFromCoordinates(lastPoint),
                                  builder: (context, lastAddressSnapshot) {
                                    if (!lastAddressSnapshot.hasData) {
                                      return Container(); // or a loading indicator
                                    }
                                    return Container(
                                      width: double.infinity,
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          _mapController.clearCurrentPolylines();
                                          _mapController.displayRoute(route);
                                          _mapController.createDropOffCircles(dropOffPoint, color);
                                        },
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Route Name with Stroke Effect
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Text(
                                                  route.name,
                                                  style: TextStyle(
                                                    fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black.withOpacity(0.7),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                Text(
                                                  route.name,
                                                  style: TextStyle(
                                                    fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'From ${firstAddressSnapshot.data} to ${lastAddressSnapshot.data}',
                                              style: TextStyle(
                                                fontSize: MediaQuery.of(context).size.width < 600 ? 8 : 9,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          backgroundColor: hexToColor(route.color),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      SizedBox(height: 8),
                    ],
                  ),
                  // Close Button
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: _closeFloatingWidget,
                    ),
                  ),

                  SizedBox(height: 40),
                  // Submit Ticket Button
                  Positioned(
                    left: 16,
                    bottom: -20,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showTicketSubmissionDialog(context, _guestUserData?['username'] ?? 'guest_user', _floatingWidgetData?['name'] ?? 'Terminal Name');
                      },
                      icon: Icon(Icons.confirmation_number, color: Colors.white),
                      label: MediaQuery.of(context).size.width < 600
                          ? Container() // Hide label on small screens
                          : Text(
                              'Submit Ticket',
                              style: TextStyle(color: Colors.white),
                            ),
                      style: ElevatedButton.styleFrom(
                        
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 150),
                  if (_isTicketWidgetVisible) 
                    SizedBox(
                      width: 500, // Define a width
                      height: 600, // Define a height
                      child: FloatingTicketSubmissionWidget(username: _guestUserData?['username'] ?? 'guest_user', terminalName: _floatingWidgetData?['name'] ?? 'Terminal Name'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}



Widget _buildUserDrawer(BuildContext context) {
  return Drawer(
    child: Column(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Colors.blue),
          child: Row(
            children: [
              Icon(Icons.account_circle, size: 60, color: Colors.white),
              SizedBox(width: 16),
              _guestUserData != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${_guestUserData!['username']}',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        Text(
                          '${_guestUserData!['firstName']} ${_guestUserData!['lastName']}',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                  : FutureBuilder<DocumentSnapshot>(
                      future: _userData,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Error fetching user data');
                        } else if (!snapshot.hasData || !snapshot.data!.exists) {
                          return Text('User Info not available');
                        }

                        var userData = snapshot.data!.data() as Map<String, dynamic>;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${_guestUserData!['username']}',
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            Text(
                              '${_guestUserData!['firstName']} ${_guestUserData!['lastName']}',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        );
                      },
                    ),
            ],
          ),
        ),
        ListTile(
          title: Text('FAQ'),
          onTap: () {
            Navigator.pushNamed(context, '/faq');
          },
        ),
        ListTile(
          title: Text('Log Out'),
          onTap: () {
            FirebaseAuth.instance.signOut();
            Navigator.of(context).pop(); 
          },
        ),
      ],
    ),
  );
}

}

