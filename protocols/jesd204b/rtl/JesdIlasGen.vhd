-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Initial lane alignment sequence Generator
--              Adds A na R characters at the LMFC borders.
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
use surf.Jesd204bpkg.all;

entity JesdIlasGen is
   generic (
      TPD_G : time                   := 1 ns;
      F_G   : positive               := 2;
      K_G   : positive               := 32;
      L_G   : positive range 1 to 32 := 2);
   port (
      clk : in sl;
      rst : in sl;

      -- Enable counter
      enable_i : in sl;

      -- Increase counter
      ilas_i : in sl;

      -- Increase counter
      lmfc_i : in sl;

      -- ILA config data
      did_i       : in slv(7 downto 0) := (others => '0');
      bid_i       : in slv(3 downto 0) := (others => '0');
      lid_i       : in slv(4 downto 0) := (others => '0');
      scrEnable_i : in sl              := '0';
      subClass_i  : in sl              := '0';

      -- Outs
      ilasData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      ilasK_o    : out slv(GT_WORD_SIZE_C-1 downto 0));
end entity JesdIlasGen;

architecture rtl of JesdIlasGen is

   type RegType is record
      lmfcD1          : sl;
      lmfcD2          : sl;
      lmfcounter      : slv(1 downto 0);
      clkcounter      : natural range 0 to 32;
      ilaConfigOctets : Slv8Array(13 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      lmfcD1          => '0',
      lmfcD2          => '0',
      lmfcounter      => (others => '0'),
      clkcounter      => 0,
      ilaConfigOctets => (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- ILA config paramenters constants or unused
   constant ILAC_JESDV_C  : slv(2 downto 0) := "001";
   constant ILAC_CF_C     : slv(4 downto 0) := (others => '0');
   constant ILAC_CS_C     : slv(1 downto 0) := (others => '0');
   constant ILAC_ADJCNT_C : slv(3 downto 0) := (others => '0');
   constant ILAC_ADJDIR_C : sl              := '0';
   constant ILAC_PHADJ_C  : sl              := '0';
   constant ILAC_HD_C     : sl              := '0';
   constant ILAC_M_C      : slv(7 downto 0) := conv_std_logic_vector(1-1, 8);
   constant ILAC_N_C      : slv(4 downto 0) := conv_std_logic_vector(16-1, 5);
   constant ILAC_S_C      : slv(4 downto 0) := conv_std_logic_vector(((F_G+1)/2)-1, 5);
   constant ILAC_F_C      : slv(7 downto 0) := conv_std_logic_vector(F_G-1, 8);
   constant ILAC_K_C      : slv(4 downto 0) := conv_std_logic_vector(K_G-1, 5);
   constant ILAC_L_C      : slv(4 downto 0) := conv_std_logic_vector(L_G-1, 5);

   constant PARTIAL_CHKSUM_C : slv(7 downto 0) := ILAC_JESDV_C + ILAC_HD_C + ILAC_M_C + ILAC_N_C + ILAC_N_C + ILAC_S_C + ILAC_F_C + ILAC_K_C + ILAC_L_C;

begin

   comb : process (enable_i, ilas_i, lmfc_i, r, rst, did_i, bid_i, lid_i, scrEnable_i, subClass_i) is
      variable v         : RegType;
      variable vIlasData : slv(ilasData_o'range);
      variable vIlasK    : slv(ilasK_o'range);
      variable vChecksum : slv(7 downto 0);
   begin
      v := r;

      -- Delay LMFC for 2 c-c
      v.lmfcD1 := lmfc_i;
      v.lmfcD2 := r.lmfcD1;

      -- Combinatorial logic
      vIlasData := (others => '0');
      vIlasK    := (others => '0');

      if enable_i = '1' and ilas_i = '1' then
         -- Send A character
         if r.lmfcD1 = '1' then
            vIlasData(vIlasData'high downto vIlasData'high-7) := A_CHAR_C;
            vIlasK(vIlasK'high)                               := '1';
            v.lmfcounter                                      := v.lmfcounter + 1;
         end if;
         -- Send R character
         if r.lmfcD2 = '1' then
            vIlasData (7 downto 0) := R_CHAR_C;
            vIlasK(0)              := '1';
            v.clkcounter           := 0;
            if r.lmfcounter = 1 then
               vIlasData (15 downto 8) := Q_CHAR_C;
               vIlasK(1)               := '1';
               v.clkcounter            := r.clkcounter + 1;
               if GT_WORD_SIZE_C = 4 then
                  vIlasData(23 downto 16) := r.ilaConfigOctets(0);
                  vIlasData(31 downto 24) := r.ilaConfigOctets(1);
               end if;
            end if;
         end if;
         -- Send ILA config
         if GT_WORD_SIZE_C = 4 and r.lmfcounter = 1 and (r.clkcounter > 0 and r.clkcounter < 4) then
            vIlasData(7 downto 0)   := r.ilaConfigOctets((r.clkcounter*4)-2);
            vIlasData(15 downto 8)  := r.ilaConfigOctets((r.clkcounter*4)-1);
            vIlasData(23 downto 16) := r.ilaConfigOctets((r.clkcounter*4));
            vIlasData(31 downto 24) := r.ilaConfigOctets((r.clkcounter*4)+1);
            v.clkcounter            := r.clkcounter + 1;
         end if;
         if GT_WORD_SIZE_C = 2 and r.lmfcounter = 1 and (r.clkcounter > 0 and r.clkcounter < 8) then
            vIlasData(7 downto 0)  := r.ilaConfigOctets(((r.clkcounter-1)*2));
            vIlasData(15 downto 8) := r.ilaConfigOctets(((r.clkcounter-1)*2)+1);
            v.clkcounter           := r.clkcounter + 1;
         end if;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Set ILA config data
      v.ilaConfigOctets(0)  := did_i;
      v.ilaConfigOctets(1)  := ILAC_ADJCNT_C & bid_i;
      v.ilaConfigOctets(2)  := '0' & ILAC_ADJDIR_C & ILAC_PHADJ_C & lid_i;
      v.ilaConfigOctets(3)  := scrEnable_i & "00" & ILAC_L_C;
      v.ilaConfigOctets(4)  := ILAC_F_C;
      v.ilaConfigOctets(5)  := "000" & ILAC_K_C;
      v.ilaConfigOctets(6)  := ILAC_M_C;
      v.ilaConfigOctets(7)  := ILAC_CS_C & '0' & ILAC_N_C;
      v.ilaConfigOctets(8)  := "00" & subClass_i & ILAC_N_C;
      v.ilaConfigOctets(9)  := ILAC_JESDV_C & ILAC_S_C;
      v.ilaConfigOctets(10) := ILAC_HD_C & "00" & ILAC_CF_C;
      v.ilaConfigOctets(11) := (others => '0');
      v.ilaConfigOctets(12) := (others => '0');

      -- Checksum
      vChecksum := did_i + bid_i + lid_i + PARTIAL_CHKSUM_C;
      v.ilaConfigOctets(13) := vChecksum;


      rin <= v;

      -- Output assignment
      ilasData_o <= vIlasData;
      ilasK_o    <= vIlasK;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
