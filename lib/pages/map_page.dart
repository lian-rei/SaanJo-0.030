import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/map_controller.dart';
import '../models/terminal.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<DocumentSnapshot> _userData;
  bool _isDarkMode = false; // Track dark mode status
  Key _mapKey = UniqueKey(); // Key to force rebuild of MapboxMap widget

  @override
  void initState() {
    super.initState();
    _mapController.initializeLocationService();
    _mapController.addListener(() {
      if (_mapController.selectedTerminal != null) {
        print("Terminal selected: ${_mapController.selectedTerminal?.name}");
        _openRouteDrawer();
      } else {
        print("No terminal selected.");
      }
    });

    // Load user data from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userData = FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    }
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
      _mapKey = UniqueKey(); // Force rebuild of MapboxMap widget
    });
    print("Dark Mode: $_isDarkMode"); // Debug statement
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
            title: Text('Saan Jo 0.030'),
            leading: IconButton(
              icon: Icon(Icons.account_circle), // User icon on the left
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer(); // Open user drawer
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.directions),
                onPressed: null,
              ),
            ],
          ),
          body: Stack(
            children: [
              MapboxMap(
                key: _mapKey, // Use the key to force rebuild
                accessToken: 'pk.eyJ1IjoicmVpamkyMDAyIiwiYSI6ImNsdnV6c2hhZzFxZTAybG1oMzJoeDNtOGQifQ.0hCQ02IhCilBVh-DhFDioQ',
                styleString: _isDarkMode
                    ? 'https://api.mapbox.com/styles/v1/reiji2002/clvwkctw3025301qr5ebn3huq/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoicmVpamkyMDAyIiwiYSI6ImNsdnV6b2Q5YzFzMjgya214ZW5rZnFwZTEifQ.pEJZ0EOKW3tMR0wxmr--cQ'
                    : 'https://api.mapbox.com/styles/v1/reiji2002/clvxk6ihd011v01pccts41fc7/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoicmVpamkyMDAyIiwiYSI6ImNsdnV6b2Q5YzFzMjgya214ZW5rZnFwZTEifQ.pEJZ0EOKW3tMR0wxmr--cQ',
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
            ],
          ),
          drawer: _buildUserDrawer(), // Main drawer with user info
          endDrawer: _buildRouteDrawer(), // Route drawer accessible from the right
        );
      },
    );
  }

  void _openRouteDrawer() {
    if (_mapController.selectedTerminal != null) {
      setState(() {});
      Future.delayed(Duration(milliseconds: 200), () {
        _scaffoldKey.currentState?.openEndDrawer(); // Open the route drawer from the right side
      });
    }
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
                FutureBuilder<DocumentSnapshot>(
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
          ListTile(
            title: Text('Routes'),
            onTap: () {
              _openRouteDrawer();
              Navigator.pop(context); // Close the user drawer
            },
          ),
          SwitchListTile(
            title: Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: _toggleDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDrawer() {
    return Drawer(
      child: ValueListenableBuilder<Terminal?>(
        valueListenable: _mapController.selectedTerminalNotifier,
        builder: (context, terminal, child) {
          if (terminal == null) {
            return Center(child: Text('No terminal selected'));
          }

          if (terminal.routes.isEmpty) {
            return Center(child: Text('No routes available'));
          }

          return ListView.builder(
            itemCount: terminal.routes.length,
            itemBuilder: (context, index) {
              final route = terminal.routes[index];
              return ListTile(
                title: Text(route.name),
                onTap: () {
                  Navigator.pop(context); // Close the route drawer
                  _mapController.displayRoute(route);
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
