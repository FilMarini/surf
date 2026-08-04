-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Registered RoCE TX beat and packet-path metadata coupling
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;
use surf.SsiPkg.all;
use surf.RocePkg.all;

entity RoCEv2TxPathPipeline is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      MAX_QP_G       : positive := 4);
   port (
      clk           : in  sl;
      rst           : in  sl := not RST_POLARITY_G;
      sAxisMaster   : in  AxiStreamMasterType;
      sAxisSlave    : out AxiStreamSlaveType;
      qpPathMeta    : in  slv(MAX_QP_G*ROCE_TX_PATH_META_W_C-1 downto 0);
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType;
      pathMetaValid : out sl;
      pathMetaData  : out slv(ROCE_TX_PATH_META_W_C-1 downto 0);
      pathMetaReady : in  sl);
end entity RoCEv2TxPathPipeline;

architecture rtl of RoCEv2TxPathPipeline is

   signal pipeInMaster : AxiStreamMasterType;
   signal pipeInMeta   : slv(ROCE_TX_PATH_META_W_C-1 downto 0);
   signal pipeMaster   : AxiStreamMasterType;
   signal pipeSlave    : AxiStreamSlaveType;
   signal pipeMeta     : slv(ROCE_TX_PATH_META_W_C-1 downto 0);

begin

   PREP : process (qpPathMeta, sAxisMaster) is
      variable v     : AxiStreamMasterType;
      variable meta  : slv(ROCE_TX_PATH_META_W_C-1 downto 0);
      variable qpIdx : natural range 0 to MAX_QP_G-1;
   begin
      v       := sAxisMaster;
      v.tDest := (others => '0');
      meta    := (others => '0');
      qpIdx   := 0;
      if to_integer(unsigned(sAxisMaster.tDest)) < MAX_QP_G then
         qpIdx := to_integer(unsigned(sAxisMaster.tDest));
      end if;
      meta := qpPathMeta((qpIdx+1)*ROCE_TX_PATH_META_W_C-1 downto
                         qpIdx*ROCE_TX_PATH_META_W_C);
      pipeInMaster <= v;
      pipeInMeta   <= meta;
   end process PREP;

   U_Pipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         SIDE_BAND_WIDTH_G => ROCE_TX_PATH_META_W_C,
         PIPE_STAGES_G     => 1)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => pipeInMaster,
         sSideBand   => pipeInMeta,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => pipeMaster,
         mSideBand   => pipeMeta,
         mAxisSlave  => pipeSlave);

   mAxisMaster     <= pipeMaster;
   pathMetaData    <= pipeMeta;
   pathMetaValid   <= pipeMaster.tValid and
                      ssiGetUserSof(EMAC_AXIS_CONFIG_C, pipeMaster);
   pipeSlave.tReady <= mAxisSlave.tReady and
                       (not ssiGetUserSof(EMAC_AXIS_CONFIG_C, pipeMaster) or
                        pathMetaReady);

   -- pragma translate_off
   ASSERTIONS : process (clk) is
      variable stalled      : boolean := false;
      variable heldMaster   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      variable heldMeta     : slv(ROCE_TX_PATH_META_W_C-1 downto 0) := (others => '0');
      variable sofAccepted  : boolean;
      variable metaAccepted : boolean;
   begin
      if rising_edge(clk) then
         if rst = RST_POLARITY_G then
            stalled    := false;
            heldMaster := AXI_STREAM_MASTER_INIT_C;
            heldMeta   := (others => '0');
         else
            if (sAxisMaster.tValid = '1') and
               (ssiGetUserSof(EMAC_AXIS_CONFIG_C, sAxisMaster) = '1') then
               assert to_integer(unsigned(sAxisMaster.tDest)) < MAX_QP_G
                  report "RoCEv2TxPathPipeline: out-of-range TX path QP tag"
                  severity failure;
            end if;

            assert pathMetaValid =
                   (pipeMaster.tValid and
                    ssiGetUserSof(EMAC_AXIS_CONFIG_C, pipeMaster))
               report "RoCEv2TxPathPipeline: metadata valid is not aligned to TX SOF"
               severity failure;

            if stalled then
               assert pipeMaster = heldMaster
                  report "RoCEv2TxPathPipeline: TX beat changed while atomically stalled"
                  severity failure;
               assert pipeMeta = heldMeta
                  report "RoCEv2TxPathPipeline: TX path metadata changed while stalled"
                  severity failure;
            end if;

            sofAccepted := (pipeMaster.tValid = '1') and
                           (ssiGetUserSof(EMAC_AXIS_CONFIG_C, pipeMaster) = '1') and
                           (pipeSlave.tReady = '1');
            metaAccepted := (pathMetaValid = '1') and
                            (pathMetaReady = '1') and
                            (mAxisSlave.tReady = '1');
            assert sofAccepted = metaAccepted
               report "RoCEv2TxPathPipeline: TX SOF and metadata did not transfer atomically"
               severity failure;

            stalled    := (pipeMaster.tValid = '1') and (pipeSlave.tReady = '0');
            heldMaster := pipeMaster;
            heldMeta   := pipeMeta;
         end if;
      end if;
   end process ASSERTIONS;
   -- pragma translate_on

end architecture rtl;
