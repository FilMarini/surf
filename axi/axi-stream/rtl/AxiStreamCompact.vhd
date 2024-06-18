-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to compact AXI-Streams if tKeep bits are not contiguous
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

entity AxiStreamCompact is

  generic (
    TPD_G               : time    := 1 ns;
    RST_ASYNC_G         : boolean := false;
    PIPE_STAGES_G       : natural := 0;
    SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
    MASTER_AXI_CONFIG_G : AxiStreamConfigType);
  port (
    axisClk     : in  sl;
    axisRst     : in  sl;
    -- Slave Port
    sAxisMaster : in  AxiStreamMasterType;
    sAxisSlave  : out AxiStreamSlaveType;
    -- Master Port
    mAxisMaster : out AxiStreamMasterType;
    mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamCompact;

architecture rtl of AxiStreamCompact is

  constant SLV_BYTES_C : positive := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
  constant MST_BYTES_C : positive := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

  type RegType is record
    count       : slv(bitSize(MST_BYTES_C)-1 downto 0);
    obMaster    : AxiStreamMasterType;
    obMasterBkp : AxiStreamMasterType;
    ibSlave     : AxiStreamSlaveType;
  end record RegType;

  constant REG_INIT_C : RegType := (
    count       => (others => '0'),
    obMaster    => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
    obMasterBkp => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
    ibSlave     => AXI_STREAM_SLAVE_INIT_C
    );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal pipeAxisMaster : AxiStreamMasterType;
  signal pipeAxisSlave  : AxiStreamSlaveType;

begin  -- architecture rtl

  -- Make sure data widths are the same
  -- assert (SLV_BYTES_C = MST_BYTES_C)
  --   report "Data widths must be equal between master and slave" severity failure;

  comb : process (pipeAxisSlave, r, sAxisMaster) is
    variable v       : RegType;
    variable ibM     : AxiStreamMasterType;
    variable byteCnt : integer;  -- Number of valid bytes in incoming bus
    variable bytePos : integer;         -- byte positioning on slave stream
  begin  -- process
    v       := r;
    bytePos := conv_integer(r.count);
    -- Count num. of bytes
    byteCnt := getTKeep(sAxisMaster.tKeep, SLAVE_AXI_CONFIG_G);

    -- Init ready
    v.ibSlave.tReady := '0';

    -- Choose ready source and clear valid
    if (pipeAxisSlave.tReady = '1' or r.count < MST_BYTES_C) then
      v.obMaster.tValid := '0';
    end if;

    if v.obMaster.tValid = '0' then
      -- Get Inbound data
      ibM              := sAxisMaster;
      v.ibSlave.tReady := '1';

      -- Get Backup stream
      v.obMaster := v.obMasterBkp;

      -- init when count = 0
      if (r.count = 0) then
        v.obMaster       := axiStreamMasterInit(MASTER_AXI_CONFIG_G);
        v.obMaster.tKeep := (others => '0');
      end if;

      if ibm.tValid = '1' then
        for i in 0 to MST_BYTES_C - 1 loop
          if ibM.tKeep(i) = '1' and bytePos <= MST_BYTES_C - 1 then
            v.obMaster.tData((bytePos*8)+7 downto (bytePos*8)) := ibM.tData((i*8)+7 downto (i*8));
            v.obMaster.tKeep(bytePos)                          := '1';
            v.obMaster.tUser                                   := ibM.tUser;
            v.obMaster.tStrb                                   := ibM.tStrb;
            bytePos                                            := bytePos + 1;
          elsif ibM.tKeep(i) = '1' and bytePos > MST_BYTES_C - 1 then
            v.obMasterBkp.tData(((bytePos - MST_BYTES_C)*8)+7 downto ((bytePos - MST_BYTES_C)*8)) := ibM.tData((i*8)+7 downto (i*8));
            v.obMasterBkp.tKeep(bytePos - MST_BYTES_C)                                            := '1';
            bytePos                                                                               := bytePos + 1;
          end if;
        end loop;  -- i

        v.obMaster.tId   := ibM.tId;
        v.obMaster.tDest := ibM.tDest;
        v.obMaster.tLast := ibM.tLast;

        -- Determine if we moved to backup
        if bytePos >= MST_BYTES_C - 1 then
          v.count           := conv_std_logic_vector(bytePos - MST_BYTES_C, v.count'length);
          v.obMaster.tValid := '1';
        else
          v.count       := conv_std_logic_vector(bytePos, v.count'length);
          v.obMasterBkp := v.obMaster;
        end if;
      end if;

    end if;

    sAxisSlave     <= v.ibSlave;
    pipeAxisMaster <= r.obMaster;

    rin <= v;

  end process;

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
