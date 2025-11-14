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
  
  // O2 Sensor Voltages (Mode 01 PIDs 0114-011B)
  final double o2SensorVoltage1; // Bank 1 Sensor 1
  final double o2SensorVoltage2; // Bank 1 Sensor 2
  final double o2SensorVoltage3; // Bank 1 Sensor 3
  final double o2SensorVoltage4; // Bank 1 Sensor 4
  final double o2SensorVoltage5; // Bank 2 Sensor 1
  final double o2SensorVoltage6; // Bank 2 Sensor 2
  final double o2SensorVoltage7; // Bank 2 Sensor 3
  final double o2SensorVoltage8; // Bank 2 Sensor 4
  
  // Additional Mode 01 PIDs
  final int engineOilTempC; // PID 015D
  final double engineFuelRate; // PID 015F (L/h)
  final int driverDemandTorque; // PID 0161 (%)
  final int actualTorque; // PID 0162 (%)
  final int referenceTorque; // PID 0163 (Nm)
  
  // Calculated Values (không có PID riêng)
  final double fuelEconomyL100km; // Fuel economy (L/100km)
  final double enginePowerKw; // Engine power (kW)
  final double enginePowerHp; // Engine power (HP)
  final double acceleration; // Acceleration (m/s²)
  final double averageSpeed; // Average speed (km/h)
  final double distanceTraveled; // Distance traveled (km)
  final int tripTime; // Trip time (seconds)
  final double airFuelRatio; // Air/Fuel ratio (AFR)
  final double volumetricEfficiency; // Volumetric efficiency (%)

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
    required this.o2SensorVoltage1,
    required this.o2SensorVoltage2,
    required this.o2SensorVoltage3,
    required this.o2SensorVoltage4,
    required this.o2SensorVoltage5,
    required this.o2SensorVoltage6,
    required this.o2SensorVoltage7,
    required this.o2SensorVoltage8,
    required this.engineOilTempC,
    required this.engineFuelRate,
    required this.driverDemandTorque,
    required this.actualTorque,
    required this.referenceTorque,
    this.fuelEconomyL100km = 0.0,
    this.enginePowerKw = 0.0,
    this.enginePowerHp = 0.0,
    this.acceleration = 0.0,
    this.averageSpeed = 0.0,
    this.distanceTraveled = 0.0,
    this.tripTime = 0,
    this.airFuelRatio = 14.7,
    this.volumetricEfficiency = 0.0,
  });
}


