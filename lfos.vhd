----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Julian Juixxxe Loiacono
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library work;
use work.memory_word_type.all;

entity LFOs is

Port ( 
    clk100         : in STD_LOGIC;
    LFO_RESET      : in unsigned(lfocount-1 downto 0);
    LFO_PHASEREF   : in LFOcount_by_lfocountlog2;
    LFO_INCREF     : in LFOcount_by_lfocountlog2;
    LFO_ALIGN      : in LFOcount_by_ramwidth18;
    LFO_WF         : in LFOcount_by_wfcountlog2;
    LFO_INCREMENT  : in LFOcount_by_ramwidth18;
    LFO_DEPTH      : in LFOcount_by_ramwidth18;
    LFO            : out LFOcount_by_ramwidth18 := (others=>(others=>'0'));
    
    initRam        : in boolean;
    OUTF_ALMOSTFULL   : in std_logic
   );
end LFOs;

architecture Behavioral of LFOs is

constant LFO_clk_div    : integer := 8;
signal LFO_predivide    : unsigned(LFO_clk_div + lfocountLOG2 - 1 downto 0) := (others=>'0');

signal LFO_phase        : LFOcount_by_ramwidth18 := (others=>(others=>'0'));
signal Z03_LFO_basewaveform : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z01_LFO_phase : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z01_LFO_INC   : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z02_LFO_phase_prime     : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal LFO_internal     : LFOcount_by_ramwidth18 := (others=>(others=>'0'));

signal Z04_LFO_afterdepth   : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z01_basephasedraw: integer range 0 to lfocount -1;
signal Z00_currlfo   : integer range 0 to lfocount -1;
signal Z01_currlfo   : integer range 0 to lfocount -1;
signal Z02_currlfo   : integer range 0 to lfocount -1;
signal Z03_currlfo   : integer range 0 to lfocount -1;
signal Z04_currlfo   : integer range 0 to lfocount -1;

begin

LFO <= LFO_internal;

-- this is a lazy pipeline, and only updates when the majority of the clock divider is zero
-- pipeline step 1: increment phase
-- pipeline step 2: convert to wave
-- pipeline step 3: multiply by depth
-- pipeline step 4: align as appropriate

LFOsummer: process(clk100)
begin
    if rising_edge(clk100) then
    if not initRam and OUTF_ALMOSTFULL='0' then
        LFO_predivide <= LFO_predivide + 1;
        if LFO_predivide(LFO_predivide'high - lfocountLOG2 downto 0) = 0 then
            Z00_currlfo <= to_integer(LFO_predivide(LFO_predivide'high downto LFO_predivide'length - lfocountLOG2));
            Z01_currlfo <= Z00_currlfo;
            Z02_currlfo <= Z01_currlfo;
            Z03_currlfo <= Z02_currlfo;
            Z04_currlfo <= Z03_currlfo;

            -- step 0: get lfo phase and increment relative to dependence
            Z01_LFO_phase <= LFO_phase(LFO_PHASEREF(Z00_currlfo));
            -- if inc ref is self, set increment normally
            if(LFO_INCREF(Z00_currlfo) = Z00_currlfo) then
                Z01_LFO_INC <= LFO_INCREMENT(Z00_currlfo);
            -- otherwise add the referenced waveform
            else
                Z01_LFO_INC <= LFO_INCREMENT(Z00_currlfo) + LFO_internal(LFO_INCREF(Z00_currlfo));
            end if;
            
            --step 1: modify phase appropriately
            Z02_LFO_phase_prime <= Z01_LFO_phase + Z01_LFO_INC;
            
            -- Step 2: convert to wave, store phase
            Z03_LFO_basewaveform <= GETWF(LFO_WF(Z02_currlfo), Z02_LFO_phase_prime);
            LFO_phase(Z02_currlfo) <= Z02_LFO_phase_prime;
            
            --step 3: multiply by depth
            Z04_LFO_afterdepth <= MULT(Z03_LFO_basewaveform, LFO_DEPTH(Z03_currlfo), RAM_WIDTH18, 1); 
                        
            --step 4: align as appropriate
            LFO_internal(Z04_currlfo) <= LFO_ALIGN(Z04_currlfo) + Z04_LFO_afterdepth;

        end if;
        
        for i in 0 to LFO_RESET'high loop
            if LFO_RESET(i) = '1' then
                LFO_phase(i) <= (others=>'0');
            end if;
        end loop;
    end if;
    end if;
end process;
end Behavioral;
