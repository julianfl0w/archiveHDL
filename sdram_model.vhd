----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:11:26 09/20/2013 
-- Design Name: 
-- Module Name:    sdram_model - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
-- Originally by Mike Field
-- Updated by Julian Loiacono, Aug 2017
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library work;
use work.memory_word_type.all;

entity sdram_model is
    generic (
      BANKCOUNT           : natural;
      sdram_rowcount      : natural;
      sdram_rows_to_sim   : natural;
      sdram_colcount      : natural;
      dataWidth           : natural);
    Port ( CLK     : in  STD_LOGIC;
           CKE     : in  STD_LOGIC;
           CS_N    : in  STD_LOGIC;
           RAS_N   : in  STD_LOGIC;
           CAS_N   : in  STD_LOGIC;
           WE_N    : in  STD_LOGIC;
           BA      : in  STD_LOGIC_VECTOR (log2(BANKCOUNT)-1 downto 0);
           DQS_P   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
           DQS_N   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
           DQM     : in  STD_LOGIC_VECTOR (1 downto 0);
           ADDR    : in  STD_LOGIC_VECTOR (sdram_rowcount-1 downto 0);
           DQ      : inout  STD_LOGIC_VECTOR (dataWidth-1 downto 0));
end sdram_model;

architecture Behavioral of sdram_model is
   type decode is (unsel_c, lmr_c, ref_c, pre_c, act_c, wr_c, rd_c, term_c, nop_c);
   signal command : decode;
   
   signal selected_bank : integer := 0;
   signal column        : unsigned(sdram_colcount-1 downto 0) := (others=>'0');
   signal column_i      : integer := 0;

   type   memory_array is array ((2**sdram_rows_to_sim)-1 downto 0, BANKCOUNT-1 downto 0, (2**sdram_colcount)-1 downto 0) of std_logic_vector( dataWidth-1 downto 0);
   type   row_array    is array (BANKCOUNT-1 downto 0) of integer;
   
   signal memory        : memory_array  := (others=>(others=>(others=>(others=>'0'))));
   signal thisRead      : std_logic_vector( dataWidth-1 downto 0);
   signal active_row    : row_array :=(others=>0);
   signal is_row_active : std_logic_vector(BANKCOUNT-1 downto 0)      := (others=>'0');
   signal mode_reg      : std_logic_vector(sdram_rowcount-1 downto 0) := (others=>'0');
   -- Some devices contain extended mode registers
   signal EMR1_reg      : std_logic_vector(sdram_rowcount-1 downto 0) := (others=>'0');
   signal EMR2_reg      : std_logic_vector(sdram_rowcount-1 downto 0) := (others=>'0');
   signal EMR3_reg      : std_logic_vector(sdram_rowcount-1 downto 0) := (others=>'0');
   
   type data_delaytype is array (12 downto 0) of std_logic_vector(dataWidth-1 downto 0);
   signal data_delay_fromRAM    : data_delaytype := (others=>(others=>'0'));      
   
   constant BURST_MAX   : integer := 9;
   signal wr_mask       : std_logic_vector(dataWidth/8 - 1 downto 0) := (others=>'0');
   signal rd_data       : std_logic_vector(dataWidth-1 downto 0) := (others=>'0');
   signal wr_burst      : std_logic_vector(10 + BURST_MAX-1 downto 0) := (others=>'0');
   signal writing       : std_logic := '0';
   signal rd_burst      : std_logic_vector(BURST_MAX  downto 0) := (others=>'0');
   signal reading       : std_logic := '0';
   signal currBank      : integer := 0;
   
   signal CL : integer := 3;
   signal AL : integer := 2;
   signal BL : integer := 0;
   constant tDQSQmax : time := 200pS;
   
begin
    BL <= 1 when mode_reg(2 downto 0) = "000" else to_integer(unsigned(mode_reg(2 downto 0) & '0'));
    currBank <= to_integer(unsigned(ba(log2(BANKCOUNT)-1 downto 0)));
    writing <= wr_burst(0);
    reading <= rd_burst(0);
    rd_data <= memory(active_row(selected_bank), selected_bank, column_i);
    CL <= to_integer(unsigned(mode_reg(6 downto 4)));
    AL <= to_integer(unsigned(EMR1_reg(5 downto 3)));
    column_i <= to_integer(column);
decode_proc: process(CS_N, RAS_N, CAS_N, WE_N)
   variable cmd : std_logic_vector(2 downto 0);
   begin
      if CS_N = '1' then
         command <= unsel_c;
      else
         cmd := RAS_N & CAS_N & WE_N;
         case cmd is 
            when "000"  => command <= LMR_c;
            when "001"  => command <= REF_c;
            when "010"  => command <= PRE_c;
            when "011"  => command <= ACT_c;
            when "100"  => command <= WR_c;
            when "101"  => command <= RD_c;
            when "110"  => command <= TERM_c;
            when others => command <= NOP_c;         
         end case;
      end if;
   end process;
 
data_process : process(clk)
   begin
      if rising_edge(clk) or falling_edge(clk) then
         dq<= data_delay_fromRAM(1) after tDQSQmax;
             
         -- this implements the data masks, gets updated when a read command is sent
         rd_burst(BURST_MAX-1 downto 0) <= rd_burst(BURST_MAX downto 1);
         
         wr_burst(wr_burst'high-1 downto 0) <= wr_burst(wr_burst'high downto 1);

         -- Process any pending writes
         if writing = '1' then
            column <= column+1;
            if wr_mask(0) = '1' then
                memory(active_row(selected_bank), selected_bank, column_i)(7 downto 0) <= DQ(7 downto 0);
            end if;
            if wr_mask(1) = '1' then
                memory(active_row(selected_bank), selected_bank, column_i)(15 downto 8) <= DQ(15 downto 8);
            end if;
         end if;            
         
        -- the following operates at half-speed, and on the falling edge
         if clk = '0' then
             -- default is not to write
             wr_mask <= "00";
             if command = wr_c then
                rd_burst <= (others => '0');
                column        <= unsigned(addr(sdram_colcount-1 downto 0));
                selected_bank <= currBank;
                if mode_reg(9) = '1' then 
                   wr_burst((AL + CL)*2 + BURST_MAX -2 downto (AL + CL)*2-1) <= "000000001";
                else
                   case mode_reg(2 downto 0) is
                      when "000" => wr_burst((AL + CL)*2 + BURST_MAX -4 downto (AL + CL)*2 - 3) <= "000000001";
                      when "001" => wr_burst((AL + CL)*2 + BURST_MAX -4 downto (AL + CL)*2 - 3) <= "000000011";
                      when "010" => wr_burst((AL + CL)*2 + BURST_MAX -4 downto (AL + CL)*2 - 3) <= "000001111";
                      when "011" => wr_burst((AL + CL)*2 + BURST_MAX -4 downto (AL + CL)*2 - 3) <= "011111111";
                      when "111" => wr_burst((AL + CL)*2 + BURST_MAX -4 downto (AL + CL)*2 - 3) <= "111111111";  -- full page
                      when others =>
                   end case;
                end if;
             elsif command = lmr_c then
                case BA is 
                when "00"   => mode_reg <= addr;
                when "01"   => EMR1_reg <= addr;
                when "10"   => EMR2_reg <= addr;
                when others => EMR3_reg <= addr;
                end case;
             elsif command = act_c then
                -- Open a row in a bank (of rows_to_simulate)
                active_row(currBank)    <= to_integer(unsigned(addr(sdram_rows_to_sim-1 downto 0)));
                is_row_active(currBank) <= '1';
             elsif command = pre_c then
                -- Close off the row
                active_row(currBank)    <= 0; -- SHOULD BE X FOR UNDEFINED, BUT ITS REDUNDANT TO is_row_active ANYWAY
                is_row_active(currBank) <= '0';
             elsif command = RD_c then
                wr_burst      <= (others => '0');
                column        <= unsigned(addr(sdram_colcount-1 downto 0));
                selected_bank <= currBank;
                -- establish read shift register dependent on burst length
                case mode_reg(2 downto 0) is
                   when "000" => rd_burst <= "000000001" & rd_burst(1);
                   when "001" => rd_burst <= "000000011" & rd_burst(1);
                   when "010" => rd_burst <= "000001111" & rd_burst(1);
                   when "011" => rd_burst <= "011111111" & rd_burst(1);
                   when "111" => rd_burst <= "111111111" & rd_burst(1);  -- full page
                   when others =>
                      -- full page not implemnted
                end case;
             end if;         
              -- Output masks lag a cycle 
              wr_mask <= not dqm;
          end if;         
          
          
          -- This is the logic that implements the CAS (CL) delay
          -- and the AL delay if applicable
          -- Modifying CL and AL delay ensures that access time is
          -- less than its equivalent in clocks, dependent on the
          -- clock frequency. 
          delayloop:
          for depth in data_delay_fromRAM'low to data_delay_fromRAM'high-1 loop
             data_delay_fromRAM(depth) <= data_delay_fromRAM(depth + 1);
          end loop;
          data_delay_fromRAM(data_delay_fromRAM'high) <= (others=>'Z');
          
          -- load data into the delay buffer while a read issue was less than
          -- burstlength halfclocks ago
          if reading = '1' then
            thisRead <= memory(active_row(selected_bank), selected_bank, column_i);
          
            column <= column+1;
            if dqm(0) = '0' then
              data_delay_fromRAM((AL + CL - 2)*2)(7 downto 0) <= memory(active_row(selected_bank), selected_bank, column_i)(7 downto 0);
            end if;
            
            if dqm(1) = '0' then
              data_delay_fromRAM((AL + CL - 2)*2)(15 downto 8) <= memory(active_row(selected_bank), selected_bank, column_i)(15 downto 8);
            end if;
          end if;
        end if;
   end process;

end Behavioral;