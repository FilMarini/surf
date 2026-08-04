-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 engine + DCQCN congestion-control composing wrapper.
--   Instantiates surf.RoceEngineWrapper (the RoCEv2 transport engine) and
--   surf.Dcqcn (DCQCN rate limiter). A 1->(1+MAX_QP_G) AXI-Lite crossbar fans the single
--   AXI-Lite slave to the engine's MetaData bank (slot 0, 0x0000) and one Dcqcn
--   register file per QP (QP i at slot i+1 / offset (i+1)*0x1000).  The engine
--   tags every TX frame with its local QP index in tDest.  A stream demux sends
--   each QP to an independent Dcqcn instance driven by cnpVec(i), then a
--   frame-locked mux recombines the paced streams.  The internal tDest tag is
--   cleared before the UDP-facing output.  DCQCN_EN_G gates the block end-to-end
--   (bypass = stream passthrough and all Dcqcn slots return DECERR).
--   Reuses the name of the pre-migration wrapper that bundled engine + DCQCN.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;
use surf.RocePkg.all;

entity RoCEv2AxiStreamRdma is
   generic (
      TPD_G            : time             := 1 ns;
      RST_POLARITY_G   : sl               := '1';
      RST_ASYNC_G      : boolean          := false;
      MAX_QP_G         : positive         := 4;
      MAX_QP_WR_G      : positive         := 4;
      EN_TX_G          : boolean          := true;
      EN_RX_G          : boolean          := true;
      EN_READ_G        : boolean          := true;
      DCQCN_EN_G       : boolean          := true;                    -- gate the per-QP DCQCN block
      DCQCN_BUCKET_SIZE_G : slv(31 downto 0) := x"00004000";          -- per-QP max burst credit (16 KiB)
      AXIL_BASE_ADDR_G : slv(31 downto 0) := (others => '0'));  -- absolute AXI-Lite base of this window
   port (
      clk                 : in  sl;
      rst                 : in  sl := not RST_POLARITY_G;
      -- RoCE wire streams (16-byte EMAC_AXIS_CONFIG_C beats)
      sAxisDataStreamMaster : in  AxiStreamMasterType;
      sAxisDataStreamSlave  : out AxiStreamSlaveType;
      mAxisDataStreamMaster : out AxiStreamMasterType;
      mAxisDataStreamSlave  : in  AxiStreamSlaveType;
      -- One packet-local path item is transferred with each accepted TX SOF.
      txPathMetaValid       : out sl := '0';
      txPathMetaData        : out slv(ROCE_TX_PATH_META_W_C-1 downto 0) := (others => '0');
      txPathMetaReady       : in  sl := '1';
      -- WorkReq / RecvReq
      sWorkReqMaster      : in  RoceWorkReqMasterType;
      sWorkReqSlave       : out RoceWorkReqSlaveType;
      sRecvReqMaster      : in  RoceRecvReqMasterType;
      sRecvReqSlave       : out RoceRecvReqSlaveType;
      -- Work completions
      mWorkCompRqMaster   : out RoceWorkCompMasterType;
      mWorkCompRqSlave    : in  RoceWorkCompSlaveType;
      mWorkCompSqMaster   : out RoceWorkCompMasterType;
      mWorkCompSqSlave    : in  RoceWorkCompSlaveType;
      -- DMA read client
      mDmaReadReqMaster   : out RoceDmaReadReqMasterType;
      mDmaReadReqSlave    : in  RoceDmaReadReqSlaveType;
      sDmaReadRespMaster  : in  RoceDmaReadRespMasterType;
      sDmaReadRespSlave   : out RoceDmaReadRespSlaveType;
      -- DMA write client
      mDmaWriteReqMaster  : out RoceDmaWriteReqMasterType;
      mDmaWriteReqSlave   : in  RoceDmaWriteReqSlaveType;
      sDmaWriteRespMaster : in  RoceDmaWriteRespMasterType;
      sDmaWriteRespSlave  : out RoceDmaWriteRespSlaveType;
      -- AXI-Lite (MetaData @0x0000, DCQCN QP i @(i+1)*0x1000)
      axilReadMaster      : in  AxiLiteReadMasterType;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType;
      axilWriteSlave      : out AxiLiteWriteSlaveType;
      -- metadata completion interrupt
      mdDoneIrq           : out sl;
      -- per-QP CNP pulses from the engine (observation and per-QP DCQCN input)
      cnp                 : out slv(MAX_QP_G-1 downto 0));
end entity RoCEv2AxiStreamRdma;

architecture rtl of RoCEv2AxiStreamRdma is

   constant NUM_AXIL_C : positive := 1 + MAX_QP_G;
   constant MD_C       : natural  := 0;   -- MetaData @ base + 0x0000
   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_C, AXIL_BASE_ADDR_G, 16, 12);

   signal axilWriteMastersX : AxiLiteWriteMasterArray(NUM_AXIL_C-1 downto 0);
   signal axilWriteSlavesX  : AxiLiteWriteSlaveArray(NUM_AXIL_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);
   signal axilReadMastersX  : AxiLiteReadMasterArray(NUM_AXIL_C-1 downto 0);
   signal axilReadSlavesX   : AxiLiteReadSlaveArray(NUM_AXIL_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);

   signal cnpVec         : slv(MAX_QP_G-1 downto 0);
   signal engineTxMaster : AxiStreamMasterType;   -- engine TX -> Dcqcn ingress
   signal engineTxSlave  : AxiStreamSlaveType;
   signal dcqcnInMasters  : AxiStreamMasterArray(MAX_QP_G-1 downto 0);
   signal dcqcnInSlaves   : AxiStreamSlaveArray(MAX_QP_G-1 downto 0);
   signal dcqcnOutMasters : AxiStreamMasterArray(MAX_QP_G-1 downto 0);
   signal dcqcnOutSlaves  : AxiStreamSlaveArray(MAX_QP_G-1 downto 0);
   signal dcqcnMuxMaster  : AxiStreamMasterType;
   signal dcqcnMuxSlave   : AxiStreamSlaveType;
   signal qpPathMeta      : slv(MAX_QP_G*ROCE_TX_PATH_META_W_C-1 downto 0);
   signal selectedTxMaster : AxiStreamMasterType;
   signal selectedTxSlave  : AxiStreamSlaveType;

begin

   cnp <= cnpVec;

   -- pragma translate_off
   -- Integration invariant: the engine emits a valid local QP tag and holds
   -- it for the complete accepted frame.  The demux routes every beat from
   -- tDest, so changing it mid-frame would split one packet across QPs.
   QP_TAG_ASSERT : process (clk) is
      variable inFrame : boolean := false;
      variable qpTag   : slv(7 downto 0) := (others => '0');
   begin
      if rising_edge(clk) then
         if rst = RST_POLARITY_G then
            inFrame := false;
            qpTag   := (others => '0');
         elsif (engineTxMaster.tValid = '1') and (engineTxSlave.tReady = '1') then
            assert to_integer(unsigned(engineTxMaster.tDest)) < MAX_QP_G
               report "RoCEv2AxiStreamRdma: out-of-range local QP tDest tag"
               severity failure;
            if inFrame then
               assert engineTxMaster.tDest = qpTag
                  report "RoCEv2AxiStreamRdma: local QP tDest changed mid-frame"
                  severity failure;
            else
               qpTag := engineTxMaster.tDest;
            end if;
            inFrame := engineTxMaster.tLast = '0';
         end if;
      end if;
   end process QP_TAG_ASSERT;
   -- pragma translate_on

   -- The wrapper reserves a 64-KiB AXI-Lite window split into 4-KiB slots:
   -- one metadata slot plus at most fifteen per-QP DCQCN slots.
   assert MAX_QP_G <= 15
      report "RoCEv2AxiStreamRdma: MAX_QP_G exceeds the 15 DCQCN slots in the " &
             "64-KiB AXI-Lite window"
      severity failure;

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => clk,
         axiClkRst           => rst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMastersX,
         mAxiWriteSlaves     => axilWriteSlavesX,
         mAxiReadMasters     => axilReadMastersX,
         mAxiReadSlaves      => axilReadSlavesX);

   U_Engine : entity surf.RoceEngineWrapper
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MAX_QP_G       => MAX_QP_G,
         MAX_QP_WR_G    => MAX_QP_WR_G,
         EN_TX_G        => EN_TX_G,
         EN_RX_G        => EN_RX_G,
         EN_READ_G      => EN_READ_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         sAxisDataStreamMaster => sAxisDataStreamMaster,
         sAxisDataStreamSlave  => sAxisDataStreamSlave,
         mAxisDataStreamMaster => engineTxMaster,       -- into Dcqcn
         mAxisDataStreamSlave  => engineTxSlave,
         sWorkReqMaster        => sWorkReqMaster,
         sWorkReqSlave         => sWorkReqSlave,
         sRecvReqMaster        => sRecvReqMaster,
         sRecvReqSlave         => sRecvReqSlave,
         mWorkCompRqMaster     => mWorkCompRqMaster,
         mWorkCompRqSlave      => mWorkCompRqSlave,
         mWorkCompSqMaster     => mWorkCompSqMaster,
         mWorkCompSqSlave      => mWorkCompSqSlave,
         mDmaReadReqMaster     => mDmaReadReqMaster,
         mDmaReadReqSlave      => mDmaReadReqSlave,
         sDmaReadRespMaster    => sDmaReadRespMaster,
         sDmaReadRespSlave     => sDmaReadRespSlave,
         mDmaWriteReqMaster    => mDmaWriteReqMaster,
         mDmaWriteReqSlave     => mDmaWriteReqSlave,
         sDmaWriteRespMaster   => sDmaWriteRespMaster,
         sDmaWriteRespSlave    => sDmaWriteRespSlave,
         axilReadMaster        => axilReadMastersX(MD_C),
         axilReadSlave         => axilReadSlavesX(MD_C),
         axilWriteMaster       => axilWriteMastersX(MD_C),
         axilWriteSlave        => axilWriteSlavesX(MD_C),
         mdDoneIrq             => mdDoneIrq,
         qpPathMeta            => qpPathMeta,
         cnp                   => cnpVec);

   GEN_DCQCN : if DCQCN_EN_G generate
      -- The local QP index is encoded in all eight tDest bits.  A malformed
      -- out-of-range tag is consumed/dropped by AxiStreamDeMux.
      U_DcqcnDemux : entity surf.AxiStreamDeMux
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            NUM_MASTERS_G  => MAX_QP_G,
            MODE_G         => "INDEXED",
            TDEST_HIGH_G   => 7,
            TDEST_LOW_G    => 0)
         port map (
            axisClk      => clk,
            axisRst      => rst,
            sAxisMaster  => engineTxMaster,
            sAxisSlave   => engineTxSlave,
            mAxisMasters => dcqcnInMasters,
            mAxisSlaves  => dcqcnInSlaves);

      GEN_DCQCN_QP : for i in 0 to MAX_QP_G-1 generate
         U_Dcqcn : entity surf.Dcqcn
            generic map (
               TPD_G          => TPD_G,
               AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
               BUCKET_SIZE_G  => DCQCN_BUCKET_SIZE_G,
               RST_ASYNC_G    => RST_ASYNC_G,
               RST_POLARITY_G => RST_POLARITY_G)
            port map (
               axisClk         => clk,
               axisRst         => rst,
               cnp             => cnpVec(i),
               axilReadMaster  => axilReadMastersX(i+1),
               axilReadSlave   => axilReadSlavesX(i+1),
               axilWriteMaster => axilWriteMastersX(i+1),
               axilWriteSlave  => axilWriteSlavesX(i+1),
               sAxisMaster     => dcqcnInMasters(i),
               sAxisSlave      => dcqcnInSlaves(i),
               mAxisMaster     => dcqcnOutMasters(i),
               mAxisSlave      => dcqcnOutSlaves(i));
      end generate GEN_DCQCN_QP;

      -- With interleaving disabled the mux keeps a selected QP until its
      -- accepted tLast beat, preserving packet boundaries.
      U_DcqcnMux : entity surf.AxiStreamMux
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            NUM_SLAVES_G   => MAX_QP_G,
            MODE_G         => "PASSTHROUGH",
            ILEAVE_EN_G    => false)
         port map (
            axisClk      => clk,
            axisRst      => rst,
            sAxisMasters => dcqcnOutMasters,
            sAxisSlaves  => dcqcnOutSlaves,
            mAxisMaster  => dcqcnMuxMaster,
            mAxisSlave   => dcqcnMuxSlave);

      dcqcnMuxSlave   <= selectedTxSlave;
      selectedTxMaster <= dcqcnMuxMaster;
   end generate GEN_DCQCN;

   BYPASS_DCQCN : if not DCQCN_EN_G generate
      engineTxSlave   <= selectedTxSlave;
      selectedTxMaster <= engineTxMaster;

      GEN_DISABLED_AXIL : for i in 1 to MAX_QP_G generate
         axilReadSlavesX(i)  <= AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
         axilWriteSlavesX(i) <= AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
      end generate GEN_DISABLED_AXIL;
   end generate BYPASS_DCQCN;

   -- Snapshot the post-arbitration winner and its path context before either
   -- UDP consumer can apply backpressure.
   U_TxPathPipeline : entity surf.RoCEv2TxPathPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MAX_QP_G       => MAX_QP_G)
      port map (
         clk           => clk,
         rst           => rst,
         sAxisMaster   => selectedTxMaster,
         sAxisSlave    => selectedTxSlave,
         qpPathMeta    => qpPathMeta,
         mAxisMaster   => mAxisDataStreamMaster,
         mAxisSlave    => mAxisDataStreamSlave,
         pathMetaValid => txPathMetaValid,
         pathMetaData  => txPathMetaData,
         pathMetaReady => txPathMetaReady);

end architecture rtl;
