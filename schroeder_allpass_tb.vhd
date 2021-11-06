library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY schroeder_allpass_tb IS 
END schroeder_allpass_tb;

ARCHITECTURE behavior OF schroeder_allpass_tb IS
-- Component Declaration for the Unit Under Test (UUT)
--just copy and paste the input and output ports of your module as such. 
COMPONENT schroeder_allpass
Port ( 
    clk100          : in STD_LOGIC;
    ZN8_ADDR        : in unsigned (RAMADDR_WIDTH-1 downto 0);
    
    DELAY_SAMPLES   : in instcount_by_delaytaps_by_ramwidth18u;
    DELAY_SAMPLES_DRAW : in instcount_by_delaytaps_by_drawslog2;
    MEM_IN       : in std_logic_vector(ram_width18 -1 downto 0);
    MEM_WRADDR   : in std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    GAIN_WREN    : in std_logic;
    
    Z00_schroeder_IN : in  sfixed(1 downto -STD_FLOWWIDTH + 2);
    Z12_schroeder_OUT: out sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
    
    ZN2_OS  : in oneshotspervoice_by_ramwidth18s;
    ZN2_COMPUTED_ENVELOPE    : in inputcount_by_ramwidth18s;
    
    ram_rst100     : in std_logic;
    initRam100        : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
END COMPONENT;


component ram_active_rst is
Port ( clkin      : in STD_LOGIC;
   clksRdy    : in STD_LOGIC;
   ram_rst    : out STD_LOGIC := '0';
   initializeRam_out0 : out std_logic := '1';
   initializeRam_out1 : out std_logic := '1'
   );
end component;
   
signal DELAY_SAMPLES_DRAW   : instcount_by_delaytaps_by_drawslog2 := (others=>(others=>(others=>'0')));
signal ZN2_OS               : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal ZN2_COMPUTED_ENVELOPE: inputcount_by_ramwidth18s := (others=>(others=>'0'));
    
-- Clock period definitions
constant clk100_period : time := 10 ns;
signal clk100       : STD_LOGIC := '0';

-- 10ms ~= 100 Hz
constant square_period : time := 1 ms;
signal square          : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal saw             : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');

signal OUTSAMPLEF_ALMOSTFULL : std_logic := '0';
signal clksRdy    : std_logic := '1';
signal initRam100   : std_logic := '1';
signal initRam100_1 : std_logic := '1';
signal ram_rst100 : std_logic := '0';
signal GAIN_WREN : std_logic := '0';

signal MEM_IN       : STD_LOGIC_VECTOR(ram_width18 -1 downto 0)   := (others=>'0');
signal MEM_WRADDR   : STD_LOGIC_VECTOR(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal Z00_ADDR     : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN8_ADDR     : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');

signal Z00_schroeder_IN : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z12_schroeder_OUT : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z13_schroeder_OUT : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
    
signal SAMPLECOUNT : integer := 0;
signal DELAY_SAMPLES   : instcount_by_delaytaps_by_ramwidth18u := (others=>(others=>(others=>'0')));

constant TAPNO0  : std_logic_vector(1 downto 0) := "00";
constant TAPNO1  : std_logic_vector(1 downto 0) := "01";
constant TAPNO2  : std_logic_vector(1 downto 0) := "10";
constant INSTNO : std_logic_vector(1 downto 0) := "00";

BEGIN

i_schroeder_allpass: schroeder_allpass Port map ( 
    clk100          => clk100,
    ZN8_ADDR        => ZN8_ADDR,
    
    DELAY_SAMPLES => DELAY_SAMPLES,
    DELAY_SAMPLES_DRAW => DELAY_SAMPLES_DRAW,
    MEM_IN       => MEM_IN,
    MEM_WRADDR   => MEM_WRADDR,
    GAIN_WREN    => GAIN_WREN,
    
    Z00_schroeder_IN  => Z00_schroeder_IN,
    Z12_schroeder_OUT => Z12_schroeder_OUT,
    
    ZN2_OS   => ZN2_OS,
    ZN2_COMPUTED_ENVELOPE => ZN2_COMPUTED_ENVELOPE,
        
    ram_rst100     => ram_rst100,
    initRam100        => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
);

i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    ram_rst            => ram_rst100,
    clksRdy            => clksRdy,
    initializeRam_out0  => initRam100,
    initializeRam_out1  => initRam100_1
    );

-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

-- generate a square wave
square_proc: process
begin
    square <= to_sfixed(2**22 , square);
    wait for square_period/2;
    square <= to_sfixed(-2**22, square);
    wait for square_period/2;
end process;


timing_proc: process(clk100)
begin
    if rising_edge(clk100) then
        ZN8_ADDR <= ZN8_ADDR + 1;
        Z00_ADDR <= ZN8_ADDR - 7;       
        Z13_schroeder_OUT <= Z12_schroeder_OUT;
        if signed(Z00_ADDR) >= -1 and signed(Z00_ADDR) < 3 then
            --Z00_schroeder_IN <= SQUARE;
            Z00_schroeder_IN <= saw;
        else
            Z00_schroeder_IN <= (others=>'0');
        end if;
        
        if Z00_ADDR = -2 then
            saw <= resize(saw + to_sfixed(0.05, saw), saw,  fixed_wrap, fixed_truncate);
        end if;
    end if;
end process;
   
envtest: process
begin
    wait until initRam100 = '0';
    wait until rising_edge(clk100);
    DELAY_SAMPLES(0,0) <= to_unsigned(100, RAMADDR_WIDTH);
    GAIN_WREN <= '1';
        
    -- set gains
    MEM_IN <= std_logic_vector(to_unsigned(0, RAM_WIDTH18));
    MEM_WRADDR <= INSTNO & "0000" & TAPNO0 & FBGAIN_ADDR;
    wait until rising_edge(clk100);
    MEM_WRADDR <= INSTNO & "0000" & TAPNO1 & FBGAIN_ADDR;
    wait until rising_edge(clk100);
    MEM_WRADDR <= INSTNO & "0000" & TAPNO2 & FBGAIN_ADDR;
    wait until rising_edge(clk100);
    
    MEM_IN <= std_logic_vector(to_unsigned(2**16, RAM_WIDTH18));
    MEM_WRADDR <= INSTNO & "0000" & TAPNO0 & FORWARDGAIN_ADDR;
    wait until rising_edge(clk100);
    --MEM_IN <= std_logic_vector(to_unsigned(2**16, RAM_WIDTH18));
    MEM_WRADDR <= INSTNO & "0000" & TAPNO1 & FORWARDGAIN_ADDR;
    wait until rising_edge(clk100);
    MEM_WRADDR <= INSTNO & "0000" & TAPNO2 & FORWARDGAIN_ADDR;
    wait until rising_edge(clk100);
        
    MEM_IN <= std_logic_vector(to_unsigned(0, RAM_WIDTH18));
    MEM_WRADDR <= INSTNO & "0000" & TAPNO0 & COLORGAIN_ADDR;
    wait until rising_edge(clk100);
    MEM_IN <= std_logic_vector(to_unsigned(0, RAM_WIDTH18));
    MEM_WRADDR <= INSTNO & "0000" & TAPNO1 & COLORGAIN_ADDR;
    wait until rising_edge(clk100);
    MEM_WRADDR <= INSTNO & "0000" & TAPNO2 & COLORGAIN_ADDR;
    wait until rising_edge(clk100);
    
    MEM_IN <= std_logic_vector(to_unsigned(0, RAM_WIDTH18));
    MEM_WRADDR <= INSTNO & "0000" & TAPNO0 & INPUT_GAIN_ADDR;
    wait until rising_edge(clk100);
    MEM_WRADDR <= INSTNO & "0000" & TAPNO1 & INPUT_GAIN_ADDR;
    wait until rising_edge(clk100);
    MEM_WRADDR <= INSTNO & "0000" & TAPNO2 & INPUT_GAIN_ADDR;
    wait until rising_edge(clk100);
    GAIN_WREN <= '0';
    wait;
end process;
END;
