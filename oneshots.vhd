----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--FIFO_SYNC_MACRO : In order to incorporate this function into the design,
--     VHDL      : the following instance declaration needs to be placed
--   instance    : in the architecture body of the design code.  The
--  declaration  : (FIFO_SYNC_MACRO_inst) and/or the port declarations
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

entity oneshots is
Port (
    clk100       : in STD_LOGIC;
    
    GOS              : out globaloneshots_by_ramwidth18 := (others=>(others=>'0'));
    GOS_INCREMENT    : in globaloneshots_by_ramwidth18u;   
    GOS_STARTPOINT_Y : in globaloneshots_by_ramwidth18;
    GOS_MIDPOINT_Y   : in globaloneshots_by_ramwidth18;  
    GOS_ENDPOINT_Y   : in globaloneshots_by_ramwidth18;     

    GOS_RESET_EN : in STD_LOGIC;
    GOS_TO_RESET : in integer range 0 to OScount-1;
    
    initRam      : in boolean;
    ram_rst100   : in std_logic;
    OUTF_ALMOSTFULL : in std_logic
    );
           
end oneshots;

architecture Behavioral of oneshots is

signal GOS_phase : globaloneshots_by_ramwidth18u := (others=>(others=>'0'));

signal Z02_ONE_MINUS_T    : signed(RAM_WIDTH18 downto 0) := (others=>'0');
signal Z02_T              : signed(RAM_WIDTH18 downto 0) := (others=>'0');

signal Z01_phase    : unsigned(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z01_inc      : unsigned(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z03_A        : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z03_B        : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z03_C        : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z04_D        : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z04_E        : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z04_F        : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z05_F        : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal Z05_SUMA     : signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');

signal Z02_PHASE_CANDIDATE: unsigned(RAM_WIDTH18 -1 downto 0) := (others=>'0');

signal RAM18_WE  : std_logic_vector(1 downto 0) := "11";
signal RAM_RDEN    : std_logic :='0';
signal RAM_REGCE   : std_logic :='0';


signal Z00_curros: integer range 0 to OScount-1 := 0;
signal Z01_curros: integer range 0 to OScount-1 := 0;
signal Z02_curros: integer range 0 to OScount-1 := 0;
signal Z03_curros: integer range 0 to OScount-1 := 0;
signal Z04_curros: integer range 0 to OScount-1 := 0;
signal Z05_curros: integer range 0 to OScount-1 := 0;

signal ospredivide : unsigned(12 downto 0) := (others=>'0');

begin

bezier_proc: process(clk100)
begin    
if rising_edge(clk100) then    
if not initRam and OUTF_ALMOSTFULL = '0' then
-- Bezier curves:
-- from wikipedia:
-- B(t) = P0(1-t)^2 + 2*P1*(1-t)*t + P2*t^2
-- assume P0x = 0, P1x = .5, P2x = 1 => B(t)x = t, then
-- B(t)y = StartY(1-t)^2 + 2*MidY*(1-t)*t + EndY*t^2
-- or, B(t)y = StartY*A + 2*MidY*B + EndY*C
-- ot, B(t)y = D + E + F

ospredivide <= ospredivide + 1;

-- once a cycle
if(ospredivide(ospredivide'high - OScountlog2 downto 0) = 0) then 
    -- increase operable oneshot
    Z00_curros <= to_integer(ospredivide(ospredivide'high downto ospredivide'length - OScountlog2));
    Z01_curros <= Z00_curros;
    Z02_curros <= Z01_curros;
    Z03_curros <= Z02_curros;
    Z04_curros <= Z03_curros;
    Z05_curros <= Z04_curros;

    -- read in the current phase and increment
    Z01_phase <= GOS_phase(Z00_curros);
    Z01_inc   <= GOS_INCREMENT(Z00_curros);
    
    -- increment phase as appropriate
    GOS_phase(Z01_curros) <= ADDSU(Z01_phase, Z01_inc);    
    --  calculate t and 1-t values
    Z02_T           <= signed('0' & Z01_phase);
    Z02_ONE_MINUS_T <= signed('0' & (to_unsigned(2**18 -1,  18) - unsigned(Z01_phase)));
    
    -- signed multiplication requires an extra leftward shift of one
    Z03_A <= MULT(Z02_ONE_MINUS_T, Z02_ONE_MINUS_T, STD_FLOWWIDTH, 1);
    Z03_B <= MULT(Z02_ONE_MINUS_T, Z02_T,           STD_FLOWWIDTH, 1);
    Z03_C <= MULT(Z02_T,           Z02_T,           STD_FLOWWIDTH, 1);
    
    -- midpoint is multiplied by 2 AND 2 again to get the full range of Bezier
    Z04_E <= MULT(Z03_B, GOS_MIDPOINT_Y(Z03_curros), RAM_WIDTH18, 3);
    
    -- use the set startpoint and endpoint
    Z04_F <= MULT(Z03_C, GOS_ENDPOINT_Y(Z03_curros),   RAM_WIDTH18, 1);
    Z04_D <= MULT(Z03_A, GOS_STARTPOINT_Y(Z03_curros), RAM_WIDTH18, 1); 
    
    Z05_SUMA <= ADDS(Z04_D, Z04_E);
    Z05_F <= Z04_F;
    
    GOS(Z05_curros) <= ADDS(Z05_SUMA, Z05_F);
end if;

if(GOS_RESET_EN = '1') then
    GOS_phase(GOS_TO_RESET) <= (others=>'0');
end if;

end if;
end if;
end process;
end Behavioral;