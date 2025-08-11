<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## What it does

This submission introduces a **True Random Number Generator (TRNG)** peripheral designed to generate random numbers using ring oscillator-based entropy sources. While the design aims to provide high-quality randomness, comprehensive evaluation should be performed on silicon to confirm its effectiveness.

A detailed PDF document is included, describing the peripheral’s architecture and operation. The TRNG has been implemented on FPGA and fabricated on a different process node; however, as TRNG performance depends on the fabrication process, further testing on the target process is recommended.

Key features include two selectable ring generator bases (long 32-bit and short 16-bit polynomials), configurable calibration, and a straightforward memory-mapped interface for integration with the TinyQV core. Only one ring generator is active during operation—the dual options allow for comparative evaluation of entropy quality. More information is available in the included PDF located in the `/docs` directory.

### Key Features:
- **Dual Ring Generators**: Selectable between long (32-bit polynomial) and short (16-bit polynomial) ring generators
- **24 Entropy Cells**: Each generates entropy from ring oscillator jitter
- **Calibration Mode**: Configurable calibration cycles to stabilize the entropy sources
- **32-bit Random Output**: Serial collection of 32 random bits per read operation
- **Memory-Mapped Interface**: Simple register-based control and data access
- **Ready/Valid Handshaking**: Clear indication when random numbers are available

## Register Map

The TRNG peripheral uses a 6-address register map for configuration and data access:

| Address | Name                    | Access | Description                                                         |
|---------|-------------------------|--------|---------------------------------------------------------------------|
| 0x00    | CONTROL_REG            | R/W    | Control register for TRNG operations                               |
| 0x01    | STATUS_REG             | R/W    | Status register with ready bit                                      |
| 0x02    | CALIBRATION_CYCLES_REG | R/W    | Number of calibration cycles (32-bit value)                        |
| 0x03    | I1_REG                 | R/W    | Input I1 for entropy cells (bits 23:0 used)                       |
| 0x04    | I2_REG                 | R/W    | Input I2 for entropy cells (bits 23:0 used)                       |
| 0x05    | TRIGGER_REG            | R/W    | Trigger oscillator inputs for entropy cells (bits 23:0 used)      |
| 0x06    | RANDOM_NUMBER_REG      | R      | 32-bit random number output (read-only)                           |

### Control Register (0x00) Bit Fields:
| Bit | Name     | Access | Description                                    |
|-----|----------|--------|------------------------------------------------|
| 0   | RST      | R/W    | Software reset (1 = reset TRNG core)          |
| 1   | SEL_BASE | R/W    | Ring generator selection (0 = long, 1 = short)|
| 2   | CALIB    | R/W    | Calibration enable (1 = start calibration)    |
| 3   | READ     | R/W    | Read request (1 = request new random number)  |
| 31:4| Reserved | R/W    | Unused                       |

### Status Register (0x01) Bit Fields:
| Bit | Name     | Access | Description                                    |
|-----|----------|--------|------------------------------------------------|
| 0   | READY    | R      | Ready status (1 = random number ready to read)|
| 31:1| Reserved | R/W    | Unused                       |

## Operation Sequence

### 1. Initialization
The core can be reset by software with the first bit of the CONTROL_REG

```
1. Write CONTROL_REG[0] = 1 to reset the TRNG core
2. Write CONTROL_REG[0] = 0 to release reset
```

### 2. Entropy Trigger & Ring Generator Selection
```
Trigger entropy cells:
1. Each entropy cell can be individually configured via I1_REG, I2_REG and TRIGGER_REG, the trigger sequence is as followed (example trigger cell[1] and cell[0])
    - Write I1_REG with 0x3 (arm cell[1] and cell[0])
    - Write I2_REG with 0x0 (bit[1] and bit[0] is oppsite)
    - Write TRIGGER_REG with 0x3 (trigger cell[1] and cell[0])
2. Select ring generator:
    - Write 0 to CONTROL_REG[1] to select the long ring generator
    - Write 1 to CONTROL_REG[1] to select the short ring generator
```

### 3. Calibration
```
1. Write CALIBRATION_CYCLES_REG with desired number of calibration cycles (default 2^11)
2. Write CONTROL_REG[2] = 1 to start calibration
3. Wait for STATUS_REG[0] = 1 (ready bit) indicating calibration complete
```

### 4. Random Number Generation
```
1. Ensure STATUS_REG[0] = 1 (TRNG is ready)
2. Write CONTROL_REG[3] = 1 to request new random number
3. Wait for STATUS_REG[0] = 1 (new random number ready)
4. Read RANDOM_NUMBER_REG to get 32-bit random value
5. Repeat steps 2-4 for additional random numbers
```

### Recommended Test Setup:
- No external hardware required for basic operation
- Optional: Connect oscilloscope to monitor UO_OUT for debugging
- Optional: External entropy sources for enhanced randomness testing

The peripheral is fully self-contained and generates entropy from internal silicon process variations and thermal noise in the ring oscillators.
