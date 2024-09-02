import 'package:flutter/material.dart';
import '../models/terminal.dart';

// Info Window Widget
class InfoWindow extends StatelessWidget {
  final Terminal? selectedTerminal;
  final VoidCallback onClose;

  const InfoWindow({
    Key? key,
    required this.selectedTerminal,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedTerminal == null) return SizedBox.shrink();

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 200,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.all(8.0),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close),
                onPressed: onClose,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40),
                Text(
                  selectedTerminal!.name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.0),
                Text('Terminal Points:'),
                for (var point in selectedTerminal!.points)
                  Text('(${point.latitude}, ${point.longitude})'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Map Action Button Widget
class MapActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MapActionButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.directions),
      onPressed: onPressed,
    );
  }
}

// Map Loading Indicator Widget
class MapLoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator());
  }
}
