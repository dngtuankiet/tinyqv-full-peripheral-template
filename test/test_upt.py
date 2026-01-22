# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

PERIPHERAL_NUM = 30

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI 
    # interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset
    await tqv.reset()

    dut._log.info("Test UPT peripheral behavior")
    # Register addresses
    CONTROL_REG = 0x0
    READOUT_REG = 0x1
    CALIBRATION_CYCLES_REG = 0x2
    SEED_0_REG = 0x3
    SEED_1_REG = 0x4
    MASK_0_REG = 0x5
    MASK_1_REG = 0x6
    I1_0_REG = 0x7
    I1_1_REG = 0x8
    I2_0_REG = 0x9
    I2_1_REG = 0xA
    TRIGGER_0_REG = 0xB
    TRIGGER_1_REG = 0xC


    # Status and output registers
    STATUS_REG = 0xD
    SAMPLE_0_REG = 0xE
    SAMPLE_1_REG = 0xF
    CAPTURED_ENTROPY_0_REG = 0x10
    CAPTURED_ENTROPY_1_REG = 0x11
    TEST_STATE_0_REG = 0x12
    TEST_STATE_1_REG = 0x13
    


    # Control register bits
    CORE_RESET = 0x1 << 0
    CORE_MODE = 0x1 << 1
    CORE_ENABLE = 0x1 << 2
    CORE_INIT = 0x1 << 3
    CORE_CALIB = 0x1 << 4
    
    READ_REQUEST = 0x1 << 0
    READY = 0x1 << 0

    # Parameters for the UPT peripheral
    # These values can be adjusted based on the test case
    # ENTROPY_CELLS = 0x1 # enable 1 cell among 50-bit entropy cells
    # ENTROPY_CELL_LOW = 0xDCBAABCD  # Lower 32 bits
    ENTROPY_CELL_LOW = 0xFFFFFFFF
    ENTROPY_CELL_HIGH = 0x3FFFF  # Upper 18 bits
    RANDOM_MODE = 0 # RANDOM_MODE
    PUF_MODE = 1 # PUF_MODE
    MODE_SELECT = PUF_MODE # Select RANDOM or PUF mode

    #=== Step 1: Reset UPT peripheral ===#
    dut._log.info("----------------------------------")
    dut._log.info("Step 1: Reset UPT peripheral")
    await tqv.write_word_reg(CONTROL_REG, CORE_RESET) # Reset the UPT peripheral
    await ClockCycles(dut.clk, 1000) # Reset the UPT for 1000 clock cycles
    await tqv.write_word_reg(CONTROL_REG, CORE_ENABLE)

    control_reg = await tqv.read_word_reg(CONTROL_REG)
    dut._log.info(f"UPT control register after reset: {control_reg:#x}")
    status_reg = await tqv.read_word_reg(STATUS_REG)
    dut._log.info(f"UPT status register after reset: {status_reg:#x}")

    #=== Step 1.5: Select mode and set parameters based on mode ===#
    dut._log.info("----------------------------------")
    dut._log.info("Step 1.5: Select mode and set parameters based on mode")
    if MODE_SELECT == RANDOM_MODE:
        dut._log.info("Selecting RANDOM mode")
        control_reg = await tqv.read_word_reg(CONTROL_REG)
        await tqv.write_word_reg(CONTROL_REG, control_reg & ~CORE_MODE)
    else:
        dut._log.info("Selecting PUF mode")
        control_reg = await tqv.read_word_reg(CONTROL_REG)
        await tqv.write_word_reg(CONTROL_REG, control_reg | CORE_MODE)

        dut._log.info("Set SEED registers for PUF mode")
        # In PUF mode, we may want to set a seed to stabilize the output
        puf_seed_0 = 0xDEADBEEF  # Example seed part 0
        puf_seed_1 = 0xCAFEBABE  # Example seed part 1
        await tqv.write_word_reg(SEED_0_REG, puf_seed_0)
        await tqv.write_word_reg(SEED_1_REG, puf_seed_1)
        seed_0_reg = await tqv.read_word_reg(SEED_0_REG)
        seed_1_reg = await tqv.read_word_reg(SEED_1_REG)
        dut._log.info(f"PUF SEED register 0 set to: {seed_0_reg:#x}")
        dut._log.info(f"PUF SEED register 1 set to: {seed_1_reg:#x}")

        dut._log.info("Set MASK register for PUF mode")
        # In PUF mode, we may want to set a mask to select which bits to use
        puf_mask_0 = 0xFFFFFFFF  # Example: Use all bits for MASK_0_REG
        puf_mask_1 = 0x3FFFF  # Example: Use all bits for MASK_1_REG
        await tqv.write_word_reg(MASK_0_REG, puf_mask_0)
        await tqv.write_word_reg(MASK_1_REG, puf_mask_1)
        mask_0_reg = await tqv.read_word_reg(MASK_0_REG)
        mask_1_reg = await tqv.read_word_reg(MASK_1_REG)
        dut._log.info(f"PUF MASK register 0 set to: {mask_0_reg:#x}")
        dut._log.info(f"PUF MASK register 1 set to: {mask_1_reg:#x}")

    #=== Step 2: Trigger entropy cells and select ring generator base ===#
    dut._log.info("----------------------------------")
    dut._log.info("Step 2: Trigger entropy cells")
    await tqv.write_word_reg(I1_0_REG, ENTROPY_CELL_LOW)
    await tqv.write_word_reg(I1_1_REG, ENTROPY_CELL_HIGH)
    await tqv.write_word_reg(I2_0_REG, 0x0) # opposite of I1_REG
    await tqv.write_word_reg(I2_1_REG, 0x0) # opposite of I1_REG
    await tqv.write_word_reg(TRIGGER_0_REG, ENTROPY_CELL_LOW)
    await tqv.write_word_reg(TRIGGER_1_REG, ENTROPY_CELL_HIGH)
    await ClockCycles(dut.clk, 10) # Wait for the trigger to take effect
    dut._log.info(f"Triggered entropy cells: {ENTROPY_CELL_HIGH:#x} {ENTROPY_CELL_LOW:#x}")

    # Print captured entropy for debugging
    captured_entropy_0 = await tqv.read_word_reg(CAPTURED_ENTROPY_0_REG)
    captured_entropy_1 = await tqv.read_word_reg(CAPTURED_ENTROPY_1_REG)
    dut._log.info(f"Captured entropy part 0: {captured_entropy_0:#x}")
    dut._log.info(f"Captured entropy part 1: {captured_entropy_1:#x}")

    #=== Step 3: Initialize UPT in PUF Mode ===#
    if MODE_SELECT == PUF_MODE:
        dut._log.info("----------------------------------")
        dut._log.info("Step 3: Initialize UPT in PUF Mode")
        control_reg = await tqv.read_word_reg(CONTROL_REG)
        await tqv.write_word_reg(CONTROL_REG, CORE_INIT | control_reg)
        await ClockCycles(dut.clk, 100) # Wait for initialization to complete
        dut._log.info("UPT peripheral initialized in PUF mode")

        # Read out state value to check Initialization
        test_state_0 = await tqv.read_word_reg(TEST_STATE_0_REG)
        test_state_1 = await tqv.read_word_reg(TEST_STATE_1_REG)
        dut._log.info(f"UPT test state after initialization part 0: {test_state_0:#x}")
        dut._log.info(f"UPT test state after initialization part 1: {test_state_1:#x}")

        # Disable the INIT bit
        control_reg = await tqv.read_word_reg(CONTROL_REG)
        await tqv.write_word_reg(CONTROL_REG, control_reg & ~CORE_INIT)


    # #=== Step 4: Calibrate UPT peripheral ===#
    dut._log.info("----------------------------------")
    dut._log.info("Step 4: Calibrate UPT peripheral")
    
    # Set the number of calibration cycles
    calibration_cycles = 0x1 << 11  # Example: 2^11 cycles
    await tqv.write_word_reg(CALIBRATION_CYCLES_REG, calibration_cycles)  # Set calibration cycles
    cycle_reg = await tqv.read_word_reg(CALIBRATION_CYCLES_REG) # read out the value to verify and print it
    assert cycle_reg == calibration_cycles
    dut._log.info(f"Set calibration cycle: {calibration_cycles:#x} - Read out calibration cycles: {cycle_reg:#x}")
    
    # Trigger calibration
    control_reg = await tqv.read_word_reg(CONTROL_REG)
    await tqv.write_word_reg(CONTROL_REG, control_reg | CORE_CALIB)
    
    timeout = calibration_cycles*2  # Set a timeout for calibration
    status_reg = await tqv.read_word_reg(STATUS_REG)
    # if the calibration cycles is too short, the ready signal will asserted
    dut._log.info(f"UPT status before loop: {status_reg:#x}")
    # Wait for ready signal to be asserted
    while (await tqv.read_word_reg(STATUS_REG) & READY) == 0:
        status_reg = await tqv.read_word_reg(STATUS_REG)
        # dut._log.info(f"UPT status during calibration: {status_reg:#x}")
        await ClockCycles(dut.clk, 1)
        timeout -= 1
        if timeout <= 0:
            raise TimeoutError("UPT calibration timed out")
    
    dut._log.info("UPT peripheral is ready after calibration")

    #=== Step 5: Read UPT output ===#
    dut._log.info("----------------------------------")
    dut._log.info("Step 5: Read UPT output")
    read_reg = await tqv.read_word_reg(READOUT_REG)
    await tqv.write_word_reg(READOUT_REG, read_reg | READ_REQUEST) 

    # Maybe the time out is not necessary here
    # By the time we reach here, the ready signal should be asserted
    timeout = 64*2  # The ready signal should be asserted within 64 cycles for reading out 64-bit random data
    while (await tqv.read_word_reg(STATUS_REG) & READY) == 0:
        # status_reg = await tqv.read_word_reg(STATUS_REG)
        await ClockCycles(dut.clk, 1)
        timeout -= 1
        if timeout <= 0:
            raise TimeoutError("UPT read request timed out") 
    dut._log.info("UPT read request completed")

    # Read the random data
    sample_0 = await tqv.read_word_reg(SAMPLE_0_REG)
    sample_1 = await tqv.read_word_reg(SAMPLE_1_REG)
    full_sample = (sample_1 << 32) | sample_0

    # Deassert the read request
    read_reg = await tqv.read_word_reg(READOUT_REG)
    await tqv.write_word_reg(READOUT_REG, read_reg & ~READ_REQUEST)
    dut._log.info(f"UPT sample data: 0x{full_sample:016x}")

    # #=== Step 6: Repeat to read several random numbers ===#
    if MODE_SELECT == RANDOM_MODE:
        dut._log.info("----------------------------------")
        dut._log.info("Step 6: Repeat to read several random numbers")
        for i in range(5):
            read_reg = await tqv.read_word_reg(READOUT_REG)
            await tqv.write_word_reg(READOUT_REG, read_reg | READ_REQUEST) 

            # Again, maybe the time out is not necessary here
            timeout = 64*2  # The ready signal should be asserted within 64 cycles for reading out 64-bit random data
            while (await tqv.read_word_reg(STATUS_REG) & READY) == 0:
                # status_reg = await tqv.read_word_reg(STATUS_REG)
                await ClockCycles(dut.clk, 1)
                timeout -= 1
                if timeout <= 0:
                    raise TimeoutError("UPT read request timed out") 

            sample_0 = await tqv.read_word_reg(SAMPLE_0_REG) # Read the random data part 0
            sample_1 = await tqv.read_word_reg(SAMPLE_1_REG) # Read the random data part 1
            full_sample = (sample_1 << 32) | sample_0
            read_reg = await tqv.read_word_reg(READOUT_REG) # Deassert the read request

            await tqv.write_word_reg(READOUT_REG, read_reg & ~READ_REQUEST)
            dut._log.info(f"UPT sample data {i+1}: 0x{full_sample:016x}")

    dut._log.info("Test completed successfully")