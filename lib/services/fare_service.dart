

class FareService {
  final double baseFare;
  final double baseDistance; // Base distance for minimum fare
  final double additionalFarePerKm; // Fare for each additional kilometer
  final double staticMarkupAmount; // Static markup amount

  FareService({
    this.baseFare = 13.5,
    this.baseDistance = 4.0,
    this.additionalFarePerKm = 2.65,
    this.staticMarkupAmount = 3.0,
  });

  List<double> calculateFare(double distance) {
    // Calculate total distance
    double totalDistance = distance;

    // Calculate base fare (without markup)
    double fareWithoutMarkup;
    if (totalDistance <= baseDistance) {
      fareWithoutMarkup = baseFare;
    } else {
      double additionalDistance = totalDistance - baseDistance;
      fareWithoutMarkup = baseFare + (additionalDistance * additionalFarePerKm);
    }

    // Calculate fare with markup
    double fareWithMarkup = fareWithoutMarkup + staticMarkupAmount;

    // Round up both values
    fareWithoutMarkup = _roundUp(fareWithoutMarkup);
    fareWithMarkup = _roundUp(fareWithMarkup);

    return [fareWithoutMarkup, fareWithMarkup]; // Return both fares as a list
  }

  double _roundUp(double value) {
    return (value == value.floorToDouble()) ? value : value.ceilToDouble();
  }
}

void main() {
  // Example usage:
  FareService fareService = FareService();

  double distance = 4.0; // Example input distance
  List<double> totalFare = fareService.calculateFare(distance);
  
  print("Total Fare for distance of $distance km: ${totalFare[0].toStringAsFixed(2)} to ${totalFare[1].toStringAsFixed(2)} pesos");
}
