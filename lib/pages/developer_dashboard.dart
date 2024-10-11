import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeveloperDashboard extends StatefulWidget {
  @override
  _DeveloperDashboardState createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  int totalPUVTerminals = 0;
  int totalTickets = 0;
  int totalTricycleTerminals = 0;
  int activeRoutes = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch PUV Terminals
      QuerySnapshot puvSnapshot = await FirebaseFirestore.instance.collection('terminals').get();
      totalPUVTerminals = puvSnapshot.docs.length;

      // Fetch Tickets
      QuerySnapshot ticketSnapshot = await FirebaseFirestore.instance.collection('tickets').get();
      totalTickets = ticketSnapshot.docs.length;

      // Fetch Tricycle Terminals
      QuerySnapshot tricycleSnapshot = await FirebaseFirestore.instance.collection('tricycleterminals').get();
      totalTricycleTerminals = tricycleSnapshot.docs.length;

      // Fetch Active Routes
      QuerySnapshot routesSnapshot = await FirebaseFirestore.instance.collection('terminals').get();
      for (var terminal in routesSnapshot.docs) {
        QuerySnapshot routeSnapshot = await terminal.reference.collection('routes').get();
        activeRoutes += routeSnapshot.docs.length;
      }

      setState(() {});
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Developer Dashboard'),
        backgroundColor: Color.fromARGB(189, 0, 0, 0),
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: Colors.grey[200],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_terminal');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      backgroundColor: Color.fromARGB(255, 145, 180, 255),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Add New Terminal'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/remove_terminal');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      backgroundColor: Color.fromARGB(255, 145, 180, 255),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Remove Terminal'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/modify_terminal');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      backgroundColor: Color.fromARGB(255, 145, 180, 255),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Modify Terminal'), 
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_tricycle');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      backgroundColor: Color.fromARGB(255, 145, 180, 255),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Add Tricycles'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/modify_tricycles');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      backgroundColor: Color.fromARGB(255, 145, 180, 255),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Modify Tricycles'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/ticket_dash');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60),
                      padding: EdgeInsets.symmetric(vertical: 5),
                      backgroundColor: Color.fromARGB(255, 145, 180, 255),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Ticket Dashboard'), 
                  ),
                ],
              ),
            ),
          ),
          // Main content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to the Developer Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Manage your terminals and routes here.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 32),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildDataBox('Total PUV Terminals', totalPUVTerminals.toString()),
                        _buildDataBox('Total Tickets', totalTickets.toString()),
                        _buildDataBox('Total Tricycle Terminals', totalTricycleTerminals.toString()),
                        _buildDataBox('Active Routes', activeRoutes.toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataBox(String title, String value) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
