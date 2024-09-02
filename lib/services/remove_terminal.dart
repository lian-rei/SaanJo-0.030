import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RemoveTerminalPage extends StatefulWidget {
  @override
  _RemoveTerminalPageState createState() => _RemoveTerminalPageState();
}

class _RemoveTerminalPageState extends State<RemoveTerminalPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _terminals = [];
  String? _selectedTerminal;

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

  void _deleteTerminal() {
    if (_selectedTerminal != null) {
      _firestore.collection('terminals').doc(_selectedTerminal).delete().then((_) {
        setState(() {
          _terminals.remove(_selectedTerminal);
          _selectedTerminal = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terminal deleted successfully!')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Remove Terminal'),
      ),
      body: Padding(
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
            ElevatedButton(
              onPressed: _deleteTerminal,
              child: Text('Delete Terminal'),
            ),
          ],
        ),
      ),
    );
  }
}
