library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY tempo_tb IS 
END tempo_tb;

ARCHITECTURE behavior OF tempo_tb IS
-- Component Declaration for the Unit Under Test (UUT)

COMPONENT tempo
--just copy and paste the input and output ports of your module as such. 
Port ( 
    -- GPIF Signals
    GPIF_CLK      : in std_logic;               ---output clk 100 Mhz and 180 phase shift                       
    TEMPO_PULSE  : out std_logic := '0';
    i2s_cycle_begin : in STD_LOGIC;  
    
    TEMPOPULSE    : out std_logic := '0';     
    TEMPOPULSE_DATA : out std_logic_vector(gpif_width -1 downto 0) := (others=>'0');    
    BeatPulse     : in std_logic := '0';
    measureCount  : in unsigned(MEASUREMAXLOG2-1 downto 0);
    beatCount     : in unsigned(BEATMAXLOG2-1 downto 0);
    beatLengthWREN   : in std_logic := '0';
    MEM_IN25  : in unsigned (DIV_LENGTH-1 downto 0);
    
    initRamGPIF   : in std_logic
    );
END COMPONENT;

constant GPIF_CLK_period : time := 20.83333333 ns;

constant beatPeriod : time := 7ms;
constant samplePeriod : time := 20.83333us;

signal GPIF_CLK       : STD_LOGIC := '0';          
signal TEMPO_PULSE     : std_logic := '0';
signal i2s_cycle_begin : STD_LOGIC := '0';

signal TEMPOPULSE    : std_logic := '0';     
signal TEMPOPULSE_DATA : std_logic_vector(gpif_width -1 downto 0) := (others=>'0');  
signal BeatPulse     : std_logic := '0';
signal measureCount  : unsigned(MEASUREMAXLOG2-1 downto 0) := to_unsigned(16, MEASUREMAXLOG2);
signal beatCount     : unsigned(BEATMAXLOG2-1 downto 0) := to_unsigned(4, BEATMAXLOG2);
signal MEM_IN25  : unsigned (DIV_LENGTH-1 downto 0) := (others=>'0');
signal beatLengthWREN   : std_logic := '0';

signal initRamGPIF   : std_logic := '0';


BEGIN

-- Instantiate the Unit Under Test (UUT)
i_tempo: tempo Port Map( 
    -- GPIF Signals
    GPIF_CLK    =>  GPIF_CLK,
    TEMPO_PULSE   => TEMPO_PULSE,
    i2s_cycle_begin => i2s_cycle_begin,
    
    TEMPOPULSE    => TEMPOPULSE,
    TEMPOPULSE_DATA => TEMPOPULSE_DATA,
    BeatPulse     => BeatPulse,
    measureCount  => measureCount,
    beatCount     => beatCount,
    beatLengthWREN  => beatLengthWREN,
    MEM_IN25 => MEM_IN25,
    initRamGPIF   => initRamGPIF
);

-- Clock process definitions( clock with 50% duty cycle is generated here.
GPIF_CLK_process: process
begin
    GPIF_CLK <= '0';
    wait for GPIF_CLK_period/2;  --for 0.5 ns signal is '0'.
    GPIF_CLK <= '1';
    wait for GPIF_CLK_period/2;  --for next 0.5 ns signal is '1'.
end process;
   
beatproc: process
begin
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '1';
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '0';
    wait for beatPeriod;
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '1';
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '0';
    wait for beatPeriod;
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '1';
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '0';
    wait for beatPeriod;
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '1';
    wait until falling_edge(GPIF_CLK);
    BeatPulse <= '0';
    wait for beatPeriod;
    
    wait;
end process;

sampleproc: process
begin
    wait for samplePeriod;
    wait until falling_edge(GPIF_CLK);
    i2s_cycle_begin <= '1';
    wait until falling_edge(GPIF_CLK);
    i2s_cycle_begin <= '0';
end process;
END;