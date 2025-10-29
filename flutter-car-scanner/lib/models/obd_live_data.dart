class ObdLiveData {
  final int engineRpm;
  final int vehicleSpeedKmh;
  final int coolantTempC;
  final int intakeTempC;
  final int throttlePositionPercent;
  final int fuelLevelPercent;

  const ObdLiveData({
    required this.engineRpm,
    required this.vehicleSpeedKmh,
    required this.coolantTempC,
    required this.intakeTempC,
    required this.throttlePositionPercent,
    required this.fuelLevelPercent,
  });
}


