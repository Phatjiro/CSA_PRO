class CarMakes {
  // List of most popular car manufacturers worldwide
  static const List<String> popularMakes = [
    'Toyota',
    'Volkswagen',
    'Ford',
    'Honda',
    'Chevrolet',
    'Nissan',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Hyundai',
    'Kia',
    'Mazda',
    'Subaru',
    'Lexus',
    'Jeep',
    'Ram',
    'GMC',
    'Dodge',
    'Volvo',
    'Porsche',
    'Tesla',
    'Jaguar',
    'Land Rover',
    'Mitsubishi',
    'Infiniti',
    'Acura',
    'Cadillac',
    'Lincoln',
    'Buick',
    'Chrysler',
    'Genesis',
    'Alfa Romeo',
    'Fiat',
    'Mini',
    'Smart',
    'Other', // Always at the end for custom input
  ];

  // Get all makes including "Other"
  static List<String> getAll() => List.from(popularMakes);

  // Check if a make is in the popular list
  static bool isPopular(String make) {
    return popularMakes.contains(make);
  }

  // Get makes excluding "Other"
  static List<String> getPopularOnly() {
    return popularMakes.where((make) => make != 'Other').toList();
  }
}

