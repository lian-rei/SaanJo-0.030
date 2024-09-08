import 'package:flutter/material.dart';

class DeveloperDashboard extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Developer Dashboard'),
        backgroundColor: Color.fromARGB(190, 250, 79, 11),
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Welcome to the Developer Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Manage your terminals and routes here. Use the buttons below to add, remove, or modify terminals and their routes.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/add_terminal');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 60), // Width and height of the button
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Color.fromARGB(255, 255, 202, 86), // Background color of the button
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
                minimumSize: Size(200, 60), // Width and height of the button
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor:  Color.fromARGB(255, 64, 226, 186), // Background color of the button
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
                minimumSize: Size(200, 60), // Width and height of the button
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue, // Background color of the button
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
                child: Text('Modify Terminal'),
              ),
            ],
          ),
        ),
      )
    );
  }
}