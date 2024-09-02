import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/terminal.dart' as custom;
import 'package:mapbox_gl/mapbox_gl.dart';

class AddTerminalPage extends StatefulWidget {
  @override
  _AddTerminalPageState createState() => _AddTerminalPageState();
}

class _AddTerminalPageState extends State<AddTerminalPage> {
  final TextEditingController _terminalNameController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _routeColorController = TextEditingController();
  final TextEditingController _routePointsController = TextEditingController();
  final TextEditingController _terminalTypeController = TextEditingController(); 

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<custom.Route> _routes = []; 

  void _addRoute() {
    final routeName = _routeNameController.text.trim();
    final routeColor = _routeColorController.text.trim();
    final pointsString = _routePointsController.text.trim();

    if (routeName.isNotEmpty && routeColor.isNotEmpty && pointsString.isNotEmpty) {
      List<LatLng> points = pointsString.split(';').map((point) {
        List<String> coords = point.split(',');
        return LatLng(double.parse(coords[0]), double.parse(coords[1]));
      }).toList();

      setState(() {
        _routes.add(custom.Route(
          name: routeName,
          points: points,
          color: routeColor,
        ));
      });

      _routeNameController.clear();
      _routeColorController.clear();
      _routePointsController.clear();
    }
  }

  void _saveTerminal() {
    final terminalName = _terminalNameController.text.trim();
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    final terminalType = _terminalTypeController.text.trim();

    if (terminalName.isNotEmpty && latitude != null && longitude != null && terminalType.isNotEmpty) {
      _firestore.collection('terminals').doc(terminalName).set({
        'name': terminalName,
        'points': [GeoPoint(latitude, longitude)],
        'iconImage': terminalType,
      }).then((_) {
        final terminalRef = _firestore.collection('terminals').doc(terminalName);

        for (var route in _routes) {
          terminalRef.collection('routes').doc(route.name).set({
            'name': route.name,
            'points': route.points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
            'color': route.color,
          });
        }

        setState(() {
          _terminalNameController.clear();
          _latitudeController.clear();
          _longitudeController.clear();
          _terminalTypeController.clear();
          _routes.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terminal saved successfully!')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all the fields correctly!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Terminal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _terminalNameController,
              decoration: InputDecoration(labelText: 'Terminal Name'),
            ),
            TextField(
              controller: _latitudeController,
              decoration: InputDecoration(labelText: 'Latitude'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _longitudeController,
              decoration: InputDecoration(labelText: 'Longitude'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _terminalTypeController.text.isEmpty ? null : _terminalTypeController.text,
              items: [
                DropdownMenuItem(
                  child: Text('Jeep'),
                  value: 'jeep.png',
                ),
                DropdownMenuItem(
                  child: Text('E-Jeep'),
                  value: 'ejeep.png',
                ),
                DropdownMenuItem(
                  child: Text('Jeep + E-Jeep'),
                  value: 'jeepejeep.png',
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _terminalTypeController.text = value ?? '';
                });
              },
              decoration: InputDecoration(labelText: 'Terminal Type'),
            ),
            Divider(),
            Text('Add Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            ElevatedButton(
              onPressed: _addRoute,
              child: Text('Add Route'),
            ),
            Divider(),
            ElevatedButton(
              onPressed: _saveTerminal,
              child: Text('Save Terminal'),
            ),
          ],
        ),
      ),
    );
  }
}
