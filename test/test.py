import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def wait_for_output(dut, expected, max_cycles=60):
    for _ in range(max_cycles):
        output = int(dut.uo_out.value)

        if output & 0b00111111 == expected:
            return

        await ClockCycles(dut.clk, 1)

    assert False, f"Expected {expected:06b}, got {output & 0b111111:06b}"


# ---------------------------------------------------------
# TEST 1: NORMAL TRAFFIC LIGHT SEQUENCE
# ---------------------------------------------------------

@cocotb.test()
async def test_traffic_light(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    await wait_for_output(dut, 0b001001)
    dut._log.info("RED: PASS")

    await wait_for_output(dut, 0b001010)
    dut._log.info("YELLOW: PASS")

    await wait_for_output(dut, 0b001100)
    dut._log.info("GREEN: PASS")

    await wait_for_output(dut, 0b001010)
    dut._log.info("SECOND YELLOW: PASS")

    await wait_for_output(dut, 0b001001)
    dut._log.info("SECOND RED: PASS")

    dut._log.info("NORMAL TRAFFIC TEST PASSED!")


# ---------------------------------------------------------
# TEST 2: PEDESTRIAN CROSSING
# ---------------------------------------------------------

@cocotb.test()
async def test_pedestrian(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    await wait_for_output(dut, 0b001100)
    dut._log.info("GREEN: PASS")

    # Press pedestrian button
    dut.ui_in.value = 0b00000001
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    dut._log.info("Pedestrian request registered!")

    # Wait for pedestrian crossing
    await wait_for_output(dut, 0b010001)

    dut._log.info("PEDESTRIAN GREEN: PASS")
    dut._log.info("Pedestrian crossing active!")

    # Wait until crossing ends
    await wait_for_output(dut, 0b001010)

    dut._log.info("Pedestrian crossing completed!")
    dut._log.info("PEDESTRIAN TEST PASSED!")


# ---------------------------------------------------------
# TEST 3: PEDESTRIAN BUZZER
# ---------------------------------------------------------

@cocotb.test()
async def test_buzzer(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    await wait_for_output(dut, 0b001100)

    # Request crossing
    dut.ui_in.value = 0b00000001
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    await wait_for_output(dut, 0b010001)

    # Wait for buzzer ON
    for _ in range(10):
        output = int(dut.uo_out.value)

        if output & 0b100000:
            break

        await ClockCycles(dut.clk, 1)
    else:
        assert False, "Buzzer did not turn ON"

    dut._log.info("BUZZER ON: PASS")

    # Wait for buzzer OFF
    for _ in range(10):
        await ClockCycles(dut.clk, 1)

        output = int(dut.uo_out.value)

        if not (output & 0b100000):
            break
    else:
        assert False, "Buzzer did not turn OFF"

    dut._log.info("BUZZER OFF: PASS")
    dut._log.info("PEDESTRIAN + BUZZER TEST PASSED!")


# ---------------------------------------------------------
# TEST 4: EMERGENCY TOGGLE
# ---------------------------------------------------------

@cocotb.test()
async def test_emergency_toggle(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    await wait_for_output(dut, 0b001100)
    dut._log.info("GREEN: PASS")

    # Emergency ON
    dut.ui_in.value = 0b00000010
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    await wait_for_output(dut, 0b001001)
    dut._log.info("EMERGENCY ON - ALL RED: PASS")

    await ClockCycles(dut.clk, 3)

    output = int(dut.uo_out.value)

    assert output & 0b001001 == 0b001001, \
        f"Emergency should remain ON, got {output:08b}"

    dut._log.info("EMERGENCY REMAINS ON: PASS")

    # Emergency OFF
    dut.ui_in.value = 0b00000010
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    await wait_for_output(dut, 0b001001)
    dut._log.info("EMERGENCY OFF - RED: PASS")

    dut._log.info("EMERGENCY TOGGLE TEST PASSED!")
