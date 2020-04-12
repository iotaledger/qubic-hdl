-- **********************-- --------------------------------------------------------------------------
-- Filename    : QLUT_2B_3IN.vhd
--
-- Description : 3 Input QLUT, 2b processing
--             :
-- Author      : Jonathan Shaffer, Thomas Serbis, Don Kelly
--             :
-- Company     : The IOTA Foundation
-- **********************-- --------------------------------------------------------------------------
-- Revision |   Author   |   Date    | Change Description |
--    Draft | J. Shaffer | 2/7/2020  | Prototyping Demo   |
-- **********************-- --------------------------------------------------------------------------
library     ieee;
use         ieee.std_logic_1164.all;
use         ieee.numeric_std.all;

entity QLUT_2B_3IN is
   port (
      iQLUT_CLK     : in  std_logic;                           -- Input clock stared by all QLUT's
      iQLUT_RSTn    : in  std_logic;                           -- Active low global reset

      iMERGE_EN     : in  std_logic;                           -- Merge Enable bit, overrides state logic for a merge function
      iQLUT_DTABLE  : in  std_logic_vector(53 downto 0);       -- QLUT DATA Table   Bits 2 downto 0   is output for inputs -,-,-
                                                               --                   Bits 53 downto 51 is output for inputs +,+,+
      iQLUT_INA     : in  std_logic_vector(1 downto 0);        -- Input Trit A
      iQLUT_INB     : in  std_logic_vector(1 downto 0);        -- Input Trit B
      iQLUT_INC     : in  std_logic_vector(1 downto 0);        -- Input Trit C

      oQLUT_O       : out std_logic_vector(1 downto 0)         -- Output Trit
   );
end QLUT_2B_3IN;

architecture RTL of QLUT_2B_3IN is

type tSTATES is array (0 to 26) of std_logic_vector(1 downto 0);
signal sQLUT_STATES : tSTATES;

signal sCONC_IN      : std_logic_vector(5 downto 0);                -- Concatenated inpu trits all together for the LUT
signal sMERGE_DATA   : std_logic_vector(1 downto 0);
begin

sMERGE_DATA(1) <= (iQLUT_INA(1) or iQLUT_INB(1) or iQLUT_INC(1));
sMERGE_DATA(0) <= (iQLUT_INA(0) or iQLUT_INB(0) or iQLUT_INC(0));
sCONC_IN       <= iQLUT_INA & iQLUT_INB & iQLUT_INC;

GEN_DTABLE : for i in 0 to 26 generate
   sQLUT_STATES(i) <= iQLUT_DTABLE(i*2 + 1 downto i*2);
end generate;

QLUT_O_PROC : process(iQLUT_CLK, iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      oQLUT_O <= (others => '0');
   elsif rising_edge(iQLUT_CLK) then
      if iMERGE_EN = '1' then
         oQLUT_O <= sMERGE_DATA;
      else
         case sCONC_IN is
            when "101010" => oQLUT_O <= sQLUT_STATES(0);  -- Inputs A | B | C | Output
            when "101011" => oQLUT_O <= sQLUT_STATES(1);  --        - | - | - | iQLUT_DTABLE(1 downto 0)
            when "101001" => oQLUT_O <= sQLUT_STATES(2);  --        - | - | 0 | iQLUT_DTABLE(3 downto 2)
            when "101110" => oQLUT_O <= sQLUT_STATES(3);  --        - | - | + | iQLUT_DTABLE(5 downto 4)
            when "101111" => oQLUT_O <= sQLUT_STATES(4);  --        - | 0 | - | iQLUT_DTABLE(7 downto 6)
            when "101101" => oQLUT_O <= sQLUT_STATES(5);  --        - | 0 | 0 | iQLUT_DTABLE(9 downto 8)
            when "100110" => oQLUT_O <= sQLUT_STATES(6);  --        - | 0 | + | iQLUT_DTABLE(11 downto 10)
            when "100111" => oQLUT_O <= sQLUT_STATES(7);  --        - | + | - | iQLUT_DTABLE(13 downto 12)
            when "100101" => oQLUT_O <= sQLUT_STATES(8);  --        - | + | 0 | iQLUT_DTABLE(15 downto 14)
            when "111010" => oQLUT_O <= sQLUT_STATES(9);  --        - | + | + | iQLUT_DTABLE(17 downto 16)
            when "111011" => oQLUT_O <= sQLUT_STATES(10); --        0 | - | - | iQLUT_DTABLE(19 downto 18)
            when "111001" => oQLUT_O <= sQLUT_STATES(11); --        0 | - | 0 | iQLUT_DTABLE(21 downto 20)
            when "111110" => oQLUT_O <= sQLUT_STATES(12); --        0 | - | + | iQLUT_DTABLE(23 downto 22)
            when "111111" => oQLUT_O <= sQLUT_STATES(13); --        0 | 0 | - | iQLUT_DTABLE(25 downto 24)
            when "111101" => oQLUT_O <= sQLUT_STATES(14); --        0 | 0 | 0 | iQLUT_DTABLE(27 downto 26)
            when "110110" => oQLUT_O <= sQLUT_STATES(15); --        0 | 0 | + | iQLUT_DTABLE(29 downto 28)
            when "110111" => oQLUT_O <= sQLUT_STATES(16); --        0 | + | - | iQLUT_DTABLE(31 downto 30)
            when "110101" => oQLUT_O <= sQLUT_STATES(17); --        0 | + | 0 | iQLUT_DTABLE(33 downto 32)
            when "011010" => oQLUT_O <= sQLUT_STATES(18); --        0 | + | + | iQLUT_DTABLE(35 downto 34)
            when "011011" => oQLUT_O <= sQLUT_STATES(19); --        + | - | - | iQLUT_DTABLE(37 downto 36)
            when "011001" => oQLUT_O <= sQLUT_STATES(20); --        + | - | 0 | iQLUT_DTABLE(39 downto 38)
            when "011110" => oQLUT_O <= sQLUT_STATES(21); --        + | - | + | iQLUT_DTABLE(41 downto 40)
            when "011111" => oQLUT_O <= sQLUT_STATES(22); --        + | 0 | - | iQLUT_DTABLE(43 downto 42)
            when "011101" => oQLUT_O <= sQLUT_STATES(23); --        + | 0 | 0 | iQLUT_DTABLE(45 downto 44)
            when "010110" => oQLUT_O <= sQLUT_STATES(24); --        + | 0 | + | iQLUT_DTABLE(47 downto 46)
            when "010111" => oQLUT_O <= sQLUT_STATES(25); --        + | + | - | iQLUT_DTABLE(49 downto 48)
            when "010101" => oQLUT_O <= sQLUT_STATES(26); --        + | + | 0 | iQLUT_DTABLE(51 downto 50)
            when others   => oQLUT_O <= (others => '0');  --        + | + | + | iQLUT_DTABLE(53 downto 52)
         end case;
      end if;
   end if;
end process QLUT_O_PROC;

end RTL;
