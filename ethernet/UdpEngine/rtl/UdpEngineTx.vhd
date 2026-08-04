-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: UDP TX Engine Module
-- Note: UDP checksum checked in EthMac core
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity UdpEngineTx is
   generic (
      TPD_G          : time          := 1 ns;
      RST_POLARITY_G : sl            := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G    : boolean       := false;
      -- UDP General Generic
      SIZE_G         : positive      := 1;
      TX_FLOW_CTRL_G : boolean       := true;  -- True: Blow off the UDP TX data if link down, False: Backpressure until TX link is up
      IS_CLIENT_G    : boolean       := false;
      PORT_G         : PositiveArray := (0 => 8192));
   port (
      -- Interface to IPV4 Engine
      obUdpMaster   : out AxiStreamMasterType;
      obUdpSlave    : in  AxiStreamSlaveType;
      -- Interface to User Application
      linkUp        : out slv(SIZE_G-1 downto 0);
      localMac      : in  slv(47 downto 0);
      localIp       : in  slv(31 downto 0);
      remotePort    : in  Slv16Array(SIZE_G-1 downto 0);
      remoteIp      : in  Slv32Array(SIZE_G-1 downto 0);
      remoteMac     : in  Slv48Array(SIZE_G-1 downto 0);
      ibMasters     : in  AxiStreamMasterArray(SIZE_G-1 downto 0);
      ibSlaves      : out AxiStreamSlaveArray(SIZE_G-1 downto 0);
      arpTabPos     : out Slv8Array(SIZE_G-1 downto 0);
      arpTabFound   : in  slv(SIZE_G-1 downto 0)        := (others => '0');
      arpTabIpAddr  : in  Slv32Array(SIZE_G-1 downto 0) := (others => (others => '0'));
      arpTabMacAddr : in  Slv48Array(SIZE_G-1 downto 0) := (others => (others => '0'));
      -- RoCE-only packet-local path sideband for client channel zero:
      -- [31:0] destIp, [39:32] traffic class, [47:40] hop limit,
      -- [55:48] source selector, [56] override valid.
      rocePathMetaValid : in  sl := '0';
      rocePathMetaData  : in  slv(56 downto 0) := (others => '0');
      rocePathMetaReady : out sl := '0';
      roceArpLookupValid : out sl := '0';
      roceArpLookupIp    : out slv(31 downto 0) := (others => '0');
      -- Interface to DHCP Engine
      obDhcpMaster  : in  AxiStreamMasterType           := AXI_STREAM_MASTER_INIT_C;
      obDhcpSlave   : out AxiStreamSlaveType;
      -- Clock and Reset
      clk           : in  sl;
      rst           : in  sl);
end UdpEngineTx;

architecture rtl of UdpEngineTx is

   constant PORT_C : Slv16Array(SIZE_G-1 downto 0) := EthPortArrayBigEndian(PORT_G, SIZE_G);

   type StateType is (
      IDLE_S,
      ACC_ARP_TAB_S,
      DHCP_HDR_S,
      HDR_S,
      PATH_RESOLVE_S,
      PATH_HEADER0_S,
      PATH_HEADER1_S,
      PATH_DROP_S,
      DHCP_BUFFER_S,
      BUFFER_S,
      LAST_S);

   type RegType is record
      linkUp      : slv(SIZE_G-1 downto 0);
      tKeep       : slv(15 downto 0);
      tData       : slv(127 downto 0);
      tLast       : sl;
      eofe        : sl;
      chPntr      : natural range 0 to SIZE_G-1;
      index       : natural range 0 to SIZE_G-1;
      arpPos      : Slv8Array(SIZE_G-1 downto 0);
      arpTabPos   : Slv8Array(SIZE_G-1 downto 0);
      obDhcpSlave : AxiStreamSlaveType;
      ibSlaves    : AxiStreamSlaveArray(SIZE_G-1 downto 0);
      txMaster    : AxiStreamMasterType;
      pathFirstBeat : AxiStreamMasterType;
      pathMeta      : slv(56 downto 0);
      pathActive    : sl;
      pathIp        : slv(31 downto 0);
      pathMac       : slv(47 downto 0);
      pathSrcIp     : slv(31 downto 0);
      pathSrcPort   : slv(15 downto 0);
      pathDstPort   : slv(15 downto 0);
      pathConfigOk  : sl;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      linkUp      => (others => '0'),
      tKeep       => (others => '0'),
      tData       => (others => '0'),
      tLast       => '0',
      eofe        => '0',
      chPntr      => 0,
      index       => 0,
      arpPos      => (others => (others => '0')),
      arpTabPos   => (others => (others => '0')),
      obDhcpSlave => AXI_STREAM_SLAVE_INIT_C,
      ibSlaves    => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      pathFirstBeat => AXI_STREAM_MASTER_INIT_C,
      pathMeta      => (others => '0'),
      pathActive    => '0',
      pathIp        => (others => '0'),
      pathMac       => (others => '0'),
      pathSrcIp     => (others => '0'),
      pathSrcPort   => (others => '0'),
      pathDstPort   => (others => '0'),
      pathConfigOk  => '0',
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;
   signal obUdpMasterInt : AxiStreamMasterType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "TRUE";

begin

   comb : process (arpTabFound, arpTabIpAddr, arpTabMacAddr, ibMasters,
                   localIp, localMac, obDhcpMaster, obUdpMasterInt, obUdpSlave,
                   r, remoteIp, remoteMac,
                   remotePort, rocePathMetaData, rocePathMetaValid, rst,
                   txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.obDhcpSlave := AXI_STREAM_SLAVE_INIT_C;
      v.ibSlaves    := (others => AXI_STREAM_SLAVE_INIT_C);
      rocePathMetaReady <= '0';

      -- A RoCE route remains owned until its terminal output beat is accepted
      -- by the IPv4 engine.  Deliberate drops release it after the input frame
      -- has been drained instead.
      if (r.pathActive = '1') and (obUdpMasterInt.tValid = '1') and
         (obUdpMasterInt.tLast = '1') and (obUdpSlave.tReady = '1') then
         v.pathActive := '0';
         v.pathMeta   := (others => '0');
         v.pathIp     := (others => '0');
         v.pathMac    := (others => '0');
      end if;
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;

      for i in SIZE_G-1 downto 0 loop
         -- Check if link is up
         if (localMac /= 0) and         -- Non-zero local MAC address
                           (localIp /= 0) and      -- Non-zero local IP address
                           (PORT_G(i) /= 0) and    -- Non-zero local UDP port
                           (remoteMac(i) /= 0) and  -- Non-zero remote MAC address
                           (remoteIp(i) /= 0) and  -- Non-zero remote IP address
                           (remotePort(i) /= 0) then  -- Non-zero remote UDP port
            -- Link Up
            v.linkUp(i) := '1';
         else
            -- Link down
            v.linkUp(i) := '0';
         end if;
      end loop;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for roll over
            if (r.index = (SIZE_G-1)) then
               -- Reset the counter
               v.index := 0;
            else
               -- Increment the counter
               v.index := r.index + 1;
            end if;
            -- Channel zero's RoCE SOF and path item enter one ownership
            -- register on the same edge.  Acceptance depends only on that
            -- register being free, never on ARP or output readiness.
            if IS_CLIENT_G and (v.pathActive = '0') and
               (ibMasters(0).tValid = '1') and
               (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibMasters(0)) = '1') and
               (rocePathMetaValid = '1') then
               v.ibSlaves(0).tReady := '1';
               rocePathMetaReady    <= '1';
               v.pathFirstBeat      := ibMasters(0);
               v.pathMeta           := rocePathMetaData;
               v.pathActive         := '1';
               v.pathMac            := (others => '0');
               v.pathSrcIp          := localIp;
               v.pathSrcPort        := PORT_C(0);
               v.pathDstPort        := remotePort(0);
               if rocePathMetaData(56) = '1' then
                  v.pathIp := rocePathMetaData(31 downto 0);
               else
                  v.pathIp := remoteIp(0);
               end if;
               if (localMac /= 0) and (localIp /= 0) and
                  (PORT_G(0) /= 0) and (remotePort(0) /= 0) and
                  (((rocePathMetaData(56) = '1') and
                    (rocePathMetaData(31 downto 0) /= 0)) or
                   ((rocePathMetaData(56) = '0') and (remoteIp(0) /= 0))) then
                  v.pathConfigOk := '1';
               else
                  v.pathConfigOk := '0';
               end if;
               v.chPntr := 0;
               v.state  := PATH_RESOLVE_S;
            -- Do not start another frame while the preceding RoCE route is
            -- still retained in the output pipeline.
            elsif v.pathActive = '1' then
               null;
            -- Check for DHCP data and remote MAC is non-zero
            elsif (obDhcpMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Check for SOF
               if (ssiGetUserSof(EMAC_AXIS_CONFIG_C, obDhcpMaster) = '1') then
                  -- Write the first header
                  v.txMaster.tValid               := '1';
                  v.txMaster.tData(47 downto 0)   := (others => '1');  -- Destination MAC address
                  v.txMaster.tData(63 downto 48)  := x"0000";     -- All 0s
                  v.txMaster.tData(95 downto 64)  := (others => '0');  -- Source IP address
                  v.txMaster.tData(127 downto 96) := (others => '1');  -- Destination IP address
                  ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
                  -- Next state
                  v.state                         := DHCP_HDR_S;
               else
                  -- Blow off the data
                  v.obDhcpSlave.tReady := '1';
               end if;
            -- Check for data and remote MAC is non-zero
            elsif (ibMasters(r.index).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Check if need to access ARP Table
               if ibMasters(r.index).tDest = x"00" or IS_CLIENT_G = false then
                  -- Check if link down and blowing off the data
                  if (r.linkUp(r.index) = '0') and TX_FLOW_CTRL_G then
                     -- Blow off the data
                     v.ibSlaves(r.index).tReady := '1';
                  -- Check for SOF
                  elsif (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibMasters(r.index)) = '1') then
                     -- Check if link up
                     if (r.linkUp(r.index) = '1') then
                        -- Latch the index
                        v.chPntr                        := r.index;
                        -- Write the first header
                        v.txMaster.tValid               := '1';
                        v.txMaster.tData(47 downto 0)   := remoteMac(r.index);  -- Destination MAC address
                        v.txMaster.tData(63 downto 48)  := x"0000";  -- All 0s
                        v.txMaster.tData(95 downto 64)  := localIp;  -- Source IP address
                        v.txMaster.tData(127 downto 96) := remoteIp(r.index);  -- Destination IP address
                        ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
                        -- Next state
                        v.state                         := HDR_S;
                     end if;
                  else
                     -- Blow off the data
                     v.ibSlaves(r.index).tReady := '1';
                  end if;
               else
                  v.chPntr             := r.index;
                  v.arpTabPos(r.index) := ibMasters(r.index).tDest;
                  v.state              := ACC_ARP_TAB_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when PATH_RESOLVE_S =>
            -- Retain the accepted pair while the registered packet-local IP
            -- drives the ARP table and request engine.  An IP-only cache entry
            -- is not sufficient: both the matching IP and a nonzero MAC are
            -- required before header generation can begin.
            if (r.pathConfigOk = '0') and TX_FLOW_CTRL_G then
               v.state := PATH_DROP_S;
            elsif (arpTabFound(0) = '1') and
                  (arpTabIpAddr(0) = r.pathIp) and
                  (arpTabMacAddr(0) /= 0) then
               v.pathMac := arpTabMacAddr(0);
               v.state   := PATH_HEADER0_S;
            end if;
         ----------------------------------------------------------------------
         when PATH_HEADER0_S =>
            if v.txMaster.tValid = '0' then
               v.txMaster.tValid               := '1';
               v.txMaster.tData(47 downto 0)   := r.pathMac;
               v.txMaster.tData(63 downto 48)  := x"0000";
               v.txMaster.tData(95 downto 64)  := r.pathSrcIp;
               v.txMaster.tData(127 downto 96) := r.pathIp;
               if r.pathMeta(56) = '1' then
                  v.txMaster.tData(55 downto 48) := r.pathMeta(39 downto 32);
                  v.txMaster.tData(63 downto 56) := r.pathMeta(47 downto 40);
                  v.txMaster.tUser(7)            := '1';
               end if;
               ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
               v.state := PATH_HEADER1_S;
            end if;
         ----------------------------------------------------------------------
         when PATH_HEADER1_S =>
            if v.txMaster.tValid = '0' then
               v.txMaster.tValid               := '1';
               v.txMaster.tData(7 downto 0)    := x"00";
               v.txMaster.tData(15 downto 8)   := UDP_C;
               v.txMaster.tData(31 downto 16)  := x"0000";
               v.txMaster.tData(47 downto 32)  := r.pathSrcPort;
               v.txMaster.tData(63 downto 48)  := r.pathDstPort;
               v.txMaster.tData(79 downto 64)  := x"0000";
               v.txMaster.tData(95 downto 80)  := x"0000";
               v.txMaster.tData(127 downto 96) := r.pathFirstBeat.tData(31 downto 0);
               v.txMaster.tKeep(11 downto 0)   := x"FFF";
               v.txMaster.tKeep(15 downto 12)  := r.pathFirstBeat.tKeep(3 downto 0);
               v.tData(95 downto 0)            := r.pathFirstBeat.tData(127 downto 32);
               v.tData(127 downto 96)          := (others => '0');
               v.tKeep(11 downto 0)            := r.pathFirstBeat.tKeep(15 downto 4);
               v.tKeep(15 downto 12)           := (others => '0');
               v.tLast                         := r.pathFirstBeat.tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, r.pathFirstBeat);
               if v.tLast = '1' then
                  if v.tKeep /= 0 then
                     v.state := LAST_S;
                  else
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     v.state := IDLE_S;
                  end if;
               else
                  v.state := BUFFER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when PATH_DROP_S =>
            if (r.pathFirstBeat.tLast = '1') or
               (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, r.pathFirstBeat) = '1') then
               v.pathActive := '0';
               v.pathMeta   := (others => '0');
               v.pathIp     := (others => '0');
               v.state      := IDLE_S;
            elsif ibMasters(0).tValid = '1' then
               v.ibSlaves(0).tReady := '1';
               if (ibMasters(0).tLast = '1') or
                  (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(0)) = '1') then
                  v.pathActive := '0';
                  v.pathMeta   := (others => '0');
                  v.pathIp     := (others => '0');
                  v.state      := IDLE_S;
               end if;
            end if;
         -----------------------------------------------------------------------
         when ACC_ARP_TAB_S =>
            v.arpTabPos(r.chPntr) := ibMasters(r.chPntr).tDest;
            if arpTabFound(r.chPntr) = '0' then
               v.linkUp(r.chPntr)          := '0';
               -- Blow off the data..
               v.ibSlaves(r.chPntr).tReady := '1';
               -- ..until the last frame
               if (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1' or ibMasters(r.chPntr).tLast = '1') then
                  v.state := IDLE_S;
               end if;
            else
               -- Check if link down and blowing off the data
               if (r.linkUp(r.chPntr) = '0') and TX_FLOW_CTRL_G then
                  -- Blow off the data..
                  v.ibSlaves(r.chPntr).tReady := '1';
                  -- ..until the last frame
                  if (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1' or ibMasters(r.chPntr).tLast = '1') then
                     v.state := IDLE_S;
                  end if;
               -- Check for SOF
               elsif (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1') then
                  -- Check if link up
                  if (r.linkUp(r.chPntr) = '1') then
                     -- Latch the index
                     v.chPntr                        := r.chPntr;
                     -- Write the first header
                     v.txMaster.tValid               := '1';
                     v.txMaster.tData(47 downto 0)   := arpTabMacAddr(r.chPntr);  -- Destination MAC address
                     v.txMaster.tData(63 downto 48)  := x"0000";  -- All 0s
                     v.txMaster.tData(95 downto 64)  := localIp;  -- Source IP address
                     v.txMaster.tData(127 downto 96) := arpTabIpAddr(r.chPntr);  -- Destination IP address
                     ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
                     -- Next state
                     v.state                         := HDR_S;
                  end if;
               else
                  -- Blow off the data..
                  v.ibSlaves(r.chPntr).tReady := '1';
                  -- ..until the last frame
                  if (ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr)) = '1' or ibMasters(r.chPntr).tLast = '1') then
                     v.state := IDLE_S;
                  end if;
               end if;
            end if;

         ------------------------------------------------
         -- Notes: Non-Standard IPv4 Pseudo Header Format
         ------------------------------------------------
         -- tData[0][47:0]   = DST MAC Address
         -- tData[0][63:48]  = zeros
         -- tData[0][95:64]  = SRC IP Address
         -- tData[0][127:96] = DST IP address
         -- tData[1][7:0]    = zeros
         -- tData[1][15:8]   = Protocol Type = UDP
         -- tData[1][31:16]  = IPv4 Pseudo header length
         -- tData[1][47:32]  = SRC Port
         -- tData[1][63:48]  = DST Port
         -- tData[1][79:64]  = UDP Length
         -- tData[1][95:80]  = UDP Checksum
         -- tData[1][127:96] = UDP Datagram
         ------------------------------------------------
         ----------------------------------------------------------------------
         when DHCP_HDR_S =>
            -- Check if ready to move data
            if (obDhcpMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obDhcpSlave.tReady            := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               v.txMaster.tData(7 downto 0)    := x"00";  -- All 0s
               v.txMaster.tData(15 downto 8)   := UDP_C;  -- Protocol Type = UDP
               v.txMaster.tData(31 downto 16)  := x"0000";  -- IPv4 Pseudo header length = Calculated in EthMac core
               v.txMaster.tData(47 downto 32)  := DHCP_CPORT;  -- Source port
               v.txMaster.tData(63 downto 48)  := DHCP_SPORT;  -- Destination port
               v.txMaster.tData(79 downto 64)  := x"0000";  -- UDP length = Calculated in EthMac core
               v.txMaster.tData(95 downto 80)  := x"0000";  -- UDP checksum  = Calculated in EthMac core
               v.txMaster.tData(127 downto 96) := obDhcpMaster.tData(31 downto 0);  -- UDP Datagram
               v.txMaster.tKeep(11 downto 0)   := x"FFF";
               v.txMaster.tKeep(15 downto 12)  := obDhcpMaster.tKeep(3 downto 0);  -- UDP Datagram
               -- Track the leftovers
               v.tData(95 downto 0)            := obDhcpMaster.tData(127 downto 32);
               v.tData(127 downto 96)          := (others => '0');
               v.tKeep(11 downto 0)            := obDhcpMaster.tKeep(15 downto 4);
               v.tKeep(15 downto 12)           := (others => '0');
               v.tLast                         := obDhcpMaster.tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, obDhcpMaster);
               -- Check for tLast
               if (v.tLast = '1') then
                  -- Check the leftover tKeep is not empty
                  if (v.tKeep /= 0) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Set EOF and EOFE
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state          := IDLE_S;
                  end if;
               else
                  -- Next state
                  v.state := DHCP_BUFFER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when HDR_S =>
            -- Check if ready to move data
            if (ibMasters(r.chPntr).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.ibSlaves(r.chPntr).tReady     := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               v.txMaster.tData(7 downto 0)    := x"00";  -- All 0s
               v.txMaster.tData(15 downto 8)   := UDP_C;  -- Protocol Type = UDP
               v.txMaster.tData(31 downto 16)  := x"0000";  -- IPv4 Pseudo header length = Calculated in EthMac core
               v.txMaster.tData(47 downto 32)  := PORT_C(r.chPntr);  -- Source port
               v.txMaster.tData(63 downto 48)  := remotePort(r.chPntr);  -- Destination port
               v.txMaster.tData(79 downto 64)  := x"0000";  -- UDP length = Calculated in EthMac core
               v.txMaster.tData(95 downto 80)  := x"0000";  -- UDP checksum  = Calculated in EthMac core
               v.txMaster.tData(127 downto 96) := ibMasters(r.chPntr).tData(31 downto 0);  -- UDP Datagram
               v.txMaster.tKeep(11 downto 0)   := x"FFF";
               v.txMaster.tKeep(15 downto 12)  := ibMasters(r.chPntr).tKeep(3 downto 0);  -- UDP Datagram
               -- Track the leftovers
               v.tData(95 downto 0)            := ibMasters(r.chPntr).tData(127 downto 32);
               v.tData(127 downto 96)          := (others => '0');
               v.tKeep(11 downto 0)            := ibMasters(r.chPntr).tKeep(15 downto 4);
               v.tKeep(15 downto 12)           := (others => '0');
               v.tLast                         := ibMasters(r.chPntr).tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr));
               -- Check for tLast
               if (v.tLast = '1') then
                  -- Check the leftover tKeep is not empty
                  if (v.tKeep /= 0) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Set EOF and EOFE
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state          := IDLE_S;
                  end if;
               else
                  -- Next state
                  v.state := BUFFER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DHCP_BUFFER_S =>
            -- Check if ready to move data
            if (obDhcpMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.obDhcpSlave.tReady            := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               -- Move the data
               v.txMaster.tData(95 downto 0)   := r.tData(95 downto 0);
               v.txMaster.tData(127 downto 96) := obDhcpMaster.tData(31 downto 0);
               v.txMaster.tKeep(11 downto 0)   := r.tKeep(11 downto 0);
               v.txMaster.tKeep(15 downto 12)  := obDhcpMaster.tKeep(3 downto 0);
               -- Track the leftovers
               v.tData(95 downto 0)            := obDhcpMaster.tData(127 downto 32);
               v.tKeep(11 downto 0)            := obDhcpMaster.tKeep(15 downto 4);
               v.tLast                         := obDhcpMaster.tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, obDhcpMaster);
               -- Check for tLast
               if (v.tLast = '1') then
                  -- Check the leftover tKeep is not empty
                  if (v.tKeep /= 0) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Set EOF and EOFE
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state          := IDLE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BUFFER_S =>
            -- Check if ready to move data
            if (ibMasters(r.chPntr).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.ibSlaves(r.chPntr).tReady     := '1';
               -- Write the Second header
               v.txMaster.tValid               := '1';
               -- Move the data
               v.txMaster.tData(95 downto 0)   := r.tData(95 downto 0);
               v.txMaster.tData(127 downto 96) := ibMasters(r.chPntr).tData(31 downto 0);
               v.txMaster.tKeep(11 downto 0)   := r.tKeep(11 downto 0);
               v.txMaster.tKeep(15 downto 12)  := ibMasters(r.chPntr).tKeep(3 downto 0);
               -- Track the leftovers
               v.tData(95 downto 0)            := ibMasters(r.chPntr).tData(127 downto 32);
               v.tKeep(11 downto 0)            := ibMasters(r.chPntr).tKeep(15 downto 4);
               v.tLast                         := ibMasters(r.chPntr).tLast;
               v.eofe                          := ssiGetUserEofe(EMAC_AXIS_CONFIG_C, ibMasters(r.chPntr));
               -- Check for tLast
               if (v.tLast = '1') then
                  -- Check the leftover tKeep is not empty
                  if (v.tKeep /= 0) then
                     -- Next state
                     v.state := LAST_S;
                  else
                     -- Set EOF and EOFE
                     v.txMaster.tLast := '1';
                     ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state          := IDLE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data
               v.txMaster.tValid              := '1';
               v.txMaster.tData(127 downto 0) := r.tData;
               v.txMaster.tKeep(15 downto 0)  := r.tKeep;
               v.txMaster.tLast               := '1';
               ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.txMaster, r.eofe);
               -- Next state
               v.state                        := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      ibSlaves    <= v.ibSlaves;
      obDhcpSlave <= v.obDhcpSlave;
      txMaster    <= r.txMaster;
      linkUp      <= r.linkUp;
      arpTabPos   <= v.arpTabPos;
      roceArpLookupValid <= r.pathActive;
      roceArpLookupIp    <= r.pathIp;

      -- Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_TxPipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         PIPE_STAGES_G  => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => obUdpMasterInt,
         mAxisSlave  => obUdpSlave);

   obUdpMaster <= obUdpMasterInt;

end rtl;
