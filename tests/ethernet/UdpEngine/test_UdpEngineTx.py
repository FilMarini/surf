##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Exercise the UDP TX path across normal server traffic and DHCP
#   passthrough traffic.
# - Stimulus: Drive one application payload with a live remote endpoint, then
#   drive one DHCP payload through the dedicated DHCP ingress.
# - Checks: The emitted pseudo-UDP frames must contain the expected source and
#   destination metadata, and `linkUp` must assert once the endpoint is valid.
# - Timing: The tests wait on accepted AXIS transfers instead of assuming fixed
#   latency so the TX state machine and pipeline remain visible.

from __future__ import annotations

import os

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    frame_beats_from_bytes,
    payload_from_beats,
    recv_frame,
    send_contiguous_frame,
    cycle,
)
from tests.ethernet.UdpEngine.udp_test_utils import (
    DHCP_CLIENT_PORT,
    DHCP_SERVER_PORT,
    LEGACY_IPS,
    LEGACY_IP_CFGS,
    LEGACY_MAC_WIRES,
    LEGACY_MAC_CFGS,
    UDP_RTL_SOURCES,
    UDP_SERVER_PORT,
    build_udp_tx_pseudo_frame,
    setup_udp_tx_bench,
    wait_for_link_up,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/UdpEngineTxFlatWrapper.vhd"


@cocotb.test()
async def udp_engine_tx_server_payload_header_test(dut):
    bench = await setup_udp_tx_bench(dut)

    # Wait for the wrapper-visible `linkUp` output before sending traffic so
    # the test matches the contract exposed to the integrated top-level logic.
    await wait_for_link_up(dut.linkUp, clk=bench.clk)

    payload = b"udp-tx-server-payload"
    send_task = cocotb.start_soon(
        send_contiguous_frame(bench.source, frame_beats_from_bytes(payload), clk=bench.clk)
    )
    # The sink observes the internal pseudo-header stream, so compare against a
    # pseudo-header builder rather than a full Ethernet wire image.
    observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=64,
    )
    await send_task

    assert payload_from_beats(observed) == build_udp_tx_pseudo_frame(
        dst_mac=LEGACY_MAC_WIRES[1],
        src_ip=LEGACY_IPS[0],
        dst_ip=LEGACY_IPS[1],
        # The standalone TX wrapper seeds both local and remote server ports to
        # 8192 so the pseudo-header reflects that symmetric default socket.
        src_port=UDP_SERVER_PORT,
        dst_port=UDP_SERVER_PORT,
        payload=payload,
    )


@cocotb.test()
async def udp_engine_tx_dhcp_passthrough_test(dut):
    bench = await setup_udp_tx_bench(dut)

    # DHCP bypasses the normal remote-endpoint registers and always targets
    # the broadcast client/server socket pair.
    dhcp_payload = b"dhcp-client-discover"
    dhcp_send = cocotb.start_soon(
        send_contiguous_frame(bench.dhcp_source, frame_beats_from_bytes(dhcp_payload), clk=bench.clk)
    )
    observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=64,
    )
    await dhcp_send

    assert payload_from_beats(observed) == build_udp_tx_pseudo_frame(
        # DHCP always broadcasts from client port 68 to server port 67.
        dst_mac=0xFFFFFFFFFFFF,
        src_ip="0.0.0.0",
        dst_ip="255.255.255.255",
        src_port=DHCP_CLIENT_PORT,
        dst_port=DHCP_SERVER_PORT,
        payload=dhcp_payload,
    )


@cocotb.test()
async def udp_engine_tx_roce_pair_is_buffered_before_arp_test(dut):
    if os.getenv("IS_CLIENT_G", "false").lower() != "true":
        return

    bench = await setup_udp_tx_bench(dut)
    payload = b"latched-roce"
    traffic_class = 0xA3
    hop_limit = 0x17
    path_meta = (
        LEGACY_IP_CFGS[2]
        | (traffic_class << 32)
        | (hop_limit << 40)
        | (1 << 56)
    )

    # Keep ARP unresolved and the output blocked.  The complete first payload
    # beat and metadata must still be accepted into the paired ingress slot.
    dut.mUdpTReady.value = 0
    dut.rocePathMetaData.value = path_meta
    dut.rocePathMetaValid.value = 1
    await bench.source.send(frame_beats_from_bytes(payload)[0], clk=bench.clk)
    dut.rocePathMetaValid.value = 0
    dut.rocePathMetaData.value = 0
    await cycle(bench.clk, 2)

    assert int(dut.roceArpLookupValid.value) == 1
    assert int(dut.roceArpLookupIp.value) == LEGACY_IP_CFGS[2]

    # Mutating every upstream path input after acceptance must not alter the
    # packet-owned route or first payload beat.
    dut.remoteIp.value = LEGACY_IP_CFGS[3]
    dut.remoteMac.value = LEGACY_MAC_CFGS[3]
    await cycle(bench.clk, 2)
    assert int(dut.roceArpLookupIp.value) == LEGACY_IP_CFGS[2]

    dut.arpTabIpAddr.value = LEGACY_IP_CFGS[2]
    dut.arpTabMacAddr.value = LEGACY_MAC_CFGS[2]
    dut.arpTabFound.value = 1
    observed = await recv_frame(
        bench.sink,
        clk=bench.clk,
        ready_signal=dut.mUdpTReady,
        timeout_cycles=64,
    )

    expected = bytearray(
        build_udp_tx_pseudo_frame(
            dst_mac=LEGACY_MAC_WIRES[2],
            src_ip=LEGACY_IPS[0],
            dst_ip=LEGACY_IPS[2],
            src_port=UDP_SERVER_PORT,
            dst_port=UDP_SERVER_PORT,
            payload=payload,
        )
    )
    expected[6] = traffic_class
    expected[7] = hop_limit
    assert payload_from_beats(observed) == bytes(expected)
    await cycle(bench.clk, 2)
    assert int(dut.roceArpLookupValid.value) == 0


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param({"IS_CLIENT_G": False}, id="udp_engine_tx_server"),
        pytest.param({"IS_CLIENT_G": True}, id="udp_engine_tx_client_roce"),
    ],
)
def test_UdpEngineTx(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.udpenginetxflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
