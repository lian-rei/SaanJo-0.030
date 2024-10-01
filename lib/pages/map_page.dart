import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/map_controller.dart';
import '../tokens/tokens.dart';
import '../pages/routing_page.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<DocumentSnapshot<Object?>>? _userData; // For logged-in users
  bool _isDarkMode = false;
  Key _mapKey = UniqueKey();
  Map<String, String>? _guestUserData; // For guest user data
  bool _isFloatingWidgetVisible = false; // To control the floating widget visibility
  Map<String, dynamic>? _floatingWidgetData; // For place details
  final AccessToken _accessToken = AccessToken();
  int _currentIndex = 1; // Default to the map (terminals page)

  @override
  void initState() {
    super.initState();
    _mapController.initializeLocationService();
    _mapController.addListener(() {
      setState(() {
        _isFloatingWidgetVisible = _mapController.selectedTerminal != null;
        if (_isFloatingWidgetVisible) {
          _showTerminalDetails(); // Fetch details when a terminal is selected
        }
      });
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (arguments != null) {
        setState(() {
          _guestUserData = {
            'firstName': 'Guest',
            'lastName': '',
            'username': 'guest_user',
          };
          _userData = null; // No user data for guest
        });
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          setState(() {
            _userData = FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          });
        } else {
          _userData = null; // No user data if not logged in
        }
      }
    });
  }

  Future<void> _showTerminalDetails() async {
    if (_mapController.selectedTerminal != null) {
      final terminal = _mapController.selectedTerminal!;
      try {
        final placeDetails = await terminal.fetchPlaceDetails(_accessToken.mapboxaccesstoken);
        if (placeDetails != null) {
          setState(() {
            _floatingWidgetData = {
              'name': placeDetails['text'] ?? 'Unknown Place',
              'description': placeDetails['place_name'] ?? 'No description available',
              'imageUrl': placeDetails['image'] ?? 'default_image_url.jpg', // Update as needed
            };
          });
        }
      } catch (e) {
        print('Error fetching place details: $e');
      }
    }
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
      _mapKey = UniqueKey(); // Force rebuild of MapboxMap widget
    });
  }

  void _closeFloatingWidget() {
    _mapController.clearSelectedTerminal(); // Clear the selected terminal
    setState(() {
      _isFloatingWidgetVisible = false; // Close the floating widget
      _floatingWidgetData = null; // Clear floating widget data
    });
  }

  void _onTabTapped(int index) {
  setState(() {
    _currentIndex = index;
    if (index == 2) { // Check if routing tab is tapped
      Navigator.of(context).push(MaterialPageRoute(
  builder: (context) => RoutingPage(mapController: _mapController), // Pass the MapController here
));
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: _mapController.positionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error fetching location'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return Center(child: Text('Location data not available'));
        }

        Position position = snapshot.data!;
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text('Saan Jo 0.060'),
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
                _closeFloatingWidget(); // Close the widget when tapping outside
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
                    styleString: _isDarkMode
                        ? 'https://api.mapbox.com/styles/v1/reiji2002/clvwkctw3025301qr5ebn3huq/tiles/256/{z}/{x}/{y}@2x?access_token=${_accessToken.mapboxaccesstoken}'
                        : 'https://api.mapbox.com/styles/v1/reiji2002/clvxk6ihd011v01pccts41fc7/tiles/256/{z}/{x}/{y}@2x?access_token=${_accessToken.mapboxaccesstoken}',
                    onMapCreated: (controller) {
                      _mapController.onMapCreated(controller);
                    },
                    onStyleLoadedCallback: () {
                      _mapController.onStyleLoaded();
                    },
                    initialCameraPosition: CameraPosition(
                      target: LatLng(position.latitude, position.longitude),
                      zoom: 14.0,
                    ),
                    myLocationEnabled: true,
                    myLocationTrackingMode: MyLocationTrackingMode.Tracking,
                  ),
                ),
                if (_isFloatingWidgetVisible) _buildFloatingWidget(),
              ],
            ),
          ),
          drawer: _buildUserDrawer(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.library_books),
                label: 'Catalog',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Terminals',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions),
                label: 'Routing',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingWidget() {
    return Positioned(
      top: 60,
      left: MediaQuery.of(context).size.width * 0.25,
      right: MediaQuery.of(context).size.width * 0.25,
      child: GestureDetector(
        onTap: () {},
        child: Card(
          elevation: 4,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: [
                if (_floatingWidgetData != null) ...[
                  Text(
                    _floatingWidgetData!['name'] ?? 'Terminal Name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(_floatingWidgetData!['description'] ?? 'No description available'),
                  SizedBox(height: 8),
                  Image.network(
                    _floatingWidgetData!['imageUrl'] ?? '',
                    width: 200,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ],
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: _closeFloatingWidget,
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_mapController.selectedTerminal != null) {
                      _mapController.clearCurrentPolylines();
                      _mapController.displayRoute(_mapController.selectedTerminal!.routes.first);
                    }
                  },
                  child: Text('View Route'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Row(
              children: [
                Icon(Icons.account_circle, size: 60, color: Colors.white),
                SizedBox(width: 16),
                _guestUserData != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_guestUserData!['firstName']} ${_guestUserData!['lastName']}',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            'Username: ${_guestUserData!['username']}',
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
                                'Welcome, ${userData['firstName']} ${userData['lastName']}',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              Text(
                                'Username: ${userData['username']}',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          );
                        },
                      ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: _toggleDarkMode,
          ),
          ListTile(
            title: Text('Log Out'),
            onTap: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pop(); // Close the drawer
            },
          ),
        ],
      ),
    );
  }
}

                       
