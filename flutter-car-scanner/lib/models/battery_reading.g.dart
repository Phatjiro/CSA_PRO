// GENERATED CODE - DO NOT MODIFY BY HAND
// This file is a placeholder. Run `flutter pub run build_runner build` to generate properly.

part of 'battery_reading.dart';

class BatteryReadingAdapter extends TypeAdapter<BatteryReading> {
  @override
  final int typeId = 4;

  @override
  BatteryReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BatteryReading(
      id: fields[0] as String,
      vehicleId: fields[1] as String,
      voltage: fields[2] as double,
      engineRpm: fields[3] as int,
      timestamp: fields[4] as DateTime,
      isCharging: fields[5] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, BatteryReading obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vehicleId)
      ..writeByte(2)
      ..write(obj.voltage)
      ..writeByte(3)
      ..write(obj.engineRpm)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.isCharging);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

