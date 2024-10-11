import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TicketDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket Dashboard'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tickets').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tickets = snapshot.data!.docs;

          if (tickets.isEmpty) {
            return Center(child: Text('No tickets available.'));
          }

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final subject = ticket['subject'];
              final timestamp = ticket['timestamp']?.toDate() ?? DateTime.now();
              final tag = ticket['tag'] ?? 'No Tag';
              final username = ticket['username'] ?? 'Unknown User'; // Fetch username from the ticket
              final terminalName = ticket['terminalName'] ?? 'Unknown Terminal'; // Fetch terminal name from the ticket

              return Card(
                margin: EdgeInsets.all(10),
                child: ListTile(
                  title: Text(subject),
                  subtitle: Text('${username} - ${terminalName} - ${timestamp.toLocal()} - $tag'), // Updated subtitle
                  trailing: IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      _removeTicket(ticket.id);
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketDetailView(ticketId: ticket.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Method to remove a ticket
  Future<void> _removeTicket(String ticketId) async {
    try {
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).delete();
      print('Ticket removed successfully.');
    } catch (e) {
      print('Error removing ticket: $e');
    }
  }
}

class TicketDetailView extends StatelessWidget {
  final String ticketId;

  TicketDetailView({required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('tickets').doc(ticketId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final ticket = snapshot.data;

          if (ticket == null) {
            return Center(child: Text('Ticket not found.'));
          }

          final body = ticket['body'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(body, style: TextStyle(fontSize: 18)),
          );
        },
      ),
    );
  }
}
