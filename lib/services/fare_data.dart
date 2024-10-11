import 'package:flutter/material.dart';

class FareWidget extends StatelessWidget {
  final FareData fareData;

  FareWidget({required this.fareData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fareData.terminalName,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Icon(Icons.arrow_drop_down),
          Text(
            fareData.dropOffAddress,
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Walking Distance to Drop-Off: ${fareData.walkingDistanceToDropOff} km',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Last Point Address: ${fareData.lastPointAddress}',
            style: TextStyle(fontSize: 18),
          ),
          Text(
            'Walking Distance to Destination: ${fareData.walkingDistanceToDestination} km',
            style: TextStyle(fontSize: 16),
          ),
          Divider(),
          Text(
            'Fare: ${fareData.fareWithoutMarkup.toStringAsFixed(2)} - ${fareData.fareWithMarkup.toStringAsFixed(2)} pesos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Route: ${fareData.routeName}',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class FareData {
  final String terminalName;
  final String routeName;
  final String dropOffAddress;
  final String lastPointAddress;
  final double walkingDistanceToDropOff;
  final double walkingDistanceToDestination;
  final double fareWithoutMarkup;
  final double fareWithMarkup;

  FareData({
    required this.terminalName,
    required this.routeName,
    required this.dropOffAddress,
    required this.lastPointAddress,
    required this.walkingDistanceToDropOff,
    required this.walkingDistanceToDestination,
    required this.fareWithoutMarkup,
    required this.fareWithMarkup, required double walkingDistanceFromLastPoint, double? drivingDistance, required String destinationAddress,
  });
}
