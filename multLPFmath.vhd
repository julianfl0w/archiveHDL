----------------------------------------------------------------------------------
-- Julian Loiacono 01/2018
--
-- 18 bits
-- Basic building block which takes any param value as input and returns the 
-- low-passed version of it.
-- consider using shift instead of multiply to reduce resource count
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

entity multLPFmath is
Port ( 
    clk100       : in STD_LOGIC;
    
    Z00_PARAM_THIS   : in signed(ram_width18 -1 downto 0);
    Z00_PARAM_LAST   : in signed(ram_width18 -1 downto 0);
    Z01_ALPHA_IN     : in signed(ram_width18 -1 downto 0);
    Z03_PARAM_OUT    : out signed(ram_width18 -1 downto 0);
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end multLPFmath;

architecture Behavioral of multLPFmath is
   
attribute mark_debug : string;
signal Z00_LASTPARAM : signed(ram_width18 -1 downto 0) := (others=>'0');
signal Z01_LASTPARAM : signed(ram_width18 -1 downto 0) := (others=>'0');
signal Z02_LASTPARAM : signed(ram_width18 -1 downto 0) := (others=>'0');
signal Z02_POSTALPHA : signed(ram_width18 -1 downto 0) := (others=>'0');
signal Z02_ALPHA_IN  : signed(ram_width18 -1 downto 0) := (others=>'0');
signal Z01_PARAM_IN  : signed(ram_width18 -1 downto 0) := (others=>'0');
signal Z02_PARAM_IN  : signed(ram_width18 -1 downto 0) := (others=>'0');

signal Z01_DIFF  : signed(ram_width18 -1 downto 0) := (others=>'0');
    
begin 
    
phase_proc: process(clk100)
begin
if rising_edge(clk100) then
Z03_PARAM_OUT <= (others=>'0');
if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
    
    -- y(i) = x(i) + a*(x(i) - y(i-1))
    
    Z01_DIFF      <= Z00_PARAM_THIS - Z00_LASTPARAM; 
    Z02_POSTALPHA <= MULT(Z01_DIFF, Z01_ALPHA_IN, RAM_WIDTH18, 1);
    
    Z02_ALPHA_IN  <= Z01_ALPHA_IN;
    
    Z01_LASTPARAM <= Z00_LASTPARAM; 
    Z02_LASTPARAM <= Z01_LASTPARAM;
    
    Z01_PARAM_IN <= Z00_PARAM_THIS;
    Z02_PARAM_IN <= Z01_PARAM_IN;
        
    -- if speed is full, don't delay before increasing increment to full
    -- furthermore, set full if difference is 0
    if Z02_ALPHA_IN = to_signed(2**16, RAM_WIDTH18) or Z02_POSTALPHA = 0 then
        Z03_PARAM_OUT <= Z02_PARAM_IN;
    -- otherwise, only increase inccurr every 64th sample
    else
        Z03_PARAM_OUT <= Z02_LASTPARAM + Z02_POSTALPHA;
    end if;
    
end if;
end if;
end process;
end Behavioral;