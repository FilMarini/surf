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
use ieee.std_logic_misc.all;

library surf;
use surf.AxiStreamPkg.all;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

entity EthMacRxCheckICrc is
  generic (
    TPD_G         : time    := 1 ns;
    RST_ASYNC_G   : boolean := false;
    AXIS_CONFIG_G : AxiStreamConfigType
    );
  port (
    ethClk              : in  sl;
    ethRst              : in  sl;
    isRoCE              : in  sl;
    sAxisMaster         : in  AxiStreamMasterType;
    sAxisSlave          : out AxiStreamSlaveType;
    sAxisCrcCheckMaster : in  AxiStreamMasterType;
    sAxisCrcCheckSlave  : out AxiStreamSlaveType;
    mAxisMaster         : out AxiStreamMasterType;
    mAxisSlave          : in  AxiStreamSlaveType
    );
end entity EthMacRxCheckICrc;

architecture rtl of EthMacRxCheckICrc is

  type RegType is record
    obMaster   : AxiStreamMasterType;
    ibSlave    : AxiStreamSlaveType;
    ibCrcSlave : AxiStreamSlaveType;
    gotCrc     : boolean;
  end record RegType;

  constant REG_INIT_C : RegType := (
    obMaster   => axiStreamMasterInit(AXIS_CONFIG_G),
    ibSlave    => AXI_STREAM_SLAVE_INIT_C,
    ibCrcSlave => AXI_STREAM_SLAVE_INIT_C,
    gotCrc     => false
    );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- architecture rtl

  comb : process (sAxisMaster, sAxisCrcCheckMaster, mAxisSlave, r) is
    variable v      : RegType;
    variable ibM    : AxiStreamMasterType;
    variable ibCrcM : AxiStreamMasterType;
  begin  -- process comb
    v := r;

    -- Init ready
    v.ibSlave.tReady    := '0';
    v.ibCrcSlave.tReady := '0';

    -- Choose ready source and clear valid
    if (mAxisSlave.tReady = '1') then
      v.obMaster.tValid := '0';
    end if;

    if v.obMaster.tValid = '0' then
      -- Get inbound data
      ibM    := sAxisMaster;
      ibCrcM := sAxisCrcCheckMaster;

      if ibM.tValid = '1' and (ibCrcM.tValid = '1' or r.gotCrc) then
        -- Enable tReady on main
        v.ibSlave.tReady := '1';
        -- Enable tReady on CRC only for a single transaction
        if not r.gotCrc then
          v.ibCrcSlave.tReady := '1';
          v.gotCrc            := true;
        end if;
        if ibM.tLast = '1' then
          v.gotCrc := false;
        end if;
        v.obMaster := ibM;
        if or_reduce(ibCrcM.tData(31 downto 0)) = '0' then
          v.obMaster.tUser(2) := '0';
        else
          v.obMaster.tUser(2) := '1';
        end if;
      end if;
    end if;

    sAxisSlave         <= v.ibSlave;
    sAxisCrcCheckSlave <= v.ibCrcSlave;
    mAxisMaster        <= r.obMaster;

    rin <= v;

  end process comb;

  seq : process (ethClk, ethRst) is
  begin
    if (RST_ASYNC_G) and (ethRst = '1') then
      r <= REG_INIT_C after TPD_G;
    elsif (rising_edge(ethClk)) then
      if ((RST_ASYNC_G = false) and (ethRst = '1')) or (isRoCE = '0') then
        r <= REG_INIT_C after TPD_G;
      else
        r <= rin after TPD_G;
      end if;
    end if;
  end process seq;


end architecture rtl;
