library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity CrcAxiStreamWrapperRecv is
  port (
    axisClk     : in  std_logic;
    axisRst     : in  std_logic;
    sAxisMaster : in  AxiStreamMasterType;
    sAxisSlave  : out AxiStreamSlaveType;
    mAxisMaster : out AxiStreamMasterType;
    mAxisSlave  : in  AxiStreamSlaveType
    );
end CrcAxiStreamWrapperRecv;

architecture rtl of CrcAxiStreamWrapperRecv is

  component mkCrcRawAxiStreamCustomRecv is
    port (
      CLK                : in  std_logic;
      RST_N              : in  std_logic;
      s_axis_tvalid      : in  std_logic;
      s_axis_tdata       : in  std_logic_vector(255 downto 0);
      s_axis_tkeep       : in  std_logic_vector(31 downto 0);
      s_axis_tlast       : in  std_logic;
      s_axis_tuser       : in  std_logic;
      s_axis_tready      : out std_logic;
      m_crc_stream_data  : out std_logic_vector(31 downto 0);
      m_crc_stream_valid : out std_logic;
      m_crc_stream_ready : in  std_logic);
  end component mkCrcRawAxiStreamCustomRecv;

  -- BlueRdma
  signal blueRstN         : sl;
  signal bluetValidSlave  : sl;
  signal bluetDataSlave   : slv(255 downto 0);
  signal bluetKeepSlave   : slv(31 downto 0);
  signal bluetUserSlave   : sl;
  signal bluetLastSlave   : sl;
  signal bluetReadySlave  : sl;
  signal bluetDataMaster  : slv(31 downto 0);
  signal bluetValidMaster : sl;
  signal bluetReadyMaster : sl;

begin  -- architecture rtl

  blueRstN <= not axisRst;

  -----------------------------------------------------------------------------
  -- IP integrator
  -----------------------------------------------------------------------------
  MasterAxiStreamIpIntegrator_1 : entity surf.MasterAxiStreamIpIntegrator
    generic map (
      TUSER_WIDTH     => 1,
      TDATA_NUM_BYTES => 32)
    port map (
      M_AXIS_ACLK     => axisClk,
      M_AXIS_ARESETN  => blueRstN,
      M_AXIS_TVALID   => bluetValidSlave,
      M_AXIS_TDATA    => bluetDataSlave,
      M_AXIS_TKEEP    => bluetKeepSlave,
      M_AXIS_TLAST    => bluetLastSlave,
      M_AXIS_TUSER(0) => bluetUserSlave,
      M_AXIS_TREADY   => bluetReadySlave,
      axisClk         => open,
      axisRst         => open,
      axisMaster      => sAxisMaster,
      axisSlave       => sAxisSlave);

  SlaveAxiStreamIpIntegrator_1 : entity surf.SlaveAxiStreamIpIntegrator
    generic map (
      HAS_TLAST       => 1,
      HAS_TKEEP       => 1,
      TDATA_NUM_BYTES => 4)
    port map (
      S_AXIS_ACLK    => axisClk,
      S_AXIS_ARESETN => blueRstN,
      S_AXIS_TVALID  => bluetValidMaster,
      S_AXIS_TDATA   => bluetDataMaster,
      S_AXIS_TKEEP   => x"F",
      S_AXIS_TLAST   => '1',
      S_AXIS_TREADY  => bluetReadyMaster,
      axisClk        => open,
      axisRst        => open,
      axisMaster     => mAxisMaster,
      axisSlave      => mAxisSlave);

  -----------------------------------------------------------------------------
  -- CRC calculator
  -----------------------------------------------------------------------------
  mkCrcRawAxiStreamCustomRecv_1 : mkCrcRawAxiStreamCustomRecv
    port map (
      CLK                => axisClk,
      RST_N              => blueRstN,
      s_axis_tvalid      => bluetValidSlave,
      s_axis_tdata       => bluetDataSlave,
      s_axis_tkeep       => bluetKeepSlave,
      s_axis_tlast       => bluetLastSlave,
      s_axis_tuser       => bluetUserSlave,
      s_axis_tready      => bluetReadySlave,
      m_crc_stream_data  => bluetDataMaster,
      m_crc_stream_valid => bluetValidMaster,
      m_crc_stream_ready => bluetReadyMaster);


end architecture rtl;
