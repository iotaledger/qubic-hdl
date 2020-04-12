-- **********************-- --------------------------------------------------------------------------
-- Filename    : QUBIC_PROCESSOR.vhd
-- Description : Qubc Processor Core
-- Author      : Jonathan Shaffer
-- Details     : This module is the op level QLE config avalon bus
--               of the outgoing packet data
-- **********************-- --------------------------------------------------------------------------
-- Revision |   Author   |   Date    | Change Description |
--    Draft | J. Shaffer | 2/7/2020  | Prototyping Demo   |
-- **********************-- --------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity QUBIC_PROCESSOR is
   port (
      -- 200MHz clock for the QLUTs and Qubic processor core
      iQLUT_CLK         : in  std_logic;
      iQLUT_RSTn        : in  std_logic;
      
      --Control Inputs
      iQLUT_ST_ADDR     : in  std_logic_vector(8 downto 0); -- QLUT Start Address
      iQLUT_END_ADDR    : in  std_logic_vector(8 downto 0);
      iQPROC_RUN        : in  std_logic;
      
      --QLUT Control Outputs
      oQLUT_EN          : out std_logic;
      oQLUT_SEL_ADDR    : out unsigned(8 downto 0);
      
      --Status Registers
      oQPROC_IDLE       : out std_logic;
      oQPROC_DONE       : out std_logic
   );
end QUBIC_PROCESSOR;

architecture RTL of QUBIC_PROCESSOR is

type tSTATES is (cIDLE, cQLUT_ST, cDELAY1, cDELAY2, cUPDATE_ADDR, cDONE);
signal sPR_STATE  : tSTATES;
signal sNXT_STATE : tSTATES;

signal sQLUT_PCTR         : unsigned(8 downto 0);

signal sQLUT_ST_ADDR_Q      : std_logic_vector(8 downto 0);
signal sQLUT_ST_ADDR_QQ     : std_logic_vector(8 downto 0);
signal sQLUT_END_ADDR_Q     : std_logic_vector(8 downto 0);
signal sQLUT_END_ADDR_QQ    : std_logic_vector(8 downto 0);
signal sQPROC_RUN_Q         : std_logic;
signal sQPROC_RUN_QQ        : std_logic;

begin

RECLOCK_PROC : process(iQLUT_CLK, iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      sQPROC_RUN_Q      <= '0';
      sQPROC_RUN_QQ     <= '0';
      sQLUT_ST_ADDR_Q   <= (others => '0');
      sQLUT_ST_ADDR_QQ  <= (others => '0');
      sQLUT_END_ADDR_Q  <= (others => '0');
      sQLUT_END_ADDR_QQ <= (others => '0');
   elsif rising_edge(iQLUT_CLK) then 
      sQPROC_RUN_Q      <= iQPROC_RUN;
      sQPROC_RUN_QQ     <= sQPROC_RUN_Q;
      sQLUT_ST_ADDR_Q   <= iQLUT_ST_ADDR;
      sQLUT_ST_ADDR_QQ  <= sQLUT_ST_ADDR_Q;
      sQLUT_END_ADDR_Q  <= iQLUT_END_ADDR;
      sQLUT_END_ADDR_QQ <= sQLUT_END_ADDR_Q;
   end if;
end process RECLOCK_PROC;

STATE_CLOCK_PROC : process(iQLUT_CLK, iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      sPR_STATE <= cIDLE;
   elsif rising_edge(iQLUT_CLK) then 
      sPR_STATE <= sNXT_STATE;
   end if;
end process STATE_CLOCK_PROC;

STATE_CHANGE_PROC : process(sPR_STATE,sQLUT_END_ADDR_QQ,sQPROC_RUN_QQ,sQLUT_PCTR) begin

   case sPR_STATE is

      when cIDLE =>
         if (sQLUT_END_ADDR_QQ > "000000000" and sQPROC_RUN_QQ = '1') then
            sNXT_STATE <= cQLUT_ST;
         else
            sNXT_STATE <= cIDLE;
         end if;

      when cQLUT_ST =>
         sNXT_STATE <= cDELAY1;

      when cDELAY1 =>
         sNXT_STATE <= cDELAY2;

      when cDELAY2 =>
         if (sQLUT_PCTR = to_unsigned(511,9) or sQLUT_PCTR = unsigned(sQLUT_END_ADDR_QQ)) then
            sNXT_STATE <= cDONE;
         else
            sNXT_STATE <= cUPDATE_ADDR;
         end if;

      when cUPDATE_ADDR =>
         sNXT_STATE <= cDELAY1;

      when cDONE =>
         if sQPROC_RUN_QQ = '0' then
            sNXT_STATE <= cIDLE;
         else
            sNXT_STATE <= cDONE;
         end if;

      when others =>
         sNXT_STATE <= cIDLE;

   end case;
end process STATE_CHANGE_PROC;

STATE_LOGIC_PROC : process(iQLUT_CLK, iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      oQPROC_IDLE    <= '0';
      oQPROC_DONE    <= '0';
      oQLUT_EN       <= '0';
      sQLUT_PCTR     <= to_unsigned(0,9);
   elsif rising_edge(iQLUT_CLK) then

      case sNXT_STATE is

         when cIDLE =>
            oQPROC_IDLE <= '1';
            oQPROC_DONE <= '0';
            oQLUT_EN    <= '0';
            sQLUT_PCTR  <= to_unsigned(0,9);

         when cQLUT_ST =>
            oQPROC_IDLE <= '0';
            oQPROC_DONE <= '0';
            oQLUT_EN    <= '1';
            sQLUT_PCTR  <= unsigned(sQLUT_ST_ADDR_QQ);

         when cDELAY1 =>
            oQPROC_IDLE <= '0';
            oQPROC_DONE <= '0';
            oQLUT_EN    <= '1';
            sQLUT_PCTR  <= sQLUT_PCTR;

         when cDELAY2 =>
            oQPROC_IDLE <= '0';
            oQPROC_DONE <= '0';
            oQLUT_EN    <= '1';
            sQLUT_PCTR  <= sQLUT_PCTR;

         when cUPDATE_ADDR =>
            oQPROC_IDLE <= '0';
            oQPROC_DONE <= '0';
            oQLUT_EN    <= '1';
            sQLUT_PCTR  <= sQLUT_PCTR + 1;

         when cDONE =>
            oQPROC_IDLE <= '0';
            oQPROC_DONE <= '1';
            oQLUT_EN    <= '1';
            sQLUT_PCTR  <= sQLUT_PCTR;

         when others =>
            oQPROC_IDLE    <= '0';
            oQPROC_DONE    <= '0';
            oQLUT_EN       <= '0';
            sQLUT_PCTR     <= to_unsigned(0,9);

      end case;
   end if;
end process STATE_LOGIC_PROC;

oQLUT_SEL_ADDR <= sQLUT_PCTR;


end RTL;