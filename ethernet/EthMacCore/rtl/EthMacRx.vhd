-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ethernet MAC RX Wrapper
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.AxiStreamPkg.all;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

entity EthMacRx is
  generic (
    -- Simulation Generics
    TPD_G          : time                  := 1 ns;
    -- MAC Configurations
    PAUSE_EN_G     : boolean               := true;
    PHY_TYPE_G     : string                := "XGMII";
    JUMBO_G        : boolean               := true;
    -- AXI-Stream Configuration
    PRIM_CONFIG_G  : AxiStreamConfigType   := EMAC_AXIS_CONFIG_C;
    -- Non-VLAN Configurations
    FILT_EN_G      : boolean               := false;
    BYP_EN_G       : boolean               := false;
    BYP_ETH_TYPE_G : slv(15 downto 0)      := x"0000";
    -- VLAN Configurations
    VLAN_EN_G      : boolean               := false;
    VLAN_SIZE_G    : positive range 1 to 8 := 1;
    VLAN_VID_G     : Slv12Array            := (0 => x"001");
    -- Internal RAM sythesis mode
    SYNTH_MODE_G   : string                := "inferred");
  port (
    -- Clock and Reset
    ethClkEn     : in  sl;
    ethClk       : in  sl;
    ethRst       : in  sl;
    -- Primary Interface
    mPrimMaster  : out AxiStreamMasterType;
    mPrimCtrl    : in  AxiStreamCtrlType;
    -- Bypass Interface
    mBypMaster   : out AxiStreamMasterType;
    mBypCtrl     : in  AxiStreamCtrlType;
    -- VLAN Interfaces
    mVlanMasters : out AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
    mVlanCtrl    : in  AxiStreamCtrlArray(VLAN_SIZE_G-1 downto 0);
    -- XLGMII PHY Interface
    xlgmiiRxd    : in  slv(127 downto 0);
    xlgmiiRxc    : in  slv(15 downto 0);
    -- XGMII PHY Interface
    xgmiiRxd     : in  slv(63 downto 0);
    xgmiiRxc     : in  slv(7 downto 0);
    -- GMII PHY Interface
    gmiiRxDv     : in  sl;
    gmiiRxEr     : in  sl;
    gmiiRxd      : in  slv(7 downto 0);
    -- Flow Control Interface
    rxPauseReq   : out sl;
    rxPauseValue : out slv(15 downto 0);
    -- Configuration and status
    phyReady     : in  sl;
    ethConfig    : in  EthMacConfigType;
    rxCountEn    : out sl;
    rxCrcError   : out sl);
end EthMacRx;

architecture mapping of EthMacRx is

  constant ROCE_CRC32_AXI_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => 32,
    TDEST_BITS_C  => 8,
    TID_BITS_C    => 0,
    TKEEP_MODE_C  => TKEEP_COMP_C,
    TUSER_BITS_C  => 4,
    TUSER_MODE_C  => TUSER_FIRST_LAST_C);

  signal macIbMaster            : AxiStreamMasterType;
  signal pauseMaster            : AxiStreamMasterType;
  signal pauseMasters           : AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
  signal csumMaster             : AxiStreamMasterType;
  signal bypassMaster           : AxiStreamMasterType;
  signal csumMasterRoCE         : AxiStreamMasterType;
  signal csumMasterDly          : AxiStreamMasterType;
  signal csumSlaveDly           : AxiStreamSlaveType;
  signal csumMastersRoCE        : AxiStreamMasterArray(1 downto 0);
  signal csumSlavesRoCE         : AxiStreamSlaveArray(1 downto 0);
  signal csumMasterUdp          : AxiStreamMasterType;
  signal csumiCrcMaster         : AxiStreamMasterType;
  signal csumiCrcSlave          : AxiStreamSlaveType;
  signal readyForiCrcMaster     : AxiStreamMasterType;
  signal readyForiCrcSlave      : AxiStreamSlaveType;
  signal isRoCE                 : sl;
  signal crcStreamMaster_tdata  : slv(31 downto 0);
  signal crcStreamMaster_tvalid : sl;

begin

  -------------------
  -- RX Import Module
  -------------------
  U_Import : entity surf.EthMacRxImport
    generic map (
      TPD_G        => TPD_G,
      PHY_TYPE_G   => PHY_TYPE_G,
      SYNTH_MODE_G => SYNTH_MODE_G)
    port map (
      -- Clock and reset
      ethClkEn    => ethClkEn,
      ethClk      => ethClk,
      ethRst      => ethRst,
      -- AXIS Interface
      macIbMaster => macIbMaster,
      -- XLGMII PHY Interface
      xlgmiiRxd   => xlgmiiRxd,
      xlgmiiRxc   => xlgmiiRxc,
      -- XGMII PHY Interface
      xgmiiRxd    => xgmiiRxd,
      xgmiiRxc    => xgmiiRxc,
      -- GMII PHY Interface
      gmiiRxDv    => gmiiRxDv,
      gmiiRxEr    => gmiiRxEr,
      gmiiRxd     => gmiiRxd,
      -- Configuration and status
      phyReady    => phyReady,
      rxCountEn   => rxCountEn,
      rxCrcError  => rxCrcError);

  ------------------
  -- RX Pause Module
  ------------------
  U_Pause : entity surf.EthMacRxPause
    generic map (
      TPD_G       => TPD_G,
      PAUSE_EN_G  => PAUSE_EN_G,
      VLAN_EN_G   => VLAN_EN_G,
      VLAN_SIZE_G => VLAN_SIZE_G,
      VLAN_VID_G  => VLAN_VID_G)
    port map (
      -- Clock and Reset
      ethClk       => ethClk,
      ethRst       => ethRst,
      -- Incoming data from MAC
      sAxisMaster  => macIbMaster,
      -- Outgoing data
      mAxisMaster  => pauseMaster,
      mAxisMasters => pauseMasters,
      -- Pause Values
      rxPauseReq   => rxPauseReq,
      rxPauseValue => rxPauseValue);

  ------------------------------
  -- RX Non-VLAN Checksum Module
  ------------------------------
  U_Csum : entity surf.EthMacRxCsum
    generic map (
      TPD_G   => TPD_G,
      JUMBO_G => JUMBO_G,
      VLAN_G  => false)
    port map (
      -- Clock and Reset
      ethClk      => ethClk,
      ethRst      => ethRst,
      -- Configurations
      ipCsumEn    => ethConfig.ipCsumEn,
      tcpCsumEn   => ethConfig.tcpCsumEn,
      udpCsumEn   => ethConfig.udpCsumEn,
      isRoCE      => isRoCE,
      -- Outbound data to MAC
      sAxisMaster => pauseMaster,
      mAxisMaster => csumMaster);

  --------------------------
  -- RX VLAN Checksum Module
  --------------------------
  GEN_VLAN : if (VLAN_EN_G = true) generate
    GEN_VEC :
    for i in (VLAN_SIZE_G-1) downto 0 generate
      U_Csum : entity surf.EthMacRxCsum
        generic map (
          TPD_G   => TPD_G,
          JUMBO_G => JUMBO_G,
          VLAN_G  => true)
        port map (
          -- Clock and Reset
          ethClk      => ethClk,
          ethRst      => ethRst,
          -- Configurations
          ipCsumEn    => '1',
          tcpCsumEn   => '1',
          udpCsumEn   => '1',
          -- Outbound data to MAC
          sAxisMaster => pauseMasters(i),
          mAxisMaster => mVlanMasters(i));
    end generate GEN_VEC;
  end generate;

  BYPASS_VLAN : if (VLAN_EN_G = false) generate
    -- Terminate Unused buses
    mVlanMasters <= (others => AXI_STREAM_MASTER_INIT_C);
  end generate;

  ----------------------------------------------------------------------------
  -- RoCE iCRC check
  ----------------------------------------------------------------------------
  p_RoCE_switch : process (csumMaster, isRoCE, readyForiCrcMaster,
                           readyForiCrcSlave) is
  begin  -- process p_RoCE_switch
    if isRoCE = '1' then
      -- Input connection
      csumMasterRoCE <= csumMaster;
      -- Output connection
      csumMasterUdp  <= readyForiCrcMaster;
    else
      csumMasterUdp <= csumMaster;
    end if;
  end process p_RoCE_switch;

  -- double the stream
  U_Repeater : entity surf.AxiStreamRepeater
    generic map (
      TPD_G         => TPD_G,
      NUM_MASTERS_G => 2)
    port map (
      axisClk      => ethClk,
      axisRst      => ethRst,
      sAxisMaster  => csumMasterRoce,
      sAxisSlave   => open,
      mAxisMasters => csumMastersRoCE,
      mAxisSlaves  => csumSlavesRoCE);

  -- pipeline the second stream to wait for iCrc
  U_Pipeline : entity surf.AxiStreamPipeline
    generic map (
      TPD_G         => TPD_G,
      PIPE_STAGES_G => 19)
    port map (
      axisClk     => ethClk,
      axisRst     => ethRst,
      sAxisMaster => csumMastersRoCE(1),
      sAxisSlave  => csumSlavesRoCE(1),
      mAxisMaster => csumMasterDly,
      mAxisSlave  => csumSlaveDly);

  U_iCrc : entity surf.AxiStreamPrepareForICrc
    generic map (
      TPD_G => TPD_G)
    port map (
      axisClk     => ethClk,
      axisRst     => ethRst,
      isRoCE      => isRoCE,
      sAxisMaster => csumMastersRoCE(0),
      sAxisSlave  => csumSlavesRoCE(0),
      mAxisMaster => csumiCrcMaster,
      mAxisSlave  => csumiCrcSlave);

  U_Compact : entity surf.AxiStreamCompact
    generic map (
      TPD_G               => TPD_G,
      SLAVE_AXI_CONFIG_G  => PRIM_CONFIG_G,
      MASTER_AXI_CONFIG_G => ROCE_CRC32_AXI_CONFIG_C)
    port map (
      axisClk     => ethClk,
      axisRst     => ethRst,
      sAxisMaster => csumiCrcMaster,
      sAxisSlave  => csumiCrcSlave,
      isRoCE      => isRoCE,
      mAxisMaster => readyForiCrcMaster,
      mAxisSlave  => readyForiCrcSlave);

  U_iCrcIn : entity surf.CrcAxiStreamWrapperRecv
    port map (
      CLK                => ethClk,
      RST                => ethRst,
      s_axis_tvalid      => readyForiCrcMaster.tValid,
      s_axis_tdata       => readyForiCrcMaster.tData(255 downto 0),
      s_axis_tkeep       => readyForiCrcMaster.tKeep(31 downto 0),
      s_axis_tlast       => readyForiCrcMaster.tLast,
      s_axis_tuser       => readyForiCrcMaster.tUser(0),
      s_axis_tready      => readyForiCrcSlave.tReady,
      m_crc_stream_data  => crcStreamMaster_tdata,
      m_crc_stream_valid => crcStreamMaster_tvalid,
      m_crc_stream_ready => '1');

  -------------------
  -- RX Bypass Module
  -------------------
  U_Bypass : entity surf.EthMacRxBypass
    generic map (
      TPD_G          => TPD_G,
      BYP_EN_G       => BYP_EN_G,
      BYP_ETH_TYPE_G => BYP_ETH_TYPE_G)
    port map (
      -- Clock and Reset
      ethClk      => ethClk,
      ethRst      => ethRst,
      -- Incoming data from MAC
      sAxisMaster => csumMasterUdp,
      -- Outgoing primary data
      mPrimMaster => bypassMaster,
      -- Outgoing bypass data
      mBypMaster  => mBypMaster);

  -------------------
  -- RX Filter Module
  -------------------
  U_Filter : entity surf.EthMacRxFilter
    generic map (
      TPD_G     => TPD_G,
      FILT_EN_G => FILT_EN_G)
    port map (
      -- Clock and Reset
      ethClk      => ethClk,
      ethRst      => ethRst,
      -- Incoming data from MAC
      sAxisMaster => bypassMaster,
      -- Outgoing data
      mAxisMaster => mPrimMaster,
      mAxisCtrl   => mPrimCtrl,
      -- Configuration
      dropOnPause => ethConfig.dropOnPause,
      macAddress  => ethConfig.macAddress,
      filtEnable  => ethConfig.filtEnable);

end mapping;
