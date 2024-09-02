import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class ModifyTerminalPage extends StatefulWidget {
  @override
  _ModifyTerminalPageState createState() => _ModifyTerminalPageState();
}

class _ModifyTerminalPageState extends State<ModifyTerminalPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _terminals = [];
  List<String> _routes = [];
  String? _selectedTerminal;
  String? _selectedRoute;
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newTypeController = TextEditingController();
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _routeColorController = TextEditingController();
  final TextEditingController _routePointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTerminals();
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
      });

      // Fetch routes for the selected terminal
      final routesSnapshot = await _firestore.collection('terminals').doc(terminalId).collection('routes').get();
      setState(() {
        _routes = routesSnapshot.docs.map((doc) => doc.id).toList();
      });
    }
  }

  void _fetchRouteDetails(String routeId) async {
    final routeDoc = await _firestore.collection('terminals').doc(_selectedTerminal!).collection('routes').doc(routeId).get();
    final routeData = routeDoc.data();
    if (routeData != null) {
      _routeNameController.text = routeData['name'] ?? '';
      _routeColorController.text = routeData['color'] ?? '';
      List<GeoPoint> points = List<GeoPoint>.from(routeData['points'] ?? []);
      _routePointsController.text = points.map((p) => '${p.latitude},${p.longitude}').join(';');
    }
  }

  void _updateTerminal() {
    if (_selectedTerminal != null) {
      final newName = _newNameController.text.trim();
      final newType = _newTypeController.text.trim();

      if (newName.isNotEmpty && newType.isNotEmpty) {
        final terminalRef = _firestore.collection('terminals').doc(_selectedTerminal);

        terminalRef.update({
          'name': newName,
          'iconImage': newType,
        }).then((_) {
          setState(() {
            _newNameController.clear();
            _newTypeController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Terminal updated successfully!')),
          );
        });
      }
    }
  }

  void _updateRoute() {
    if (_selectedTerminal != null && _selectedRoute != null) {
      final routeName = _routeNameController.text.trim();
      final routeColor = _routeColorController.text.trim();
      final pointsString = _routePointsController.text.trim();

      if (routeName.isNotEmpty && routeColor.isNotEmpty && pointsString.isNotEmpty) {
        final routeRef = _firestore.collection('terminals').doc(_selectedTerminal).collection('routes').doc(_selectedRoute);

        List<LatLng> points = pointsString.split(';').map((point) {
          List<String> coords = point.split(',');
          return LatLng(double.parse(coords[0]), double.parse(coords[1]));
        }).toList();

        routeRef.update({
          'name': routeName,
          'color': routeColor,
          'points': points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
        }).then((_) {
          setState(() {
            _routeNameController.clear();
            _routeColorController.clear();
            _routePointsController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Route updated successfully!')),
          );
        });
      }
    }
  }

  void _deleteRoute() {
    if (_selectedTerminal != null && _selectedRoute != null) {
      final routeRef = _firestore.collection('terminals').doc(_selectedTerminal).collection('routes').doc(_selectedRoute);

      routeRef.delete().then((_) {
        setState(() {
          _routeNameController.clear();
          _routeColorController.clear();
          _routePointsController.clear();
          _selectedRoute = null;
          _fetchTerminalDetails(_selectedTerminal!);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route deleted successfully!')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Modify Terminal'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: _selectedTerminal,
                hint: Text('Select Terminal'),
                onChanged: (value) {
                  setState(() {
                    _selectedTerminal = value;
                    if (value != null) {
                      _fetchTerminalDetails(value);
                    }
                  });
                },
                items: _terminals.map((terminal) {
                  return DropdownMenuItem(
                    value: terminal,
                    child: Text(terminal),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _newNameController,
                decoration: InputDecoration(labelText: 'New Name'),
              ),
              TextField(
                controller: _newTypeController,
                decoration: InputDecoration(labelText: 'New Type'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateTerminal,
                child: Text('Update Terminal'),
              ),
              SizedBox(height: 20),
              DropdownButton<String>(
                value: _selectedRoute,
                hint: Text('Select Route'),
                onChanged: (value) {
                  setState(() {
                    _selectedRoute = value;
                    if (value != null) {
                      _fetchRouteDetails(value);
                    }
                  });
                },
                items: _routes.map((route) {
                  return DropdownMenuItem(
                    value: route,
                    child: Text(route),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _routeNameController,
                decoration: InputDecoration(labelText: 'Route Name'),
              ),
              TextField(
                controller: _routeColorController,
                decoration: InputDecoration(labelText: 'Route Color (Hex Code)'),
              ),
              TextField(
                controller: _routePointsController,
                decoration: InputDecoration(labelText: 'Route Points (lat,lng;lat,lng)'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateRoute,
                child: Text('Update Route'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _deleteRoute,
                child: Text('Delete Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Updated to use backgroundColor
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
