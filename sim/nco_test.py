# test_my_design.py (simple)

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def enable_disable_test(dut):
    """Test enable input."""

    dut.clk.value = 0
    dut.init.value = 1
    dut.freq_word.value = 100000    # per clock cycle    
    dut.freq_adjust.value = 0

    await cocotb.start(Clock(dut.clk, 10, units="ns").start())

    await RisingEdge(dut.clk)

    dut.init.value = 0

    await Timer(10, units="us")

    dut.enable.value = 1
    
    await Timer(100, units="us")
    # enabled for 100us == 10e3 cycles
    # for total phase of (10e3 - 1) * freq_word = (10e3 - 1) * 1e5

    dut.enable.value = 0

    await Timer(10, units="us")

    dut._log.info("phase is %s", dut.phase_acc.value)
    dut._log.info("phase is %d", dut.phase_acc.value.to_unsigned())
    assert dut.phase.value.to_unsigned() == 999900000, "phase is not 999900000!" # 1e9 - 1e5


@cocotb.test()
async def enable_disable_test_2(dut):
    """Test enable input."""

    dut.clk.value = 0
    dut.init.value = 1
    dut.freq_word.value = 100000    # per clock cycle    
    dut.freq_adjust.value = 0

    await cocotb.start(Clock(dut.clk, 10, units="ns").start())

    await RisingEdge(dut.clk)

    dut.init.value = 0

    await Timer(10, units="us")

    dut.enable.value = 1
    
    await Timer(100, units="us")
    # enabled for 100us == 10e3 cycles
    # for total phase of (10e3 - 1) * freq_word = (10e3) * 1e5
    await Timer(100, units="us")
    # enabled for 100us == 10e3 cycles
    # for total phase of (10e3 - 1) * freq_word = (10e3 - 1) * 1e5

    dut.enable.value = 0

    await Timer(10, units="us")

    dut._log.info("phase is %s", dut.phase_acc.value)
    dut._log.info("phase is %d", dut.phase_acc.value.to_unsigned())
    assert dut.phase.value.to_unsigned() == 1999900000, "phase is not 1999900000!" # 1e9 * 2 - 1e5


@cocotb.test()
async def freq_adjust_test(dut):
    """Test frequency adjust."""

    dut.clk.value = 0
    dut.init.value = 1
    dut.enable.value = 0
    dut.freq_word.value = 100000    # per clock cycle    
    dut.freq_adjust.value = 100     # per clock cycle 
    dut.freq_adj_zero.value = False
    dut.freq_adj_valid.value = True
    
    await cocotb.start(Clock(dut.clk, 10, units="ns").start())

    await RisingEdge(dut.clk)

    dut.init.value = 0

    await Timer(10, units="us")
    
    dut.enable.value = 1
    
    await Timer(100, units="us")
    # enabled for 100us == 10e3 cycles
    # for total phase of 10e3 - 1  (cycles) * (freq_word + freq_adjust) - freq_adjust
    # = (10e3 - 1) * (1e5 + 100) - 100  ?? why do we miss one cycle of freq_adj
        
    dut.enable.value = 0

    await Timer(10, units="us")

    dut._log.info("phase is %s", dut.phase_acc.value)
    dut._log.info("phase is %d", dut.phase_acc.value.to_unsigned())
    assert dut.phase.value.to_unsigned() == 1000899800, "phase is not 1000899800!" # 


@cocotb.test()
async def dynamic_freq_adjust_test(dut):
    """Test frequency adjust dynamically."""

    dut.clk.value = 0
    dut.init.value = 1
    dut.enable.value = 0
    dut.freq_word.value = 100000    # per clock cycle    
    dut.freq_adjust.value = 0
    dut.freq_adj_zero.value = True
    dut.freq_adj_valid.value = False
    
    await cocotb.start(Clock(dut.clk, 10, units="ns").start())

    await RisingEdge(dut.clk)

    dut.init.value = 0

    await Timer(10, units="us")

    dut.enable.value = 1
    
    await Timer(100, units="us")
    # enabled for 100us == 10e3 cycles
    # for total phase of 10e3 (cycles) * freq_word
    # = 10e3 * 1e5

    dut.freq_adjust.value = 100
    dut.freq_adj_zero.value = False
    dut.freq_adj_valid.value = True
    
    await Timer(100, units="us")
    # for total phase of 10e3 - 1 (cycles) * (freq_word + freq_adjust)
    # = (10e3 - 1) * (1e5 + 100) - 100  ??  again, not sure why we get slippage of freq_adj - delta time?

    dut.enable.value = 0

    await Timer(10, units="us")

    dut._log.info("phase is %s", dut.phase_acc.value)
    dut._log.info("phase is %d", dut.phase_acc.value.to_unsigned())
    assert dut.phase.value.to_unsigned() == 2000899800, "phase is not 2000899800!" 

