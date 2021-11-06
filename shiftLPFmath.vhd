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

entity shiftLPFmath is
Port ( 
    clk100       : in STD_LOGIC;
    
    Z00_PARAM_THIS   : in sfixed;
    Z00_PARAM_LAST   : in sfixed;
    Z01_SHIFT_IN     : in integer;
    Z03_PARAM_OUT    : out sfixed := (others=>'0');
    
    initRam100      : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end shiftLPFmath;

architecture Behavioral of shiftLPFmath is
   
attribute mark_debug : string;
signal Z01_LASTPARAM : sfixed(1 downto -Z00_PARAM_THIS'length + 2) := (others=>'0');
signal Z02_LASTPARAM : sfixed(1 downto -Z00_PARAM_THIS'length + 2) := (others=>'0');
signal Z02_POSTALPHA : sfixed(1 downto -Z00_PARAM_THIS'length + 2) := (others=>'0');
signal Z01_PARAM_IN  : sfixed(1 downto -Z00_PARAM_THIS'length + 2) := (others=>'0');
signal Z02_PARAM_IN  : sfixed(1 downto -Z00_PARAM_THIS'length + 2) := (others=>'0');

signal Z01_DIFF  : sfixed(1 downto -Z00_PARAM_THIS'length + 2) := (others=>'0');
    
begin 
    
phase_proc: process(clk100)
begin
if rising_edge(clk100) then
Z03_PARAM_OUT <= (others=>'0');
if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
    
    -- y(i) = x(i) + a*(x(i) - y(i-1))
    
    Z01_DIFF      <= resize(Z00_PARAM_THIS - Z00_PARAM_LAST, Z01_DIFF); 
    Z02_POSTALPHA <= Z01_DIFF sra Z01_SHIFT_IN;
    
    Z01_LASTPARAM <= Z00_PARAM_LAST; 
    Z02_LASTPARAM <= Z01_LASTPARAM;
    
    Z01_PARAM_IN <= Z00_PARAM_THIS;
    Z02_PARAM_IN <= Z01_PARAM_IN; 
        
    -- if speed is full, don't delay before increasing increment to full
    -- furthermore, set full if difference is 0 or -1
    if Z02_POSTALPHA = 0 or signed(to_slv(Z02_POSTALPHA)) = -1 then
        Z03_PARAM_OUT <= Z02_PARAM_IN;
    else
        Z03_PARAM_OUT <= resize(Z02_LASTPARAM + Z02_POSTALPHA, Z00_PARAM_THIS);
    end if;
    
end if;
end if;
end process;
end Behavioral;