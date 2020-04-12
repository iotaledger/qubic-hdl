-- **********************-- --------------------------------------------------------------------------
-- Filename    : QLUT_AVALON.vhd
-- Description : Avalon interface for QLUT processor
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

entity QLUT_AVALON is
   port (
      -- 50MHz clock for the avalon bus
      iAV_CLK         : in  std_logic;
      iAV_RSTn        : in  std_logic;
      -- 200MHz clock for the QLUTs
      iQLUT_CLK       : in  std_logic;
      iQLUT_RSTn      : in  std_logic;
      
      --Avalon Slave AV0 for configuration data
      iAV0_ADDRESS    : in  std_logic_vector(9 downto 0);
      iAV0_CHIP_SEL   : in  std_logic;
      iAV0_BYTE_EN    : in  std_logic_vector(7 downto 0);
      iAV0_WRITE      : in  std_logic;
      iAV0_WRITEDATA  : in  std_logic_vector(63 downto 0);
      
      --Avalon Slave AV2 for input data writes and output data reads
      iAV2_ADDRESS    : in  std_logic_vector(8 downto 0);
      iAV2_CHIP_SEL   : in  std_logic;
      iAV2_WRITE      : in  std_logic;
      iAV2_WRITEDATA  : in  std_logic_vector(7 downto 0);
      iAV2_READ       : in  std_logic;
      oAV2_READDATA   : out std_logic_vector(7 downto 0);
      
      --Avalon Slave AV3 for Qubic Processor control
      iAV3_ADDRESS    : in  std_logic_vector(1 downto 0);
      iAV3_CHIP_SEL   : in  std_logic;
      iAV3_BYTE_EN    : in  std_logic_vector(1 downto 0);
      iAV3_WRITE      : in  std_logic;
      iAV3_WRITEDATA  : in  std_logic_vector(15 downto 0);
      iAV3_READ       : in  std_logic;
      oAV3_READDATA   : out std_logic_vector(15 downto 0);
      
      oQUBIC_IRQ      : out std_logic;

      oQPROC_IDLE     : out std_logic

        );
end QLUT_AVALON;

architecture RTL of QLUT_AVALON is

constant cQLUT_COUNT       : integer := 512;

type tDTABLE is array (0 to cQLUT_COUNT - 1) of std_logic_vector(54 downto 0);
signal sQLUT_DTABLE        : tDTABLE;

type tPNTR_TABLE is array (0 to cQLUT_COUNT - 1) of std_logic_vector(29 downto 0);
signal sQLUT_PNTR_TABLE    : tPNTR_TABLE; -- implement as ram once timing is finalized

type tQLUT_DATA is array (0 to cQLUT_COUNT - 1) of std_logic_vector(1 downto 0);
signal sSYS_IN_REG         : tQLUT_DATA;
signal sQLUT_INA           : tQLUT_DATA := (others => (others => '0'));
signal sQLUT_INB           : tQLUT_DATA := (others => (others => '0'));
signal sQLUT_INC           : tQLUT_DATA := (others => (others => '0'));
signal sQLUT_OUT           : tQLUT_DATA;

-- AV0 clock domain crossing registers
signal sAV0_WRITE_Q        : std_logic;
signal sAV0_WRITE_QQ       : std_logic;
signal sAV0_WRITE_ED       : std_logic;
signal sAV0_CHIP_SEL_Q     : std_logic;
signal sAV0_CHIP_SEL_QQ    : std_logic;
signal sAV0_CHIP_SEL_ED    : std_logic;
signal sAV0_BYTE_EN_Q      : std_logic_vector(6 downto 0);
signal sAV0_BYTE_EN_QQ     : std_logic_vector(6 downto 0);
signal sAV0_ADDRESS_Q      : std_logic_vector(9 downto 0);
signal sAV0_ADDRESS_QQ     : std_logic_vector(9 downto 0);
signal sAV0_WRITEDATA_Q    : std_logic_vector(54 downto 0);
signal sAV0_WRITEDATA_QQ   : std_logic_vector(54 downto 0);
-- AV0 logic signals
signal sQLUT_PNTR_WREN     : std_logic;
signal sQLUT_PNTR_DATA     : std_logic_vector(39 downto 0);
signal sQLUT_CFG_ADDR      : std_logic_vector(9 downto 0);
signal sQLUT_CFG_DATA      : std_logic_vector(54 downto 0);

-- AV2 clock domain crossing / pipelining registers
signal sAV2_WRITE_Q        : std_logic;
signal sAV2_WRITE_QQ       : std_logic;
signal sAV2_WRITE_ED       : std_logic;
signal sAV2_READ_Q         : std_logic;
signal sAV2_READ_QQ        : std_logic;
signal sAV2_CHIP_SEL_Q     : std_logic;
signal sAV2_CHIP_SEL_QQ    : std_logic;
signal sAV2_CHIP_SEL_ED    : std_logic;
signal sAV2_ADDRESS_Q      : std_logic_vector(8 downto 0);
signal sAV2_ADDRESS_QQ     : std_logic_vector(8 downto 0);
signal sAV2_WRITEDATA_Q    : std_logic_vector(1 downto 0);
signal sAV2_WRITEDATA_QQ   : std_logic_vector(1 downto 0);
signal sAV2_READDATA       : std_logic_vector(1 downto 0);
signal sAV2_READDATA_Q     : std_logic_vector(1 downto 0);
signal sAV2_READDATA_QQ    : std_logic_vector(1 downto 0);
-- AV2 Logic signals
signal sDATA_REG_ADDR      : std_logic_vector(8 downto 0);
signal sDATA_REG           : std_logic_vector(1 downto 0);

-- AV3 read logic signals
signal sAV3_WRITE_Q        : std_logic;
signal sAV3_CHIP_SEL_Q     : std_logic;
signal sQPROC_RUN          : std_logic;
signal sQPROC_INT_EN       : std_logic;
signal sQPROC_IDLE         : std_logic;
signal sQPROC_IDLE_Q1      : std_logic;
signal sQPROC_IDLE_Q2      : std_logic;
signal sQPROC_DONE         : std_logic;
signal sQPROC_DONE_Q1      : std_logic;
signal sQPROC_DONE_Q2      : std_logic;
signal sQPROC_DONE_Q3      : std_logic;
signal sQPROC_DONE_Q4      : std_logic;
signal sQLUT_ST_ADDR       : std_logic_vector(8 downto 0);
signal sQLUT_END_ADDR      : std_logic_vector(8 downto 0);
signal sQPROC_ADDR         : std_logic_vector(1 downto 0);
signal sQPROC_DATA_REG     : std_logic_vector(15 downto 0);

-- QLUT Control Logic signals
signal sPNTRA_SEL          : std_logic;
signal sPNTRA_SEL_Q        : std_logic;
signal sPNTRB_SEL          : std_logic;
signal sPNTRB_SEL_Q        : std_logic;
signal sPNTRC_SEL          : std_logic;
signal sPNTRC_SEL_Q        : std_logic;
signal sQLUT_SEL_ADDR      : unsigned(8 downto 0);
signal sQLUT_SEL_ADDR_Q    : unsigned(8 downto 0);
signal sQLUT_SEL_ADDR_Q2   : unsigned(8 downto 0);
signal sQLUT_OUT_A_REG     : std_logic_vector(1 downto 0);
signal sQLUT_OUT_B_REG     : std_logic_vector(1 downto 0);
signal sQLUT_OUT_C_REG     : std_logic_vector(1 downto 0);
signal sSYS_IN_A_REG       : std_logic_vector(1 downto 0);
signal sSYS_IN_B_REG       : std_logic_vector(1 downto 0);
signal sSYS_IN_C_REG       : std_logic_vector(1 downto 0);
signal sQLUT_INA_PNTR      : unsigned(8 downto 0);
signal sQLUT_INB_PNTR      : unsigned(8 downto 0);
signal sQLUT_INC_PNTR      : unsigned(8 downto 0);
signal sQLUT_EN            : std_logic;
signal sQLUT_EN_Q          : std_logic;
signal sQLUT_EN_Q2         : std_logic;

component QUBIC_PROCESSOR is
   port (
      iQLUT_CLK         : in  std_logic;
      iQLUT_RSTn        : in  std_logic;
      iQLUT_ST_ADDR     : in  std_logic_vector(8 downto 0); -- QLUT Start Address
      iQLUT_END_ADDR    : in  std_logic_vector(8 downto 0);
      iQPROC_RUN        : in  std_logic;
      oQLUT_EN          : out std_logic;
      oQLUT_SEL_ADDR    : out unsigned(8 downto 0);
      oQPROC_IDLE       : out std_logic;
      oQPROC_DONE       : out std_logic
        );
end component QUBIC_PROCESSOR;

component QLUT_2B_3IN is
   port (
      iQLUT_CLK         : in  std_logic;
      iQLUT_RSTn        : in  std_logic;
      iMERGE_EN         : in  std_logic;
      iQLUT_DTABLE      : in  std_logic_vector(53 downto 0);
      iQLUT_INA         : in  std_logic_vector(1 downto 0);
      iQLUT_INB         : in  std_logic_vector(1 downto 0);
      iQLUT_INC         : in  std_logic_vector(1 downto 0);
      oQLUT_O           : out std_logic_vector(1 downto 0)
   );
end component QLUT_2B_3IN;

begin

------------------------------------------------------------------------------------------------------------------------------------------
      -- AV0 Write Clock Domain Crossing Registers
------------------------------------------------------------------------------------------------------------------------------------------
AV0_CDC_PROC : process(iQLUT_CLK,iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      sAV0_WRITE_Q      <= '0';
      sAV0_WRITE_QQ     <= '0';
      sAV0_CHIP_SEL_Q   <= '0';
      sAV0_CHIP_SEL_QQ  <= '0';
      sAV0_BYTE_EN_Q    <= (others => '0');
      sAV0_BYTE_EN_QQ   <= (others => '0');
      sAV0_ADDRESS_Q    <= (others => '0');
      sAV0_ADDRESS_QQ   <= (others => '0');
      sAV0_WRITEDATA_Q  <= (others => '0');
      sAV0_WRITEDATA_QQ <= (others => '0');
   elsif rising_edge(iQLUT_CLK) then
      sAV0_WRITE_Q      <= iAV0_WRITE;
      sAV0_WRITE_QQ     <= sAV0_WRITE_Q;
      sAV0_CHIP_SEL_Q   <= iAV0_CHIP_SEL;
      sAV0_CHIP_SEL_QQ  <= sAV0_CHIP_SEL_Q;
      sAV0_BYTE_EN_Q    <= iAV0_BYTE_EN(6 downto 0);
      sAV0_BYTE_EN_QQ   <= sAV0_BYTE_EN_Q;
      sAV0_ADDRESS_Q    <= iAV0_ADDRESS;
      sAV0_ADDRESS_QQ   <= sAV0_ADDRESS_Q;
      sAV0_WRITEDATA_Q  <= iAV0_WRITEDATA(54 downto 0);
      sAV0_WRITEDATA_QQ <= sAV0_WRITEDATA_Q;
   end if;
end process AV0_CDC_PROC;

------------------------------------------------------------------------------------------------------------------------------------------
      -- AV0 Write Control Logic QLUT state configuration
------------------------------------------------------------------------------------------------------------------------------------------
AV0_WRITE_PROC : process(iQLUT_CLK, iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      sAV0_WRITE_ED     <= '0';
      sAV0_CHIP_SEL_ED  <= '0';
      sQLUT_CFG_ADDR    <= (others => '0');
      sQLUT_CFG_DATA    <= (others => '0');
      sQLUT_DTABLE      <= (others => (others => '0'));
      sQLUT_PNTR_TABLE  <= (others => (others => '0'));
   elsif rising_edge(iQLUT_CLK) then

      sAV0_WRITE_ED    <= sAV0_WRITE_QQ;
      sAV0_CHIP_SEL_ED <= sAV0_CHIP_SEL_QQ;

      -- On falling edge of iAV0_WRITE or iAV0_READ, latch data and address
      if sAV0_WRITE_QQ = '1' and sAV0_CHIP_SEL_QQ = '1' then
         sQLUT_CFG_ADDR <= sAV0_ADDRESS_QQ;
      end if;

      -- On rising edge of iAV0_WRITE only, latch write data
      if (sAV0_WRITE_QQ = '1' and sAV0_CHIP_SEL_QQ = '1') then
         if sAV0_BYTE_EN_QQ(0) = '1' then
            sQLUT_CFG_DATA(7 downto 0)   <= sAV0_WRITEDATA_QQ(7 downto 0);
         end if;
         if sAV0_BYTE_EN_QQ(1) = '1' then
            sQLUT_CFG_DATA(15 downto 8)  <= sAV0_WRITEDATA_QQ(15 downto 8);
         end if;
         if sAV0_BYTE_EN_QQ(2) = '1' then
            sQLUT_CFG_DATA(23 downto 16) <= sAV0_WRITEDATA_QQ(23 downto 16);
         end if;
         if sAV0_BYTE_EN_QQ(3) = '1' then
            sQLUT_CFG_DATA(31 downto 24) <= sAV0_WRITEDATA_QQ(31 downto 24);
         end if;
         if sAV0_BYTE_EN_QQ(4) = '1' then
            sQLUT_CFG_DATA(39 downto 32) <= sAV0_WRITEDATA_QQ(39 downto 32);
         end if;
         if sAV0_BYTE_EN_QQ(5) = '1' then
            sQLUT_CFG_DATA(47 downto 40) <= sAV0_WRITEDATA_QQ(47 downto 40);
         end if;
         if sAV0_BYTE_EN_QQ(6) = '1' then
            sQLUT_CFG_DATA(54 downto 48) <= sAV0_WRITEDATA_QQ(54 downto 48);
         end if;
      end if;

      if (sAV0_WRITE_ED  = '1' and sAV0_CHIP_SEL_ED = '1' and sQLUT_CFG_ADDR(9) = '0') then -- this conditional will change as scalle changes
         sQLUT_DTABLE(to_integer(unsigned(sQLUT_CFG_ADDR(8 downto 0)))) <= sQLUT_CFG_DATA(54 downto 0);
      end if;
      if (sAV0_WRITE_ED  = '1' and sAV0_CHIP_SEL_ED = '1' and sQLUT_CFG_ADDR(9) = '1') then
         sQLUT_PNTR_TABLE(to_integer(unsigned(sQLUT_CFG_ADDR(8 downto 0)))) <= sQLUT_CFG_DATA(29 downto 0);
      end if;
   end if;
end process AV0_WRITE_PROC;

------------------------------------------------------------------------------------------------------------------------------------------
      -- AV2 Write Clock Domain Crossing Registers
------------------------------------------------------------------------------------------------------------------------------------------
AV2_CDC_PROC : process(iQLUT_CLK,iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      sAV2_WRITE_Q      <= '0';
      sAV2_WRITE_QQ     <= '0';
      sAV2_READ_Q       <= '0';
      sAV2_READ_QQ      <= '0';
      sAV2_CHIP_SEL_Q   <= '0';
      sAV2_CHIP_SEL_QQ  <= '0';
      sAV2_ADDRESS_Q    <= (others => '0');
      sAV2_ADDRESS_QQ   <= (others => '0');
      sAV2_WRITEDATA_Q  <= (others => '0');
      sAV2_WRITEDATA_QQ <= (others => '0');
   elsif rising_edge(iQLUT_CLK) then
      sAV2_WRITE_Q      <= iAV2_WRITE;
      sAV2_WRITE_QQ     <= sAV2_WRITE_Q;
      sAV2_READ_Q       <= iAV2_READ;
      sAV2_READ_QQ      <= sAV2_READ_Q;
      sAV2_CHIP_SEL_Q   <= iAV2_CHIP_SEL;
      sAV2_CHIP_SEL_QQ  <= sAV2_CHIP_SEL_Q;
      sAV2_ADDRESS_Q    <= iAV2_ADDRESS;
      sAV2_ADDRESS_QQ   <= sAV2_ADDRESS_Q;
      sAV2_WRITEDATA_Q  <= iAV2_WRITEDATA(1 downto 0);
      sAV2_WRITEDATA_QQ <= sAV2_WRITEDATA_Q;
   end if;
end process AV2_CDC_PROC;

--------------------------------------------------------------------------------------------------------------------------------------------
--      -- AV2 Write Control Logic
--------------------------------------------------------------------------------------------------------------------------------------------
AV2_WRITE_PROC : process(iQLUT_CLK,iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      sAV2_WRITE_ED     <= '0';
      sAV2_CHIP_SEL_ED  <= '0';
      sAV2_READDATA     <= (others => '0');
      sAV2_READDATA_Q   <= (others => '0');
      sAV2_READDATA_QQ  <= (others => '0');
      sDATA_REG         <= (others => '0');
      sDATA_REG_ADDR    <= (others => '0');
      sSYS_IN_REG       <= (others => (others => '0'));
   elsif rising_edge(iQLUT_CLK) then

      sAV2_WRITE_ED    <= sAV2_WRITE_QQ;
      sAV2_CHIP_SEL_ED <= sAV2_CHIP_SEL_QQ;

      -- On falling edge of iAV0_WRITE or iAV0_READ, latch data and address
      if (sAV2_WRITE_QQ = '1' and sAV2_CHIP_SEL_QQ = '1') then
         sDATA_REG_ADDR <= sAV2_ADDRESS_QQ;
      end if;

      -- On rising edge of iAV0_WRITE only, latch write data
      if (sAV2_WRITE_QQ = '1' and sAV2_CHIP_SEL_QQ = '1') then
         sDATA_REG  <= sAV2_WRITEDATA_QQ;
      end if;

      if sAV2_WRITE_ED = '1' and sAV2_CHIP_SEL_ED = '1' then -- this conditional will change as scalle changes
         sSYS_IN_REG(to_integer(unsigned(sDATA_REG_ADDR))) <= sDATA_REG;
      end if;

      -- Read Logic and Pipelining
      if sAV2_READ_QQ = '1' and sAV2_CHIP_SEL_QQ = '1' then
         sAV2_READDATA  <= sQLUT_OUT(to_integer(unsigned(sAV2_ADDRESS_QQ)));
      end if;

      sAV2_READDATA_Q  <= sAV2_READDATA;
      sAV2_READDATA_QQ <= sAV2_READDATA_Q;

   end if;
end process AV2_WRITE_PROC;

------------------------------------------------------------------------------------------------------------------------------------------
      -- AV2 Read Control Logic
------------------------------------------------------------------------------------------------------------------------------------------
AV2_READ_PROC : process(iAV_CLK,iAV_RSTn) begin
   if iAV_RSTn = '0' then
      oAV2_READDATA(1 downto 0) <= (others => '0');
   elsif rising_edge(iAV_CLK) then
      oAV2_READDATA(1 downto 0) <= sAV2_READDATA_QQ;
   end if;
end process AV2_READ_PROC;

oAV2_READDATA(7 downto 2) <= (others => '0');

--------------------------------------------------------------------------------------------------------------------------------------------
--      -- AV3 Write Control Logic
--------------------------------------------------------------------------------------------------------------------------------------------
AV3_WRITE_PROC : process(iAV_CLK,iAV_RSTn) begin
   if iAV_RSTn = '0' then
      sAV3_WRITE_Q     <= '0';
      sAV3_CHIP_SEL_Q  <= '0';
      sQPROC_RUN       <= '0';
      sQPROC_INT_EN    <= '0';
      sQPROC_ADDR      <= (others => '0');
      sQPROC_DATA_REG  <= (others => '0');
      sQLUT_ST_ADDR    <= (others => '0');
      sQLUT_END_ADDR   <= (others => '0');
   elsif rising_edge(iAV_CLK) then

      -- Edge detection register to one shot to latch data and address
      sAV3_WRITE_Q    <= iAV3_WRITE;
      sAV3_CHIP_SEL_Q  <= iAV3_CHIP_SEL;

      -- On falling edge of iAV0_WRITE or iAV0_READ, latch data and address
      if (iAV3_WRITE = '1' and iAV3_CHIP_SEL = '1') then
         sQPROC_ADDR   <= iAV3_ADDRESS;
      end if;

      -- On rising edge of iAV0_WRITE only, latch write data
      if (iAV3_WRITE = '1' and iAV3_CHIP_SEL = '1' and sQPROC_IDLE_Q2 = '1') then
         if iAV3_BYTE_EN(0) = '1' then
            sQPROC_DATA_REG(7 downto 0)  <= iAV3_WRITEDATA(7 downto 0);
         end if;
         if iAV3_BYTE_EN(1) = '1' then
            sQPROC_DATA_REG(15 downto 8)  <= iAV3_WRITEDATA(15 downto 8);
         end if;
      end if;

      if (sAV3_WRITE_Q = '1' and sAV3_CHIP_SEL_Q = '1' and sQPROC_IDLE_Q2 = '1' and sQPROC_ADDR = "00" and iAV3_BYTE_EN(0) = '1') then
         sQPROC_INT_EN <= sQPROC_DATA_REG(4); -- interrupt enable
      end if;

      if sQPROC_DONE_Q2 = '1' then -- clear the process after QPROC_FINISHED is cleared
         sQPROC_RUN    <= '0';
      elsif (sAV3_WRITE_Q = '1' and sAV3_CHIP_SEL_Q = '1' and sQPROC_IDLE_Q2 = '1' and sQPROC_ADDR = "00" ) then
         sQPROC_RUN    <= sQPROC_DATA_REG(0);
      end if;

      if (sAV3_WRITE_Q = '1' and sAV3_CHIP_SEL_Q = '1' and sQPROC_IDLE_Q2 = '1' and sQPROC_ADDR = "01") then -- Qubic processor QLUT Start Address
         sQLUT_ST_ADDR(8 downto 0)   <= sQPROC_DATA_REG(8 downto 0);
      end if;

      if (sAV3_WRITE_Q = '1' and sAV3_CHIP_SEL_Q = '1' and sQPROC_IDLE_Q2 = '1' and sQPROC_ADDR = "10") then -- Qubic processor QLUT End Address
         sQLUT_END_ADDR(8 downto 0)  <= sQPROC_DATA_REG(8 downto 0);
      end if;

   end if;
end process AV3_WRITE_PROC;

oQPROC_IDLE <= sQPROC_IDLE_Q2;

------------------------------------------------------------------------------------------------------------------------------------------
      -- Interrupt Generation and CDC/Metastability Registering Process
------------------------------------------------------------------------------------------------------------------------------------------
QPROC_INT_GEN_PROC : process(iAV_CLK,iAV_RSTn) begin
   if iAV_RSTn = '0' then
      sQPROC_IDLE_Q1  <= '0';
      sQPROC_IDLE_Q2  <= '0';
      sQPROC_DONE_Q1  <= '0';
      sQPROC_DONE_Q2  <= '0';
      sQPROC_DONE_Q3  <= '0';
      sQPROC_DONE_Q4  <= '0';
   elsif rising_edge(iAV_CLK) then
      sQPROC_IDLE_Q1  <= sQPROC_IDLE;
      sQPROC_IDLE_Q2  <= sQPROC_IDLE_Q1;
      sQPROC_DONE_Q1  <= sQPROC_DONE;
      sQPROC_DONE_Q2  <= sQPROC_DONE_Q1;
      sQPROC_DONE_Q3  <= sQPROC_DONE_Q2;
      sQPROC_DONE_Q4  <= sQPROC_DONE_Q3;
   end if;
end process QPROC_INT_GEN_PROC;

oQUBIC_IRQ      <= (not sQPROC_DONE_Q3) and sQPROC_DONE_Q4 and sQPROC_INT_EN;

------------------------------------------------------------------------------------------------------------------------------------------
      -- AV3 Read Control Logic
------------------------------------------------------------------------------------------------------------------------------------------
AV3_READ_PROC : process(iAV_CLK,iAV_RSTn) begin
   if iAV_RSTn = '0' then
      oAV3_READDATA  <= (others => '0');
   elsif rising_edge(iAV_CLK) then

      if (iAV3_READ = '1' and iAV3_CHIP_SEL = '1' and sQPROC_IDLE_Q2 = '0') then -- Flag error if running
         oAV3_READDATA <= (others => '1');
      elsif (iAV3_READ = '1' and iAV3_CHIP_SEL = '1') then
         case iAV3_ADDRESS is 
            when "00" =>
               if iAV3_BYTE_EN(0) = '1' then
                  oAV3_READDATA(7 downto 0)   <= "000" & sQPROC_INT_EN & "000" & sQPROC_RUN;
               end if;
               if iAV3_BYTE_EN(1) = '1' then
                  oAV3_READDATA(8)  <= sQPROC_IDLE_Q2;
               end if;
            when "01" =>
               if iAV3_BYTE_EN(0) = '1' then
                  oAV3_READDATA(7 downto 0)   <= sQLUT_ST_ADDR(7 downto 0);
               end if;
               if iAV3_BYTE_EN(1) = '1' then
                  oAV3_READDATA(8)            <= sQLUT_ST_ADDR(8);
               end if;
            when "10" =>
               if iAV3_BYTE_EN(0) = '1' then
                  oAV3_READDATA(7 downto 0)   <= sQLUT_END_ADDR(7 downto 0);
               end if;
               if iAV3_BYTE_EN(1) = '1' then
                  oAV3_READDATA(8)            <= sQLUT_END_ADDR(8);
               end if;
            when others => null;
         end case;
         oAV3_READDATA(15 downto 9) <= (others => '0');
      end if;

   end if;
end process AV3_READ_PROC;

QUBIC_PROC_INST : QUBIC_PROCESSOR
   port map (
      iQLUT_CLK        => iQLUT_CLK,
      iQLUT_RSTn       => iQLUT_RSTn,
      iQLUT_ST_ADDR    => sQLUT_ST_ADDR,
      iQLUT_END_ADDR   => sQLUT_END_ADDR,
      iQPROC_RUN       => sQPROC_RUN,
      oQLUT_EN         => sQLUT_EN,
      oQLUT_SEL_ADDR   => sQLUT_SEL_ADDR,
      oQPROC_IDLE      => sQPROC_IDLE,
      oQPROC_DONE      => sQPROC_DONE
   );

QLUT_IN_PROC : process(iQLUT_CLK,iQLUT_RSTn) begin
   if iQLUT_RSTn = '0' then
      sPNTRA_SEL        <= '0';
      sPNTRA_SEL_Q      <= '0';
      sPNTRB_SEL        <= '0';
      sPNTRB_SEL_Q      <= '0';
      sPNTRC_SEL        <= '0';
      sPNTRC_SEL_Q      <= '0';
      sQLUT_EN_Q        <= '0';
      sQLUT_EN_Q2       <= '0';
      sQLUT_SEL_ADDR_Q  <= (others => '0');
      sQLUT_SEL_ADDR_Q2 <= (others => '0');
      sQLUT_INA_PNTR    <= (others => '0');
      sQLUT_INB_PNTR    <= (others => '0');
      sQLUT_INC_PNTR    <= (others => '0');
      sQLUT_OUT_A_REG   <= (others => '0');
      sQLUT_OUT_B_REG   <= (others => '0');
      sQLUT_OUT_C_REG   <= (others => '0');
      sSYS_IN_A_REG     <= (others => '0');
      sSYS_IN_B_REG     <= (others => '0');
      sSYS_IN_C_REG     <= (others => '0');
      sQLUT_INA         <= (others => (others => '0'));
      sQLUT_INB         <= (others => (others => '0'));
      sQLUT_INC         <= (others => (others => '0'));
   elsif rising_edge(iQLUT_CLK) then

      sQLUT_EN_Q        <= sQLUT_EN;
      sQLUT_EN_Q2       <= sQLUT_EN_Q;

      sQLUT_SEL_ADDR_Q  <= sQLUT_SEL_ADDR;
      sQLUT_SEL_ADDR_Q2 <= sQLUT_SEL_ADDR_Q;

      sPNTRA_SEL        <= sQLUT_PNTR_TABLE(to_integer(sQLUT_SEL_ADDR))(9);
      sPNTRA_SEL_Q      <= sPNTRA_SEL;
      sPNTRB_SEL        <= sQLUT_PNTR_TABLE(to_integer(sQLUT_SEL_ADDR))(19);
      sPNTRB_SEL_Q      <= sPNTRB_SEL;
      sPNTRC_SEL        <= sQLUT_PNTR_TABLE(to_integer(sQLUT_SEL_ADDR))(29);
      sPNTRC_SEL_Q      <= sPNTRC_SEL;

      sQLUT_INA_PNTR    <= unsigned(sQLUT_PNTR_TABLE(to_integer(sQLUT_SEL_ADDR))(8 downto 0));
      sQLUT_INB_PNTR    <= unsigned(sQLUT_PNTR_TABLE(to_integer(sQLUT_SEL_ADDR))(18 downto 10));
      sQLUT_INC_PNTR    <= unsigned(sQLUT_PNTR_TABLE(to_integer(sQLUT_SEL_ADDR))(28 downto 20));

      sQLUT_OUT_A_REG   <= sQLUT_OUT(to_integer(sQLUT_INA_PNTR));
      sQLUT_OUT_B_REG   <= sQLUT_OUT(to_integer(sQLUT_INB_PNTR));
      sQLUT_OUT_C_REG   <= sQLUT_OUT(to_integer(sQLUT_INC_PNTR));

      sSYS_IN_A_REG     <= sSYS_IN_REG(to_integer(sQLUT_INA_PNTR));
      sSYS_IN_B_REG     <= sSYS_IN_REG(to_integer(sQLUT_INB_PNTR));
      sSYS_IN_C_REG     <= sSYS_IN_REG(to_integer(sQLUT_INC_PNTR));

      if (sPNTRA_SEL_Q = '0' and sQLUT_EN_Q2 = '1') then
         sQLUT_INA(to_integer(sQLUT_SEL_ADDR_Q2)) <= sQLUT_OUT_A_REG;
      elsif sQLUT_EN_Q2 = '1' then
         sQLUT_INA(to_integer(sQLUT_SEL_ADDR_Q2)) <= sSYS_IN_A_REG;
      end if;

      if (sPNTRB_SEL_Q = '0' and sQLUT_EN_Q2 = '1') then
         sQLUT_INB(to_integer(sQLUT_SEL_ADDR_Q2)) <= sQLUT_OUT_B_REG;
      elsif sQLUT_EN_Q2 = '1' then
         sQLUT_INB(to_integer(sQLUT_SEL_ADDR_Q2)) <= sSYS_IN_B_REG;
      end if;

      if (sPNTRC_SEL_Q = '0' and sQLUT_EN_Q2 = '1') then
         sQLUT_INC(to_integer(sQLUT_SEL_ADDR_Q2)) <= sQLUT_OUT_C_REG;
      elsif sQLUT_EN_Q2 = '1' then
         sQLUT_INC(to_integer(sQLUT_SEL_ADDR_Q2)) <= sSYS_IN_C_REG;
      end if;

   end if;
end process QLUT_IN_PROC;

GEN_QLUT : for i in 0 to cQLUT_COUNT - 1 generate
   QLE_INST : QLUT_2B_3IN
      port map (
         iQLUT_CLK    => iQLUT_CLK,
         iQLUT_RSTn   => iQLUT_RSTn,
         iMERGE_EN    => sQLUT_DTABLE(i)(54),
         iQLUT_DTABLE => sQLUT_DTABLE(i)(53 downto 0),
         iQLUT_INA    => sQLUT_INA(i),
         iQLUT_INB    => sQLUT_INB(i),
         iQLUT_INC    => sQLUT_INC(i),
         oQLUT_O      => sQLUT_OUT(i)
      );
end generate;

end architecture RTL;