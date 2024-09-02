import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/terminal.dart' as custom;

class ManageTerminals extends StatefulWidget {
  @override
  _ManageTerminalsState createState() => _ManageTerminalsState();
}

class _ManageTerminalsState extends State<ManageTerminals> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<custom.Terminal> _terminals = [];

  @override
  void initState() {
    super.initState();
    _fetchTerminals();
  }

  Future<void> _fetchTerminals() async {
    QuerySnapshot snapshot = await _firestore.collection('terminals').get();
    setState(() {
      _terminals = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return custom.Terminal.fromFirestore(data);
      }).toList();
    });
  }

  void _deleteTerminal(String terminalName) async {
    await _firestore.collection('terminals').doc(terminalName).delete();
    _fetchTerminals(); // Refresh the list
  }

  void _editTerminal(String terminalName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTerminalPage(terminalName: terminalName),
      ),
    ).then((_) => _fetchTerminals()); // Refresh after editing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Terminals'),
      ),
      body: ListView.builder(
        itemCount: _terminals.length,
        itemBuilder: (context, index) {
          final terminal = _terminals[index];
          return ListTile(
            title: Text(terminal.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _editTerminal(terminal.name),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteTerminal(terminal.name),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EditTerminalPage extends StatefulWidget {
  final String terminalName;

  EditTerminalPage({required this.terminalName});

  @override
  _EditTerminalPageState createState() => _EditTerminalPageState();
}

class _EditTerminalPageState extends State<EditTerminalPage> {
  final TextEditingController _terminalNameController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _terminalTypeController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchTerminalData();
  }

  Future<void> _fetchTerminalData() async {
    DocumentSnapshot doc = await _firestore.collection('terminals').doc(widget.terminalName).get();
    var data = doc.data() as Map<String, dynamic>;

    setState(() {
      _terminalNameController.text = data['name'];
      _latitudeController.text = (data['points'] as List).first.latitude.toString();
      _longitudeController.text = (data['points'] as List).first.longitude.toString();
      _terminalTypeController.text = data['iconImage'];
    });
  }

  void _saveChanges() {
    final terminalName = _terminalNameController.text.trim();
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    final terminalType = _terminalTypeController.text.trim();

    if (terminalName.isNotEmpty && latitude != null && longitude != null && terminalType.isNotEmpty) {
      _firestore.collection('terminals').doc(widget.terminalName).update({
        'name': terminalName,
        'points': [GeoPoint(latitude, longitude)],
        'iconImage': terminalType,
      }).then((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terminal updated successfully!')),
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
        title: Text('Edit Terminal'),
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveChanges,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
