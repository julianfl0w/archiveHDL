----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- Julian Loiacono 6/2016
--
--
-- Description: Generate an low-volume sine wave, at around 400 Hz
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--FIFO_DUALCLOCK_MACRO : In order to incorporate this function into the design,
--     VHDL      : the following instance declaration needs to be placed
--   instance    : in the architecture body of the design code.  The
--  declaration  : (FIFO_DUALCLOCK_MACRO_inst) and/or the port declarations
--     code      : after the "=>" assignment maybe changed to properly
--               : reference and connect this function to the design.
--               : All inputs and outputs must be connected.

--    Library    : In addition to adding the instance declaration, a use
--  declaration  : statement for the UNISIM.vcomponents library needs to be
--      for      : added before the entity declaration.  This library
--    Xilinx     : contains the component declarations for all Xilinx
--   primitives  : primitives and points to the models that will be used
--               : for simulation.

--  Copy the following four statements and paste them before the
--  Entity declaration, unless they already exist.

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;
entity aShift is
    Generic(
      shiftmin  : natural;
      shiftmax  : natural
    );
    Port ( 
       clk100 : in STD_LOGIC;
       Z00_to_shift : in sfixed;
       Z00_bitstoshift: in natural;
       Z01_shifted  : out sfixed
       );
           
end aShift;

architecture Behavioral of aShift is

type AllPossibleShiftsArray is array (shiftmin to shiftmax) of sfixed(Z01_shifted'high downto Z01_shifted'low);
signal Z01_AllPossibleShifts : AllPossibleShiftsArray := (others=>(others=>'0'));
signal Z01_bitstoshift: natural := shiftmin;

begin

Z01_shifted <= Z01_AllPossibleShifts(Z01_bitstoshift);

pipeline: process(clk100)
    begin
        if rising_edge(clk100) then
            Z01_bitstoshift <= Z00_bitstoshift;
            
            shiftsloop:
            for shift in shiftmin to shiftmax loop
                bitsloop:
                for abit in Z01_shifted'low to Z01_shifted'high loop
                    if abit + shift < Z00_to_shift'length then   
                        -- actual shifting
                        Z01_AllPossibleShifts(shift)(abit) <= Z00_to_shift(abit + shift);
                    else
                        -- sign extension
                        Z01_AllPossibleShifts(shift)(abit) <= Z00_to_shift(Z00_to_shift'high);
                    end if;
                end loop;
            end loop;
        end if;
    end process;
    
end Behavioral;
