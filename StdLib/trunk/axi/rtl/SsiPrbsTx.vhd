-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiPrbsTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2014-07-18
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module generates 
--                PseudoRandom Binary Sequence (PRBS) on Virtual Channel Lane.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiPrbsTx is
   generic (
      -- General Configurations
      TPD_G                      : time                       := 1 ns;
      -- FIFO configurations
      BRAM_EN_G                  : boolean                    := true;
      XIL_DEVICE_G               : string                     := "7SERIES";
      USE_BUILT_IN_G             : boolean                    := false;
      GEN_SYNC_FIFO_G            : boolean                    := false;
      ALTERA_SYN_G               : boolean                    := true;
      ALTERA_RAM_G               : string                     := "M9K";
      CASCADE_SIZE_G             : natural range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G          : natural range 4 to 48      := 9;
      FIFO_PAUSE_THRESH_G        : natural range 1 to (2**24) := 2**8;
      -- PRBS Config
      PRBS_SEED_SIZE_G           : natural range 32 to 128    := 32;
      PRBS_TAPS_G                : NaturalArray               := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
      -- AXI Stream IO Config
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType        := ssiAxiStreamConfig(16, TKEEP_COMP_C);
      MASTER_AXI_PIPE_STAGES_G   : natural range 0 to 16      := 0);      
   port (
      -- Master Port (mAxisClk)
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisSlave  : in  AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;

      -- Trigger Signal (locClk domain)
      locClk       : in  sl;
      locRst       : in  sl              := '0';
      trig         : in  sl              := '1';
      packetLength : in  slv(31 downto 0) := X"FFFFFFFF";
      busy         : out sl;
      tDest        : in  slv(7 downto 0) := X"00";
      tId          : in  slv(7 downto 0) := X"00");


end SsiPrbsTx;

architecture rtl of SsiPrbsTx is

   constant PRBS_BYTES_C      : natural             := PRBS_SEED_SIZE_G / 8;
   constant PRBS_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(PRBS_BYTES_C, TKEEP_NORMAL_C);
   
   type StateType is (
      IDLE_S,
      SEED_RAND_S,
      LENGTH_S,
      DATA_S,
      LAST_S);  

   type RegType is record
      busy         : sl;
      packetLength : slv(31 downto 0);
      dataCnt      : slv(31 downto 0);
      eventCnt     : slv(PRBS_SEED_SIZE_G-1 downto 0);
      randomData   : slv(PRBS_SEED_SIZE_G-1 downto 0);
      txAxisMaster : AxiStreamMasterType;
      state        : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txAxisMaster : AxiStreamMasterType;
   signal txAxisSlave  : AxiStreamSlaveType;
   
begin

   assert (PRBS_SEED_SIZE_G mod 8 = 0) report "PRBS_SEED_SIZE_G must be a multiple of 8" severity failure;

   comb : process (locRst, packetLength, r, tDest, tId, trig, txAxisSlave) is
      variable i : integer;
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>

            v.txAxisMaster.tValid := '0';

            -- Reset the busy flag
            v.busy := '0';
            -- Check for a trigger
            if trig = '1' then
               -- Latch the generator seed
               v.randomData         := r.eventCnt;
               -- Set the busy flag
               v.busy               := '1';
               -- Latch the configuration
               v.txAxisMaster.tDest := tDest;
               v.txAxisMaster.tId   := tId;
               -- Check the packet length request value
               if packetLength = 0 then
                  -- Force minimum packet length of 2 (+1)
                  v.packetLength := toSlv(2, 32);
               elsif packetLength = 1 then
                  -- Force minimum packet length of 2 (+1)
                  v.packetLength := toSlv(2, 32);
               else
                  -- Latch the packet length
                  v.packetLength := packetLength;
               end if;
               -- Next State
               v.state := SEED_RAND_S;
            end if;
         ----------------------------------------------------------------------
         when SEED_RAND_S =>
            -- Check the status
            --if txAxisSlave.tReady = '1' then
               -- Send the random seed word
               v.txAxisMaster.tvalid                             := '1';
               v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := r.eventCnt;
               -- Generate the next random data word
               v.randomData                                      := lfsrShift(r.randomData, PRBS_TAPS_G);
               -- Increment the counter
               v.eventCnt                                        := r.eventCnt + 1;
               -- Increment the counter
               v.dataCnt                                         := r.dataCnt + 1;

               axiStreamSetUserBit(PRBS_SSI_CONFIG_C,v.txAxisMaster,SSI_SOF_C,'1',0);

               -- Next State
               v.state                                           := LENGTH_S;
            --end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check the status
            if txAxisSlave.tReady = '1' then

               axiStreamSetUserBit(PRBS_SSI_CONFIG_C,v.txAxisMaster,SSI_SOF_C,'0',0);

               -- Send the upper packetLength value
               v.txAxisMaster.tvalid             := '1';
               v.txAxisMaster.tData(31 downto 0) := r.packetLength;
               -- Increment the counter
               v.dataCnt                         := r.dataCnt + 1;
               -- Next State
               v.state                           := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check the status
            if txAxisSlave.tReady = '1' then
               -- Send the random data word
               v.txAxisMaster.tValid                             := '1';
               v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := r.randomData;

               -- Generate the next random data word
               v.randomData := lfsrShift(r.randomData, PRBS_TAPS_G);
               -- Increment the counter
               v.dataCnt    := r.dataCnt + 1;
               -- Check the counter
               if r.dataCnt = r.packetLength then
                  -- Reset the counter
                  v.dataCnt            := (others => '0');
                  -- Set the end of frame flag                 
                  v.txAxisMaster.tLast := '1';
                  -- Reset the busy flag
                  v.busy               := '0';
                  -- Next State
                  v.state              := LAST_S;
               end if;
            end if;

         ----------------------------------------------------------------------
         when LAST_S =>
            if txAxisSlave.tReady = '1' then
               v.txAxisMaster.tValid := '0';
               v.txAxisMaster.tLast  := '0';
               v.state               := IDLE_S;
            end if;

      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (locRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      txAxisMaster <= r.txAxisMaster;
      busy         <= r.busy;
      
   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   AxiStreamFifo_Inst : entity work.AxiStreamFifo
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => MASTER_AXI_PIPE_STAGES_G,
         -- FIFO configurations
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PRBS_SSI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => locClk,
         sAxisRst    => locRst,
         sAxisMaster => txAxisMaster,
         sAxisSlave  => txAxisSlave,
         sAxisCtrl   => open,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);  

end rtl;
