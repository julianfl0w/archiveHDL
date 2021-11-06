library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY polylfos_tb IS 
END polylfos_tb;

ARCHITECTURE behavior OF polylfos_tb IS
-- Component Declaration for the Unit Under Test (UUT)
COMPONENT polylfos

--just copy and paste the input and output ports of your module as such. 
-- when draw is 1, least significant 2 bits of ALIGN, DEPTH, and INCREMENT are envelope
Port ( 
    clk100               : in  STD_LOGIC;
    ZN6_ADDR             : in  unsigned(RAMADDR_WIDTH -1 downto 0);
    ZN4_OS            : in  oneshotspervoice_by_ramwidth18s;
    POLYLFOWAVEFORM      : in  insts_by_COMPUTED_ENVELOPESpervoice_by_wfcountlog2;
    POLYLFOALIGN_DRAW    : in  insts_by_COMPUTED_ENVELOPEspervoice_by_drawslog2;
    POLYLFODEPTH_DRAW    : in  insts_by_COMPUTED_ENVELOPEspervoice_by_drawslog2;
    POLYLFOINC_DRAW      : in  insts_by_COMPUTED_ENVELOPEspervoice_by_drawslog2;
    Z00_COMPUTED_ENVELOPE       : out inputcount_by_ramwidth18s := (others=>(others=>'0'));
    Z00       : out inputcount_by_ramwidth18s := (others=>(others=>'0'));
    ZN4_ZERO_CROSS       : in  std_logic;
    
    MEM_WRADDR           : in std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    MEM_IN               : in std_logic_vector(ram_width18-1 downto 0); 
    
    POLYLFOALIGN_WREN    : in std_logic;
    POLYLFO_INC_WREN     : in std_logic;
    POLYLFODEPTH_WREN    : in std_logic;
    
    initRam100              : in std_logic;
    ram_rst100           : in std_logic;
    OUTSAMPLEF_ALMOSTFULL: in std_logic
    );
    
END COMPONENT;

component ram_active_rst is
Port ( clkin      : in STD_LOGIC;
       clksRdy    : in STD_LOGIC;
       ram_rst    : out STD_LOGIC := '0';
       initializeRam_out : out std_logic := '1'
       );
end component;
   
-- Clock period definitions
constant clk100_period : time := 10 ns;
signal clk100          : STD_LOGIC := '0';
signal clksRdy         : STD_LOGIC := '1';

signal ZN6_ADDR             : unsigned(RAMADDR_WIDTH -1 downto 0) := (others => '0');
signal ZN4_OS           : oneshotspervoice_by_ramwidth18s :=  (others=>(others=>'0'));
signal POLYLFOWAVEFORM       : insts_by_COMPUTED_ENVELOPESpervoice_by_wfcountlog2  := (others=>(others=>0));
signal POLYLFOALIGN_DRAW     : insts_by_COMPUTED_ENVELOPEspervoice_by_drawslog2 := (others=>(others=>0));
signal POLYLFODEPTH_DRAW     : insts_by_COMPUTED_ENVELOPEspervoice_by_drawslog2 := (others=>(others=>0));
signal POLYLFOINC_DRAW : insts_by_COMPUTED_ENVELOPEspervoice_by_drawslog2 := (others=>(others=>0));
signal Z00_COMPUTED_ENVELOPE        : inputcount_by_ramwidth18s := (others=>(others=>'0'));
signal Z00        : inputcount_by_ramwidth18s := (others=>(others=>'0'));
signal ZN4_ZERO_CROSS       : std_logic := '0';
    
signal MEM_WRADDR           : std_logic_vector(RAMADDR_WIDTH -1 downto 0) := (others => '0');
signal MEM_IN               : std_logic_vector(ram_width18-1 downto 0) := (others => '0');
    
signal POLYLFOALIGN_WREN    : std_logic := '0';
signal POLYLFO_INC_WREN     : std_logic := '0';
signal POLYLFODEPTH_WREN    : std_logic := '0';
    
signal initRam100              : std_logic;
signal ram_rst100           : std_logic;
signal OUTSAMPLEF_ALMOSTFULL: std_logic := '0';

constant square_period : time := 100us;

BEGIN
-- Instantiate the Unit(s) Under Test
i_COMPUTED_ENVELOPEs: polylfos PORT MAP (
    clk100             => clk100,
    ZN6_ADDR           => ZN6_ADDR,
    ZN4_OS          => ZN4_OS,
    POLYLFOWAVEFORM    => POLYLFOWAVEFORM,
    POLYLFOALIGN_DRAW  => POLYLFOALIGN_DRAW,
    POLYLFODEPTH_DRAW  => POLYLFODEPTH_DRAW,
    POLYLFOINC_DRAW    => POLYLFOINC_DRAW,
    Z00_COMPUTED_ENVELOPE     => Z00_COMPUTED_ENVELOPE,
    Z00     => Z00,
    ZN4_ZERO_CROSS     => ZN4_ZERO_CROSS,
    
    MEM_WRADDR         => MEM_WRADDR,
    MEM_IN             => MEM_IN,
    
    POLYLFOALIGN_WREN  => POLYLFOALIGN_WREN,
    POLYLFO_INC_WREN   => POLYLFO_INC_WREN,
    POLYLFODEPTH_WREN  => POLYLFODEPTH_WREN,
    
    initRam100            => initRam100,
    ram_rst100         => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL  => OUTSAMPLEF_ALMOSTFULL
    ); 

i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    clksRdy            => clksRdy, 
    ram_rst            => ram_rst100,
    initializeRam_out  => initRam100
    );
    
-- Clock process definitions( clock with 50% duty cycle is generated here.)
clk100_gen: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

clk100_process: process(clk100)
begin
if rising_edge(clk100) then
    ZN6_ADDR <= ZN6_ADDR +1;
end if;
end process;


-- square wave gen
square_process: process
begin
    wait for square_period/2;  
    ZN4_ZERO_CROSS <= '1';
    wait for square_period/2; 
    ZN4_ZERO_CROSS <= '0';
end process;

-- this simple test ensures basic functionality of polylfos and zerocrossdetection
-- a square wave is fed as TO_VOLFX. we expect POLYLFOwf to vary continuously,
-- but POLYLFOzcd to only update on a zero cross

POLYLFOtest: process
begin
    wait until initRam100 = '0';
    wait for clk100_period/4;
    -- saw type
    MEM_WRADDR <= std_logic_vector(to_unsigned(0, RAMADDR_WIDTH));
    POLYLFOWAVEFORM(0,0)     <= WF_SAW_I;
    POLYLFOALIGN_DRAW(0,0)   <= DRAW_FIXED_I;
    -- center align
    MEM_IN                   <= std_logic_vector(to_signed(0, RAM_WIDTH18));
    POLYLFOALIGN_WREN     <= '1';
    wait for clk100_period;
    POLYLFOALIGN_WREN     <= '0';
    
    POLYLFODEPTH_DRAW(0,0)   <= DRAW_FIXED_I;
    MEM_IN                   <= std_logic_vector(to_signed(2**14, RAM_WIDTH18));    -- eighth depth
    POLYLFODEPTH_WREN     <= '1';
    wait for clk100_period;
    POLYLFODEPTH_WREN     <= '0';
    
    POLYLFOINC_DRAW(0,0) <= DRAW_FIXED_I;
    MEM_IN               <= std_logic_vector(to_signed(2**13, RAM_WIDTH18));
    POLYLFO_INC_WREN  <= '1';
    wait for clk100_period;
    POLYLFO_INC_WREN  <= '0';


    -- saw type
    POLYLFOWAVEFORM(0,1)     <= WF_SINE_I;
    POLYLFOALIGN_DRAW(0,1)   <= DRAW_FIXED_I;
    -- center align
    MEM_IN                   <= std_logic_vector(to_signed(0, RAM_WIDTH18));
    MEM_WRADDR <= std_logic_vector(to_unsigned(1, RAMADDR_WIDTH));
    POLYLFOALIGN_WREN     <= '1';
    wait for clk100_period;
    POLYLFOALIGN_WREN     <= '0';
    
    POLYLFODEPTH_DRAW(0,1)   <= DRAW_FIXED_I;
    MEM_IN                   <= std_logic_vector(to_signed(2**14, RAM_WIDTH18));    -- eighth depth
    POLYLFODEPTH_WREN     <= '1';
    wait for clk100_period;
    POLYLFODEPTH_WREN     <= '0';
    
    POLYLFOINC_DRAW(0,1)<= DRAW_FIXED_I;
    MEM_IN                   <= std_logic_vector(to_signed(2**13, RAM_WIDTH18));
    POLYLFO_INC_WREN  <= '1';
    wait for clk100_period;
    POLYLFO_INC_WREN  <= '0';
 
     -- tri type
    POLYLFOWAVEFORM(0,2)      <= WF_TRI_I;
    POLYLFOALIGN_DRAW(0,2)    <= DRAW_FIXED_I;
    -- center align
    MEM_IN     <= std_logic_vector(to_signed(0, RAM_WIDTH18));
    MEM_WRADDR <= std_logic_vector(to_unsigned(2, RAMADDR_WIDTH));
    POLYLFOALIGN_WREN      <= '1';
    wait for clk100_period;
    POLYLFOALIGN_WREN      <= '0';
    
    POLYLFODEPTH_DRAW(0,2)    <= DRAW_FIXED_I;
    MEM_IN                    <= std_logic_vector(to_signed(2**14, RAM_WIDTH18));    -- eighth depth
    POLYLFODEPTH_WREN      <= '1';
    wait for clk100_period;
    POLYLFODEPTH_WREN      <= '0';
    
    POLYLFOINC_DRAW(0,2)<= DRAW_FIXED_I;
    MEM_IN                   <= std_logic_vector(to_signed(2**13, RAM_WIDTH18));
    POLYLFO_INC_WREN  <= '1';
    wait for clk100_period;
    POLYLFO_INC_WREN  <= '0';   
    wait;
end process;

END;