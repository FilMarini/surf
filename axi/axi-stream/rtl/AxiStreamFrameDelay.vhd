-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Use to limit the max AXI stream frame rate
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

entity AxiStreamFrameDelay is
  generic (
    TPD_G          : time    := 1 ns;
    RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
    RST_ASYNC_G    : boolean := false;
    PIPE_STAGES_G  : natural := 0
    );
  port (
    axisClk     : in  sl;
    axisRst     : in  sl;
    sAxisMaster : in  AxiStreamMasterType;
    sAxisSlave  : out AxiStreamSlaveType;
    mAxisMaster : out AxiStreamMasterType;
    mAxisSlave  : in  AxiStreamSlaveType;
    delay       : in  slv(15 downto 0)
    );
end entity AxiStreamFrameDelay;

architecture rtl of AxiStreamFrameDelay is

  type StateType is (
    IDLE_S,
    DELAY_S);

  type RegType is record
    timer    : slv(15 downto 0);
    timerNow : slv(15 downto 0);
    ibSlave  : AxiStreamSlaveType;
    obMaster : AxiStreamMasterType;
    state    : StateType;
  end record RegType;

  constant REG_INIT_C : RegType := (
    timer    => (others => '0'),
    timerNow => (others => '0'),
    ibSlave  => AXI_STREAM_SLAVE_INIT_C,
    obMaster => AXI_STREAM_MASTER_INIT_C,
    state    => IDLE_S);

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal pipeAxisMaster : AxiStreamMasterType;
  signal pipeAxisSlave : AxiStreamSlaveType;

begin  -- architecture rtl

  comb : process (axisRst, delay, pipeAxisSlave, r, sAxisMaster) is
    variable v : RegType;
  begin  -- process comb
    -- Latch the current value
    v := r;

    -- Init ready
    v.ibSlave.tReady := '0';

    -- Reset the flags
    if pipeAxisSlave.tReady = '1' then
      v.obMaster.tValid := '0';
    end if;

    -- State Machine
    case r.state is
      -------------------------------------------------------------------------
      when IDLE_S =>
        -- Accept input data
        if v.obMaster.tValid = '0' and sAxisMaster.tValid = '1' then
          v.obMaster       := sAxisMaster;
          v.ibSlave.tReady := '1';
          v.timer          := delay;
          v.timerNow       := (others => '0');
        end if;
        if sAxisMaster.tLast = '1' then
          if r.timer = 0 then
            v.state := IDLE_S;
          else
            v.state := DELAY_S;
          end if;
        end if;
      -----------------------------------------------------------------------
      when DELAY_S =>
        v.ibSlave.tReady := '0';
        v.timerNow       := r.timerNow + 1;
        if r.timer - 1 = r.timerNow then
          v.state := IDLE_S;
        end if;
    -----------------------------------------------------------------------
    end case;

    -- Outputs
    sAxisSlave     <= v.ibSlave;
    pipeAxisMaster <= r.obMaster;

    -- Reset
    if (RST_ASYNC_G = false and axisRst = RST_POLARITY_G) then
      v := REG_INIT_C;
    end if;

    -- Register the variable for next clock cycle
    rin <= v;
  end process comb;

  seq : process (axisClk, axisRst) is
  begin
    if (RST_ASYNC_G) and (axisRst = RST_POLARITY_G) then
      r <= REG_INIT_C after TPD_G;
    elsif rising_edge(axisClk) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  -- Optional output pipeline registers to ease timing
  AxiStreamPipeline_1 : entity surf.AxiStreamPipeline
    generic map (
      TPD_G          => TPD_G,
      RST_POLARITY_G => RST_POLARITY_G,
      RST_ASYNC_G    => RST_ASYNC_G,
      PIPE_STAGES_G  => PIPE_STAGES_G)
    port map (
      axisClk     => axisClk,
      axisRst     => axisRst,
      sAxisMaster => pipeAxisMaster,
      sAxisSlave  => pipeAxisSlave,
      mAxisMaster => mAxisMaster,
      mAxisSlave  => mAxisSlave);

end architecture rtl;
