-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RoCEv2TxPathPipeline
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;
use surf.SsiPkg.all;
use surf.RocePkg.all;

entity RoCEv2TxPathPipelineFlatWrapper is
   port (
      clk           : in  sl;
      rst           : in  sl;
      qpPathMeta    : in  slv(2*ROCE_TX_PATH_META_W_C-1 downto 0);
      sAxisTValid   : in  sl;
      sAxisTData    : in  slv(127 downto 0);
      sAxisTKeep    : in  slv(15 downto 0);
      sAxisTLast    : in  sl;
      sAxisTReady   : out sl;
      sAxisTDest    : in  slv(7 downto 0);
      sAxisSof      : in  sl;
      mAxisTValid   : out sl;
      mAxisTData    : out slv(127 downto 0);
      mAxisTKeep    : out slv(15 downto 0);
      mAxisTLast    : out sl;
      mAxisTReady   : in  sl;
      mAxisTDest    : out slv(7 downto 0);
      mAxisSof      : out sl;
      pathMetaValid : out sl;
      pathMetaData  : out slv(ROCE_TX_PATH_META_W_C-1 downto 0);
      pathMetaReady : in  sl);
end entity RoCEv2TxPathPipelineFlatWrapper;

architecture rtl of RoCEv2TxPathPipelineFlatWrapper is

   signal sMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   inputComb : process (sAxisSof, sAxisTData, sAxisTDest, sAxisTKeep,
                        sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      v.tDest(7 downto 0)   := sAxisTDest;
      ssiSetUserSof(EMAC_AXIS_CONFIG_C, v, sAxisSof);
      sMaster               <= v;
   end process inputComb;

   outputView : process (mMaster) is
   begin
      mAxisTValid <= mMaster.tValid;
      mAxisTData  <= mMaster.tData(127 downto 0);
      mAxisTKeep  <= mMaster.tKeep(15 downto 0);
      mAxisTLast  <= mMaster.tLast;
      mAxisTDest  <= mMaster.tDest(7 downto 0);
      mAxisSof    <= ssiGetUserSof(EMAC_AXIS_CONFIG_C, mMaster);
   end process outputView;

   sAxisTReady  <= sSlave.tReady;
   mSlave.tReady <= mAxisTReady;

   U_DUT : entity surf.RoCEv2TxPathPipeline
      generic map (
         MAX_QP_G => 2)
      port map (
         clk           => clk,
         rst           => rst,
         sAxisMaster   => sMaster,
         sAxisSlave    => sSlave,
         qpPathMeta    => qpPathMeta,
         mAxisMaster   => mMaster,
         mAxisSlave    => mSlave,
         pathMetaValid => pathMetaValid,
         pathMetaData  => pathMetaData,
         pathMetaReady => pathMetaReady);

end architecture rtl;
