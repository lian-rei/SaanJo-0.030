import 'package:flutter/material.dart';


class PlaceDetailDialog extends StatelessWidget {
  final String name;
  final String address;
  final String type;
  final String imageUrl;
  final VoidCallback onCreateRoute;

  PlaceDetailDialog({
    required this.name,
    required this.address,
    required this.type,
    required this.imageUrl,
    required this.onCreateRoute,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        name,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(height: 10),
            Text(
              'Address: $address',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 5),
            Text(
              'Type: $type',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {

            Navigator.of(context).pop();
          },
          child: Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); 
            onCreateRoute();
            
          },
          child: Text(
              'Create Route',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
        ),
      ],
    );
  }
}
