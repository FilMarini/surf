##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the
## terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Exercise the unchanged 32-bit MR key format with one physical entry.
# - Insert one MR, then look it up by its returned key.
# - Confirm a second allocation fails while the one physical slot is occupied.
# - Probe and remove a key whose seven-bit index exceeds physical capacity.
#   Neither operation may alias or invalidate the inserted entry.
# - Remove the valid key and clear the table through the actual request/response
#   FIFOs and their ready/valid handshakes.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.ethernet.RoCEv2.roce_test_utils import roce_rtl_sources


RTL_SOURCES = roce_rtl_sources("TagVecSrv.vhd", "MetaDataMRs.vhd")
MR_WORD = 123
BAD_KEY = (7 << 25) | MR_WORD


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(2, unit="ns")


async def response(dut):
    for _ in range(16):
        if int(dut.respValid_o.value):
            return int(dut.respData_o.value)
        await tick(dut)
    raise AssertionError("MR response timed out")


@cocotb.test()
async def rejects_out_of_range_key_without_alias(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst.value = 1
    dut.reqValid_i.value = 0
    dut.reqData_i.value = 0
    dut.respReady_i.value = 0
    dut.getMrLKey_i.value = 0
    dut.getMrRKey_i.value = 0
    dut.getMrSel_i.value = 1
    dut.clearEn_i.value = 0
    for _ in range(3):
        await tick(dut)
    dut.rst.value = 0
    await tick(dut)

    assert int(dut.reqReady_o.value) == 1
    dut.reqData_i.value = (1 << 251) | (MR_WORD << 65)
    dut.reqValid_i.value = 1
    await tick(dut)
    dut.reqValid_i.value = 0
    inserted = await response(dut)
    assert (inserted >> 250) == 1
    good_key = inserted & 0xFFFF_FFFF
    dut.getMrRKey_i.value = good_key
    dut.respReady_i.value = 1
    await tick(dut)
    dut.respReady_i.value = 0
    await Timer(1, unit="ns")
    assert int(dut.getMrValid_o.value) == 1
    assert int(dut.getMrData_o.value) == MR_WORD

    dut.reqData_i.value = (1 << 251) | ((MR_WORD + 1) << 65)
    dut.reqValid_i.value = 1
    await tick(dut)
    dut.reqValid_i.value = 0
    full_response = await response(dut)
    assert (full_response >> 250) == 0
    dut.respReady_i.value = 1
    await tick(dut)
    dut.respReady_i.value = 0
    assert int(dut.getMrValid_o.value) == 1
    assert int(dut.getMrData_o.value) == MR_WORD

    for index in (1, 4, 7, 127):
        dut.getMrRKey_i.value = (index << 25) | MR_WORD
        await Timer(1, unit="ns")
        assert int(dut.getMrValid_o.value) == 0
        assert int(dut.getMrData_o.value) == 0

    dut.reqData_i.value = (1 << 64) | (BAD_KEY << 32)
    dut.reqValid_i.value = 1
    await tick(dut)
    dut.reqValid_i.value = 0
    removed = await response(dut)
    assert (removed >> 250) == 0
    dut.respReady_i.value = 1
    await tick(dut)
    dut.respReady_i.value = 0
    dut.getMrRKey_i.value = good_key
    await Timer(1, unit="ns")
    assert int(dut.getMrValid_o.value) == 1
    assert int(dut.getMrData_o.value) == MR_WORD

    dut.reqData_i.value = (1 << 64) | (good_key << 32)
    dut.reqValid_i.value = 1
    await tick(dut)
    dut.reqValid_i.value = 0
    removed = await response(dut)
    assert (removed >> 250) == 1
    dut.respReady_i.value = 1
    await tick(dut)
    dut.respReady_i.value = 0
    await Timer(1, unit="ns")
    assert int(dut.getMrValid_o.value) == 0

    dut.reqData_i.value = (1 << 251) | ((MR_WORD + 1) << 65)
    dut.reqValid_i.value = 1
    await tick(dut)
    dut.reqValid_i.value = 0
    reused = await response(dut)
    assert (reused >> 250) == 1
    dut.respReady_i.value = 1
    await tick(dut)
    dut.respReady_i.value = 0
    dut.getMrRKey_i.value = reused & 0xFFFF_FFFF
    await Timer(1, unit="ns")
    assert int(dut.getMrValid_o.value) == 1
    assert int(dut.getMrData_o.value) == MR_WORD + 1

    dut.clearEn_i.value = 1
    await tick(dut)
    dut.clearEn_i.value = 0
    for _ in range(3):
        await tick(dut)
    assert int(dut.notEmpty_o.value) == 0


@pytest.mark.parametrize("parameters", [{"MAX_MR_PER_PD_G": 1}])
def test_MetaDataMRs(parameters):
    from tests.common.regression_utils import run_surf_vhdl_test

    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.metadatamrs",
        parameters=parameters,
        extra_vhdl_sources={"surf": RTL_SOURCES},
    )
