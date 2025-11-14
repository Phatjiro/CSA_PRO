# 🎯 Quick Reference - 78 Sensors

## 📊 Sensor Overview

**Tổng số:** **78 sensors** (69 PIDs + 9 calculated)

### Phân loại theo Category:

| Category | Count | Description |
|----------|-------|-------------|
| 🏎️ **Engine** | 10 | RPM, Speed, Load, Timing, etc. |
| 🌡️ **Temperature** | 8 | Coolant, Intake, Catalyst monitoring |
| ⛽ **Fuel** | 12 | Level, Pressure, Fuel Trim, Lambda |
| 💨 **Air** | 4 | MAF, MAP, Barometric Pressure |
| 🎚️ **Throttle** | 8 | Position variations, Commanded |
| 🔬 **Advanced** | 18 | O2 sensors, Voltage, EGR, etc. |
| 📐 **O2 Sensors** | 8 | Bank 1/2, Sensor 1/2/3/4 |
| 🧮 **Calculated** | 9 | HP, MPG, AFR, 0-100 time |
| | **Total: 78** | |

---

## 🆕 New Sensors in v1.3.0 (7 sensors)

### 🌡️ Temperature (+2)

#### Catalyst Temp B1S2 (PID 013E)
- **Location:** Bank 1 Sensor 2 (sau catalyst)
- **Range:** -40°C to 6513.5°C
- **Normal:** 400-800°C
- **Formula:** `((A×256)+B)/10 - 40`
- **Use Case:** Monitor catalyst exit temperature

#### Catalyst Temp B2S2 (PID 013F)
- **Location:** Bank 2 Sensor 2 (sau catalyst)
- **Range:** -40°C to 6513.5°C
- **Normal:** 400-800°C
- **Formula:** `((A×256)+B)/10 - 40`
- **Use Case:** Monitor catalyst exit temperature

### ⛽ Fuel (+5)

#### Fuel Pressure (PID 010A)
- **Type:** Gauge Pressure (relative to atmosphere)
- **Range:** 0-765 kPa
- **Normal:** 300-500 kPa (gasoline)
- **Formula:** `3×A`
- **Diagnostic:**
  - **Low (<250 kPa):** Weak fuel pump, clogged filter
  - **High (>600 kPa):** Fuel pressure regulator issue

#### Short Term Fuel Trim 1 (PID 0106)
- **Bank:** 1
- **Type:** Real-time adjustment
- **Range:** -100% to +99.2%
- **Normal:** -10% to +10%
- **Formula:** `(A-128)×100/128`
- **Meaning:**
  - **Positive (+):** ECU adding fuel (running LEAN)
  - **Negative (-):** ECU removing fuel (running RICH)
- **Diagnostic:**
  - **+15% to +25%:** Vacuum leak, dirty MAF, low fuel pressure
  - **-15% to -25%:** Dirty air filter, leaking injectors, bad O2

#### Long Term Fuel Trim 1 (PID 0107)
- **Bank:** 1
- **Type:** Learned adjustment
- **Range:** -100% to +99.2%
- **Normal:** -10% to +10%
- **Formula:** `(A-128)×100/128`
- **Meaning:** ECU's learned compensation over time
- **Diagnostic:**
  - **High values:** Persistent issue that ECU has adapted to
  - **Match STFT:** Confirms the diagnosis

#### Short Term Fuel Trim 2 (PID 0108)
- **Bank:** 2
- **Type:** Real-time adjustment
- **Same as STFT1 but for Bank 2**

#### Long Term Fuel Trim 2 (PID 0109)
- **Bank:** 2
- **Type:** Learned adjustment
- **Same as LTFT1 but for Bank 2**

---

## 🔍 Diagnostic Guide - NEW Sensors

### 🌡️ Catalyst Temperature Diagnostics

**4-Point Monitoring System:**
```
Upstream (B1S1, B2S1) → [Catalyst] → Downstream (B1S2, B2S2)
```

#### Scenarios:

1. **Normal Operation:**
   - B1S1: 700°C, B1S2: 600°C → Temperature drop indicates working catalyst
   - B2S1: 720°C, B2S2: 610°C → Both banks similar

2. **Catalyst Failure:**
   - B1S1: 750°C, B1S2: 740°C → Minimal drop = not working
   - **Diagnosis:** Catalyst ineffective, needs replacement

3. **Catalyst Meltdown Risk:**
   - B1S1 or B1S2 > 900°C → DANGER!
   - **Diagnosis:** Rich condition, catalyst overheating

4. **Catalyst Not Heating:**
   - All temps < 300°C after warmup
   - **Diagnosis:** Catalyst not reaching operating temperature

5. **Bank Imbalance:**
   - Bank 1: 700°C, Bank 2: 400°C
   - **Diagnosis:** Issue with Bank 2 (injector, O2 sensor, etc.)

### ⛽ Fuel System Diagnostics

**Fuel Trim Analysis Matrix:**

| STFT | LTFT | Diagnosis |
|------|------|-----------|
| 0% | 0% | ✅ Perfect! System running normally |
| +5% | 0% | ✅ Minor short-term adjustment (normal) |
| 0% | +5% | ⚠️ ECU has learned compensation |
| +15% | +15% | ❌ **LEAN condition** - Vacuum leak, low fuel pressure |
| -15% | -15% | ❌ **RICH condition** - Dirty air filter, leaking injector |
| +20% | 0% | ⚠️ Temporary issue (dirty MAF?) |
| 0% | +20% | ❌ Persistent issue ECU has adapted to |

**Bank Comparison:**

| Bank 1 | Bank 2 | Diagnosis |
|--------|--------|-----------|
| +5% | +5% | ✅ Both banks balanced |
| +15% | 0% | ❌ **Bank 1 issue** - Check Bank 1 injectors, O2 sensor |
| 0% | +15% | ❌ **Bank 2 issue** - Check Bank 2 injectors, O2 sensor |
| +20% | +20% | ❌ **System-wide issue** - MAF sensor, fuel pump, vacuum leak |

**Cross-Reference Diagnostics:**

```
Fuel Trim + Fuel Pressure + Lambda + O2 Sensors = Complete Picture
```

#### Example 1: LEAN Condition
```
STFT1: +20%
LTFT1: +15%
Fuel Pressure: 220 kPa (LOW!)
Lambda: 1.05 (lean)
O2 Sensor: 0.1V (lean)
→ Diagnosis: Low fuel pressure causing lean condition
→ Fix: Replace fuel pump or clean/replace fuel filter
```

#### Example 2: RICH Condition
```
STFT1: -18%
LTFT1: -12%
Fuel Pressure: 400 kPa (normal)
Lambda: 0.90 (rich)
O2 Sensor: 0.85V (rich)
→ Diagnosis: Excess fuel entering system
→ Fix: Check for leaking injector or dirty air filter
```

#### Example 3: Bank Specific Issue
```
STFT1: +20%  |  STFT2: +2%
LTFT1: +18%  |  LTFT2: 0%
→ Diagnosis: Bank 1 specific issue
→ Check: Bank 1 O2 sensor, injectors, vacuum leaks on that side
```

---

## 🎓 Technical Formulas

### Catalyst Temperature
```
Formula: ((A×256)+B)/10 - 40 (°C)
Example: A=1F, B=D0
  → (31×256+208)/10 - 40
  → 8144/10 - 40
  → 814.4 - 40
  → 774.4°C
```

### Fuel Pressure
```
Formula: 3×A (kPa)
Example: A=C8 (200 decimal)
  → 3×200 = 600 kPa
```

### Fuel Trim
```
Formula: (A-128)×100/128 (%)
Example: A=90 (144 decimal)
  → (144-128)×100/128
  → 16×100/128
  → 12.5%  (ECU adding 12.5% more fuel)
```

---

## 🚗 Real-World Examples

### Scenario 1: P0420 (Catalyst Efficiency Below Threshold)
**Check:**
1. Catalyst Temp B1S1: 720°C
2. Catalyst Temp B1S2: 710°C
3. **Delta:** Only 10°C drop

**Diagnosis:** Catalyst not converting properly (should drop 50-150°C)
**Action:** Replace catalyst

### Scenario 2: Car Running Rough, Check Engine Light
**Check:**
1. STFT1: +22%, STFT2: +4%
2. LTFT1: +20%, LTFT2: 0%
3. Fuel Pressure: 380 kPa (normal)

**Diagnosis:** Bank 1 vacuum leak
**Action:** Smoke test Bank 1 intake manifold

### Scenario 3: Poor Fuel Economy
**Check:**
1. STFT1: -15%, STFT2: -14%
2. LTFT1: -12%, LTFT2: -11%
3. Fuel Pressure: 550 kPa (high)
4. Lambda: 0.88 (rich)

**Diagnosis:** Fuel pressure regulator stuck/failed
**Action:** Replace fuel pressure regulator

---

## 📋 Quick Checklist

### ✅ Healthy Vehicle
- [ ] All Catalyst Temps: 400-800°C
- [ ] Temp drop across catalyst: 50-150°C
- [ ] STFT: -5% to +5%
- [ ] LTFT: -5% to +5%
- [ ] Fuel Pressure: 300-500 kPa
- [ ] Bank 1 ≈ Bank 2 (within 5%)

### ⚠️ Warning Signs
- [ ] Catalyst Temp > 850°C (overheating risk)
- [ ] Catalyst Temp < 300°C after warmup
- [ ] STFT > +15% or < -15%
- [ ] LTFT > +10% or < -10%
- [ ] Fuel Pressure < 250 kPa or > 600 kPa
- [ ] Bank difference > 10%

### ❌ Immediate Action Required
- [ ] Catalyst Temp > 950°C (meltdown!)
- [ ] STFT > +25% or < -25%
- [ ] Fuel Pressure < 200 kPa
- [ ] Large bank mismatch (>20%)

---

## 🔗 Related Documentation

- [CHANGELOG.md](CHANGELOG.md) - Version history
- [SENSORS_UPDATE.md](SENSORS_UPDATE.md) - Technical details
- [OBD2_COMPLETE_STANDARD.md](OBD2_COMPLETE_STANDARD.md) - Complete OBD2 reference
- [DEBUG_GUIDE.md](obd-emulator/DEBUG_GUIDE.md) - Troubleshooting guide

---

**Last Updated:** v1.3.0 - November 13, 2024

