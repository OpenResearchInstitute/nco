# test_my_design.py (simple)

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def my_first_test(dut):
    """Try accessing the design."""

    dut.clk.value = 0
    dut.init.value = 1
    dut.phase_delta.value = 100000
    dut.phase_adjust.value = 0

    await cocotb.start(Clock(dut.clk, 10, units="ns").start())

    await RisingEdge(dut.clk)

    dut.init.value = 0

    await Timer(1, units="ms")

    dut._log.info("phase is %s", dut.phase_acc.value)
    #assert dut.phase.value != 0, "my_signal_2[0] is not 0!"

