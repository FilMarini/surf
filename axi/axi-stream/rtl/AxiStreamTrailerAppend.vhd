-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Append slv and the end and AXI-Stream package
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

entity AxiStreamTrailerAppend is

  generic (
    TPD_G               : time     := 1 ns;
    RST_ASYNC_G         : boolean  := false;
    PIPE_STAGES_G       : natural  := 0;
    TRAILER_DATA_BYTE_G : positive := 4;
    AXI_CONFIG_G        : AxiStreamConfigType);
  port (
    axisClk      : in  sl;
    axisRst      : in  sl;
    -- Slave port
    sAxisMaster  : in  AxiStreamMasterType;
    sAxisSlave   : out AxiStreamSlaveType;
    -- Trailer data
    trailerData  : in  slv(TRAILER_DATA_BYTE_G*8-1 downto 0);
    trailerValid : in  sl;
    -- Master port
    mAxisMaster  : out AxiStreamMasterType;
    mAxisSlave   : in  AxiStreamSlaveType);
end entity AxiStreamTrailerAppend;

architecture rtl of AxiStreamTrailerAppend is

  type RegType is record
    obMaster       : AxiStreamMasterType;
    ibSlave        : AxiStreamSlaveType;
    trailerLatched : slv(TRAILER_DATA_BYTE_G*8-1 downto 0);
    trailerBusy    : boolean;
  end record RegType;

  constant REG_INIT_C : RegType := (
    obMaster       => axiStreamMasterInit(AXI_CONFIG_G),
    ibSlave        => AXI_STREAM_SLAVE_INIT_C,
    trailerLatched => (others => '0'),
    trailerBusy    => false
    );
  constant BYTES_C : positive := AXI_CONFIG_G.TDATA_BYTES_C;

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal pipeAxisMaster : AxiStreamMasterType;
  signal pipeAxisSlave  : AxiStreamSlaveType;

begin  -- architecture rtl

  -- Make sure data widths are apropriate
  assert (BYTES_C >= TRAILER_DATA_BYTE_G)
    report "Trailer data widths must be less or equal than axi-stream" severity failure;

  comb : process (pipeAxisSlave, r, sAxisMaster, trailerData, trailerValid) is
    variable v   : RegType;
    variable ibM : AxiStreamMasterType;
  begin  -- process comb
    v             := r;
    v.trailerBusy := false;

    -- Init ready
    v.ibSlave.tReady := '0';

    -- Latch trailer
    if trailerValid = '1' then
      v.trailerLatched := trailerData;
    end if;

    -- Choose ready source and clear valid
    if (pipeAxisSlave.tReady = '1' or r.trailerBusy) then
      v.obMaster.tValid := '0';
    end if;

    if v.obMaster.tValid = '0' then
      -- Get inbound data
      ibM := sAxisMaster;
      if not r.trailerBusy then
        v.ibSlave.tReady := '1';
      end if;

      -- Mirror data until tLast
      if ibM.tValid = '1' then
        v.obMaster := ibM;
        if ibM.tLast = '1' then
          v.obMaster.tLast := '0';
          v.trailerBusy    := true;
        end if;
      end if;

      -- Send trailer frame
      if r.trailerBusy then
        v.obMaster                                         := AXI_STREAM_MASTER_INIT_C;
        v.obMaster.tKeep                                   := (others => '0');
        v.obMaster.tStrb                                   := (others => '0');
        v.obMaster.tData(TRAILER_DATA_BYTE_G*8-1 downto 0) := r.trailerLatched;
        v.obMaster.tKeep(TRAILER_DATA_BYTE_G-1 downto 0)   := (others => '1');
        v.obMaster.tLast                                   := '1';
        v.obMaster.tValid                                  := '1';
      end if;

    end if;

    sAxisSlave     <= v.ibSlave;
    pipeAxisMaster <= r.obMaster;

    rin <= v;

  end process comb;

  seq : process (axisClk, axisRst) is
  begin
    if (RST_ASYNC_G) and (axisRst = '1') then
      r <= REG_INIT_C after TPD_G;
    elsif (rising_edge(axisClk)) then
      if (RST_ASYNC_G = false) and (axisRst = '1') then
        r <= REG_INIT_C after TPD_G;
      else
        r <= rin after TPD_G;
      end if;
    end if;
  end process seq;

  -- Optional output pipeline registers to ease timing
  AxiStreamPipeline_1 : entity surf.AxiStreamPipeline
    generic map (
      TPD_G         => TPD_G,
      RST_ASYNC_G   => RST_ASYNC_G,
      -- SIDE_BAND_WIDTH_G => SIDE_BAND_WIDTH_G,
      PIPE_STAGES_G => PIPE_STAGES_G)
    port map (
      axisClk     => axisClk,
      axisRst     => axisRst,
      sAxisMaster => pipeAxisMaster,
      -- sSideBand   => pipeSideBand,
      sAxisSlave  => pipeAxisSlave,
      mAxisMaster => mAxisMaster,
      -- mSideBand   => mSideBand,
      mAxisSlave  => mAxisSlave);


end architecture rtl;
