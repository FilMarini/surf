-------------------------------------------------------------------------------
-- File       : SspDecoder12b14b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2017-04-26
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. This module
-- ties the framing core to an RTL 12b14b encoder.
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
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;
use work.Code12b14bPkg.all;

entity SspDecoder12b14b is

   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true);
   port (
      clk       : in  sl;
      rst       : in  sl := RST_POLARITY_G;
      dataIn    : in  slv(13 downto 0);
      dataOut   : out slv(11 downto 0);
      valid     : out sl;
      sof       : out sl;
      eof       : out sl;
      eofe      : out sl;
      codeError : out sl;
      dispError : out sl);

end entity SspDecoder12b14b;

architecture rtl of SspDecoder12b14b is

   signal framedData  : slv(11 downto 0);
   signal framedDataK : slv(0 downto 0);

begin

   Decoder12b14b_1 : entity work.Decoder12b14b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk       => clk,
         clkEn     => '1',
         rst       => rst,
         dataIn    => dataIn,
         dataOut   => framedData,
         dataKOut  => framedDataK(0),
         codeError => codeError,
         dispError => dispError);

   SspDeframer_1 : entity work.SspDeframer
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         WORD_SIZE_G     => 12,
         K_SIZE_G        => 1,
         SSP_IDLE_CODE_G => K_120_11_C,
         SSP_IDLE_K_G    => "1",
         SSP_SOF_CODE_G  => K_120_0_C,
         SSP_SOF_K_G     => "1",
         SSP_EOF_CODE_G  => K_120_1_C,
         SSP_EOF_K_G     => "1")
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => framedData,
         dataKIn => framedDataK,
         dataOut => dataOut,
         valid   => valid,
         sof     => sof,
         eof     => eof,
         eofe    => eofe);



end architecture rtl;
