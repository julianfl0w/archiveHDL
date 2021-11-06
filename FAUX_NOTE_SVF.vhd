----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------

-- here's what this nutso thing does
-- first, look at the flow diagram in Julius O Smith's State Variable Filter writeup
-- we need to run a single pole twice, effectively doubling the input sample rate
-- thats what the OVERSAMPLEFACTOR is
-- the rest is just implimentation
-- and plumbing
-- hopefully this code never breaks lol

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


Library work;
use work.memory_word_type.all;

entity faux_note_svf is
    
Port ( clk100     : in STD_LOGIC;
    Z03_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
            
    Z25_TO_PANNING: out signed(std_flowwidth-1 downto 0) := (others=>'0');
    Z09_TO_FILTER : in  signed(std_flowwidth-1 downto 0);
    
    Z04_OSRAW    : in oneshotspervoice_by_ramwidth18s;
    Z04_POLYLFORAW : in POLYLFOSpervoice_by_ramwidth18s;
    LFO           : in LFOcount_by_ramwidth18;

    MEM_WRADDR    : in STD_LOGIC_VECTOR(RAMADDR_WIDTH-1 downto 0);
    MEM_IN        : in STD_LOGIC_VECTOR(ram_width18-1 downto 0); 
    VOICE_FILTQ_WREN    : in STD_LOGIC;
    VOICE_FILTF_WREN    : in STD_LOGIC;
    FILT_FDRAW : in instcount_by_drawslog2;
    FILT_QDRAW : in instcount_by_drawslog2;
    FILT_FTYPE : in instcount_by_ftypeslog2;
    
    ram_rst100    : in std_logic;
    initRam       : in boolean;
    OUTF_ALMOSTFULL  : in std_logic
    );
           
end faux_note_svf;

architecture Behavioral of faux_note_svf is


-- constants
constant OVERSAMPLEFACTOR : integer := 3;
constant singlesampleclkreq : integer := 7;

type Uarray is array (10 to 10 + singlesampleclkreq * (OVERSAMPLEFACTOR -1)) of signed(std_flowwidth-1 downto 0);
signal Z10_U : Uarray := (others=>(others=>'0'));

begin


-- timing proc does basic plumbing and timing
-- kind of a catchall process
timing_proc: process(clk100)
begin 
if rising_edge(clk100) then
    if not initram and OUTF_ALMOSTFULL = '0' then
    -- read and propagate input
    Z10_U(10) <= Z09_TO_FILTER;
    -- LP input and propagation
    inputprop: for i in Z10_U'low+1 to Z10_U'high loop Z10_U(i) <= Z10_U(i-1); end loop;
             
    Z25_TO_PANNING <= Z10_U(10 + singlesampleclkreq*(OVERSAMPLEFACTOR -1));   
    end if;
end if;
end process;

end Behavioral;