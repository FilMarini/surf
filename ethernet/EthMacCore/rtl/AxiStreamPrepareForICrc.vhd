-------------------------------------------------------------------------------
-- Title      : AxiStreamPrepareForICrc
-- Project    : 
-------------------------------------------------------------------------------
-- File       : AxiStreamPrepareForICrc.vhd
-- Author     : Filippo Marini  <filippo.marini@pd.infn.it>
-- Company    : INFN Padova
-- Created    : 2024-06-20
-- Last update: 2024-06-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2024 INFN Padova
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2024-06-20  1.0      fmarini Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.AxiStreamPkg.all;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

entity AxiStreamPrepareForICrc is
  generic (
    -- Simulation Generics
    TPD_G         : time    := 1 ns;
    RST_ASYNC_G   : boolean := false;
    PIPE_STAGES_G : natural := 0);
  port (
    axisClk     : in  sl;
    axisRst     : in  sl;
    -- RoCE transmission?
    isRoCE      : in  sl;
    -- Slave ports
    sAxisMaster : in  AxiStreamMasterType;
    sAxisSlave  : out AxiStreamSlaveType;
    -- Master ports
    mAxisMaster : out AxiStreamMasterType;
    mAxisSlave  : in  AxiStreamSlaveType
    );
end entity AxiStreamPrepareForICrc;

architecture rtl of AxiStreamPrepareForICrc is

  type RegType is record
    count    : integer;
    obMaster : AxiStreamMasterType;
    ibSlave  : AxiStreamSlaveType;
  end record RegType;

  constant REG_INIT_C : RegType := (
    count    => 0,
    obMaster => AXI_STREAM_MASTER_INIT_C,
    ibSlave  => AXI_STREAM_SLAVE_INIT_C
    );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- architecture rtl

  comb : process (mAxisSlave, sAxisMaster, r) is
    variable v   : RegType;
    variable ibM : AxiStreamMasterType;
  begin  -- process comb
    v := r;

    -- Init ready
    v.ibSlave.tReady := '0';

    -- Choose ready source and clear valid
    if mAxisSlave.tReady = '1' then
      v.obMaster.tValid := '0';
    end if;

    if v.obMaster.tValid = '0' then
      ibM              := sAxisMaster;
      v.ibSlave.tReady := '1';
      if ibM.tValid = '1' then
        v.obMaster := ibM;
        case r.count is
          when 0 =>
            -- reset output data
            v.obMaster.tData(v.obMaster.tData'length-1 downto 80) := (others => '0');
            -- ignore MAC header
            v.obMaster.tData(63 downto 0)                         := (others => '1');
            -- Get Version and Header length
            v.obMaster.tData(71 downto 64)                        := sAxisMaster.tData(119 downto 112);
            -- ignore Type of Service
            v.obMaster.tData(79 downto 72)                        := (others => '1');
            -- adjust tKeep
            v.obMaster.tKeep(v.obMaster.tKeep'length-1 downto 10) := (others => '0');
            v.obMaster.tKeep(9 downto 0)                          := (others => '1');
          when 1 =>
            -- ignore TTL
            v.obMaster.tData(55 downto 48) := (others => '1');
            -- ignore ip checksum
            v.obMaster.tData(79 downto 64) := (others => '1');
          when 2 =>
            -- ignore prot checksum
            v.obMaster.tData(79 downto 64)   := (others => '1');
            -- ignore BTH fecn, becn and resv6
            v.obMaster.tData(119 downto 112) := (others => '1');
          when others =>
            null;
        end case;
        v.count := v.count + 1;
        if ibM.tLast = '1' then
          v.count := 0;
        end if;
      end if;
    end if;

    sAxisSlave  <= v.ibSlave;
    mAxisMaster <= r.obMaster;

    rin <= v;

  end process comb;

  seq : process (axisClk, axisRst) is
  begin
    if (RST_ASYNC_G) and (axisRst = '1') then
      r <= REG_INIT_C after TPD_G;
    elsif (rising_edge(axisClk)) then
      if ((RST_ASYNC_G = false) and (axisRst = '1')) or (isRoCE = '0') then
        r <= REG_INIT_C after TPD_G;
      else
        r <= rin after TPD_G;
      end if;
    end if;
  end process seq;

end architecture rtl;
