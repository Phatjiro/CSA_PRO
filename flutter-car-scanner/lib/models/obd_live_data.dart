class ObdLiveData {
  final int engineRpm;
  final int vehicleSpeedKmh;
  final int coolantTempC;
  final int intakeTempC;
  final int throttlePositionPercent;
  final int fuelLevelPercent;
  final int engineLoadPercent;
  final int mapKpa;
  final int baroKpa;
  final int mafGs;
  final double voltageV;
  final int ambientTempC;
  final double lambda;
  
  // Additional PIDs from images
  final int fuelSystemStatus;
  final int timingAdvance;
  final int runtimeSinceStart;
  final int distanceWithMIL;
  final int commandedPurge;
  final int warmupsSinceClear;
  final int distanceSinceClear;
  final int catalystTemp;
  final int absoluteLoad;
  final double commandedEquivRatio;
  final int relativeThrottle;
  final int absoluteThrottleB;
  final int absoluteThrottleC;
  final int pedalPositionD;
  final int pedalPositionE;
  final int pedalPositionF;
  final int commandedThrottleActuator;
  final int timeRunWithMIL;
  final int timeSinceCodesCleared;
  final double maxEquivRatio;
  final int maxAirFlow;
  final int fuelType;
  final int ethanolFuel;
  final int absEvapPressure;
  final int evapPressure;
  final int shortTermO2Trim1;
  final int longTermO2Trim1;
  final int shortTermO2Trim2;
  final int longTermO2Trim2;
  final int shortTermO2Trim3;
  final int longTermO2Trim3;
  final int shortTermO2Trim4;
  final int longTermO2Trim4;
  final int catalystTemp1;
  final int catalystTemp2;
  final int catalystTemp3;
  final int catalystTemp4;
  final int fuelPressure;
  final int shortTermFuelTrim1;
  final int longTermFuelTrim1;
  final int shortTermFuelTrim2;
  final int longTermFuelTrim2;

  const ObdLiveData({
    required this.engineRpm,
    required this.vehicleSpeedKmh,
    required this.coolantTempC,
    required this.intakeTempC,
    required this.throttlePositionPercent,
    required this.fuelLevelPercent,
    required this.engineLoadPercent,
    required this.mapKpa,
    required this.baroKpa,
    required this.mafGs,
    required this.voltageV,
    required this.ambientTempC,
    required this.lambda,
    required this.fuelSystemStatus,
    required this.timingAdvance,
    required this.runtimeSinceStart,
    required this.distanceWithMIL,
    required this.commandedPurge,
    required this.warmupsSinceClear,
    required this.distanceSinceClear,
    required this.catalystTemp,
    required this.absoluteLoad,
    required this.commandedEquivRatio,
    required this.relativeThrottle,
    required this.absoluteThrottleB,
    required this.absoluteThrottleC,
    required this.pedalPositionD,
    required this.pedalPositionE,
    required this.pedalPositionF,
    required this.commandedThrottleActuator,
    required this.timeRunWithMIL,
    required this.timeSinceCodesCleared,
    required this.maxEquivRatio,
    required this.maxAirFlow,
    required this.fuelType,
    required this.ethanolFuel,
    required this.absEvapPressure,
    required this.evapPressure,
    required this.shortTermO2Trim1,
    required this.longTermO2Trim1,
    required this.shortTermO2Trim2,
    required this.longTermO2Trim2,
    required this.shortTermO2Trim3,
    required this.longTermO2Trim3,
    required this.shortTermO2Trim4,
    required this.longTermO2Trim4,
    required this.catalystTemp1,
    required this.catalystTemp2,
    required this.catalystTemp3,
    required this.catalystTemp4,
    required this.fuelPressure,
    required this.shortTermFuelTrim1,
    required this.longTermFuelTrim1,
    required this.shortTermFuelTrim2,
    required this.longTermFuelTrim2,
  });
}


