-------------------------------------------------------------------------------
-- Title      : RoceConfigurator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : RoceConfigurator.vhd
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2024-07-30
-- Last update: 2024-07-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2024 INFN Padova
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2024-07-30  1.0      fmarini Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity RoceConfigurator is
  generic (
    TPD_G       : time    := 1 ns;
    RST_ASYNC_G : boolean := false
    );
  port (
    RoceClk                     : in  std_logic;
    RoceRst                     : in  std_logic;
    -- RoCE Metadata Interface
    mAxisMetaDataReqMaster_o  : out AxiStreamMasterType;
    mAxisMetaDataReqSlave_i   : in  AxiStreamSlaveType;
    sAxisMetaDataRespMaster_i : in  AxiStreamMasterType;
    sAxisMetaDataRespSlave_o  : out AxiStreamSlaveType;
    -- AXI-Lite Interface
    axilReadMaster            : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
    axilReadSlave             : out AxiLiteReadSlaveType;
    axilWriteMaster           : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
    axilWriteSlave            : out AxiLiteWriteSlaveType
    );
end entity RoceConfigurator;

architecture rtl of RoceConfigurator is

  type AxilRegType is record
    metaData       : slv(302 downto 0);
    metaDataIsSet  : sl;
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record AxilRegType;

  constant AXIL_REG_INIT_C : AxilRegType := (
    metaData       => (others => '0'),
    metaDataIsSet  => '0',
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C
    );

  signal regR   : AxilRegType := AXIL_REG_INIT_C;
  signal regRin : AxilRegType;

  type ConfStateType is (
    st0_idle,
    st1_dump_config,
    st2_get_response
    );

  type ConfRegType is record
    state           : ConfStateType;
    metaData        : slv(275 downto 0);
    metaDataIsReady : sl;
    txMaster        : AxiStreamMasterType;
    rxSlave         : AxiStreamSlaveType;
  end record ConfRegType;

  constant CONF_REG_INIT_C : ConfRegType := (
    state           => st0_idle,
    metaData        => (others => '0'),
    metaDataIsReady => '0',
    txMaster        => AXI_STREAM_MASTER_INIT_C,
    rxSlave         => AXI_STREAM_SLAVE_INIT_C
    );

  signal confR   : ConfRegType := CONF_REG_INIT_C;
  signal confRin : ConfRegType;

  signal metaDataIsSet : sl;

begin

  regComb : process (axilReadMaster, axilWriteMaster, confR.metaData,
                     confR.metaDataIsReady, regR) is
    variable v      : AxilRegType;
    variable regCon : AxiLiteEndPointType;
  begin  -- process regComb
    -- Latch the current value
    v := regR;

    -- Determine the transaction type
    axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

    -- Gen registers
    axiSlaveRegister (regCon, x"F00", 0, v.metaDataIsSet);
    axiSlaveRegister (regCon, x"F04", 0, v.metaData);
    axiSlaveRegisterR (regCon, x"F00", 1, confR.metaDataIsReady);
    axiSlaveRegisterR (regCon, x"F2C", 0, confR.metaData);

    -- Closeout the transaction
    axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

    -- Outputs
    axilWriteSlave <= regR.axilWriteSlave;
    axilReadSlave  <= regR.axilReadSlave;

    -- Register update
    regRin <= v;

  end process regComb;

  regSeq : process (RoceClk, RoceRst) is
  begin
    if (RST_ASYNC_G) and (RoceRst = '1') then
      regR <= AXIL_REG_INIT_C after TPD_G;
    elsif (rising_edge(RoceClk)) then
      if (RST_ASYNC_G = false) and (RoceRst = '1') then
        regR <= AXIL_REG_INIT_C after TPD_G;
      else
        regR <= regRin after TPD_G;
      end if;
    end if;
  end process regSeq;

  -- Get rising_edge
  SynchronizerEdge_1 : entity surf.SynchronizerEdge
    generic map (
      TPD_G         => TPD_G,
      BYPASS_SYNC_G => true
      )
    port map (
      clk        => RoceClk,
      dataIn     => regR.metaDataIsSet,
      risingEdge => metaDataIsSet
      );

  confComb : process (confR, mAxisMetaDataReqSlave_i, metaDataIsSet,
                      regR.metaData,
                      sAxisMetaDataRespMaster_i.tData,
                      sAxisMetaDataRespMaster_i.tValid) is
    variable v      : ConfRegType;
  begin  -- process confComb
    -- Latch the current value
    v := confR;

    -- Init Ready
    v.rxSlave.tReady := '0';

    -- Choose ready source and clear valid
    if mAxisMetaDataReqSlave_i.tReady = '1' then
      v.txMaster.tValid := '0';
    end if;

    case confR.state is
      -------------------------------------------------------------------------
      when st0_idle =>
        if metaDataIsSet = '1' then
          v.state           := st1_dump_config;
          v.metaDataIsReady := '0';
        end if;
      -----------------------------------------------------------------------
      when st1_dump_config =>
        v.txMaster.tData(302 downto 0) := regR.metaData;
        v.txMaster.tValid              := '1';
        if v.txMaster.tValid = '0' then
          v.state := st2_get_response;
        end if;
      -----------------------------------------------------------------------
      when st2_get_response =>
        if sAxisMetaDataRespMaster_i.tValid = '1' then
          v.rxSlave.tReady  := '1';
          v.metaData        := sAxisMetaDataRespMaster_i.tData(275 downto 0);
          v.metaDataIsReady := '1';
          v.state           := st0_idle;
        end if;
      -----------------------------------------------------------------------
      when others =>
        v := CONF_REG_INIT_C;
    end case;

    sAxisMetaDataRespSlave_o <= v.rxSlave;
    mAxisMetaDataReqMaster_o <= confR.txMaster;

    confRin <= v;

  end process confComb;

  confSeq : process (RoceClk, RoceRst) is
  begin
    if (RST_ASYNC_G) and (RoceRst = '1') then
      confR <= CONF_REG_INIT_C after TPD_G;
    elsif (rising_edge(RoceClk)) then
      if (RST_ASYNC_G = false) and (RoceRst = '1') then
        confR <= CONF_REG_INIT_C after TPD_G;
      else
        confR <= confRin after TPD_G;
      end if;
    end if;
  end process confSeq;


end architecture rtl;
