import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FloatingTicketSubmissionWidget extends StatefulWidget {
  final String username; // Add a username parameter
  final String terminalName; // Add a terminal name parameter

  FloatingTicketSubmissionWidget({required this.username, required this.terminalName}); // Update constructor

  @override
  _FloatingTicketSubmissionWidgetState createState() => _FloatingTicketSubmissionWidgetState();
}

class _FloatingTicketSubmissionWidgetState extends State<FloatingTicketSubmissionWidget> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<String> _tags = ['Fare', 'Route', 'Closure', 'Other'];
  String? _selectedTag;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submitTicket() async {
    final String subject = _subjectController.text;
    final String body = _bodyController.text;
    final String username = widget.username; // Use the passed username
    final String terminalName = widget.terminalName; // Use the passed terminal name

    try {
      await FirebaseFirestore.instance.collection('tickets').add({
        'subject': subject,
        'body': body,
        'tag': _selectedTag,
        'username': username, // Save the username
        'terminalName': terminalName, // Save the terminal name
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Ticket submitted: Subject: $subject, Body: $body, Tag: $_selectedTag, Username: $username, Terminal Name: $terminalName');
      
      // Clear fields after submission
      _subjectController.clear();
      _bodyController.clear();
      setState(() {
        _selectedTag = null;
      });

      Navigator.of(context).pop();

    } catch (e) {
      print('Error submitting ticket: $e');
    }
  }

  void _closeWidget() {
    Navigator.of(context).pop(); // Close the dialog
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.all(16.0),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.black),
                onPressed: _closeWidget,
              ),
            ),
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(labelText: 'Subject (Please include terminal name)'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(labelText: 'Body'),
              maxLines: 5,
            ),
            SizedBox(height: 16),
            Text('Select a Tag:', style: TextStyle(fontSize: 16)),
            Wrap(
              spacing: 8,
              children: _tags.map((tag) {
                return ChoiceChip(
                  label: Text(tag),
                  selected: _selectedTag == tag,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTag = selected ? tag : null;
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitTicket,
              child: Text('Submit Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

// Function to show the dialog
void showTicketSubmissionDialog(BuildContext context, String username, String terminalName) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return FloatingTicketSubmissionWidget(username: username, terminalName: terminalName); // Pass the username and terminal name
    },
  );
}
