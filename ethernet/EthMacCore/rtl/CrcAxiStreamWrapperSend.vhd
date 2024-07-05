library ieee;
use ieee.std_logic_1164.all;

entity CrcAxiStreamWrapperSend is
  port (
    CLK                : in  std_logic;
    RST                : in  std_logic;
    s_axis_tvalid      : in  std_logic;
    s_axis_tdata       : in  std_logic_vector(255 downto 0);
    s_axis_tkeep       : in  std_logic_vector(31 downto 0);
    s_axis_tlast       : in  std_logic;
    s_axis_tuser       : in  std_logic;
    s_axis_tready      : out std_logic;
    m_crc_stream_data  : out std_logic_vector(31 downto 0);
    m_crc_stream_valid : out std_logic;
    m_crc_stream_ready : in  std_logic
    );
end CrcAxiStreamWrapperSend;

architecture rtl of CrcAxiStreamWrapperSend is

  component mkCrcRawAxiStreamCustomSend is
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
  end component mkCrcRawAxiStreamCustomSend;

  signal s_rstn : std_logic;

begin  -- architecture rtl

  s_rstn <= not RST;

  CrcAxiStreamWrapperSend_1 : mkCrcRawAxiStreamCustomSend
    port map (
      CLK                => CLK,
      RST_N              => s_rstn,
      s_axis_tvalid      => s_axis_tvalid,
      s_axis_tdata       => s_axis_tdata,
      s_axis_tkeep       => s_axis_tkeep,
      s_axis_tlast       => s_axis_tlast,
      s_axis_tuser       => s_axis_tuser,
      s_axis_tready      => s_axis_tready,
      m_crc_stream_data  => m_crc_stream_data,
      m_crc_stream_valid => m_crc_stream_valid,
      m_crc_stream_ready => m_crc_stream_ready);

end architecture rtl;
