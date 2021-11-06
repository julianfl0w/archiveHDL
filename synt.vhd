library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY instrument_effects_tb IS 
END instrument_effects_tb;

ARCHITECTURE behavior OF instrument_effects_tb IS

component instrument_effects is
Port ( 
    clk100        : in STD_LOGIC;
    Z00_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
    Z00_INSTFX_IN : in signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
    OUTSAMPLEF_DI   : out signed(i2s_width -1 downto 0) := (others=>'0');
    OUTSAMPLEF_WREN : out std_logic := '0';
    
    -- parameters for ALLPASS can be set for REVERBDELAYPHASERFLANGER
    FB_GAIN         : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    COLOR_GAIN      : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    FORWARD_GAIN    : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    INPUT_GAIN      : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    DELAY_SAMPLES   : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    
    INST_SHIFT  : in integer range 0 to instcount-1;
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

component ram_active_rst is
Port ( 
    clksRdy           : in STD_LOGIC;
    clk100            : in STD_LOGIC;
    ram_rst100        : out STD_LOGIC := '0';
    initializeRam_out : out std_logic := '1'
    );
end component;

component clocks is
port (
    clksRdy : out std_logic;
    clk100  : in std_logic;
    clk200  : out std_logic;
    GPIF_CLK : out std_logic);
end component;

signal clksRdy       : std_logic;
signal clk100        : STD_LOGIC;
signal clk200        : STD_LOGIC;
signal GPIF_clk      : STD_LOGIC;
signal reset         : STD_LOGIC := '0';

-- instrument effects signals
signal ZN1_ADDR      : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z00_ADDR      : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal square        : integer := 0;
signal Z00_INSTFX_IN : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal OUTSAMPLEF_DI    : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal OUTSAMPLEF_WREN  : std_logic := '0';
    
-- parameters for ALLPASS can be set for REVERBDELAYPHASERFLANGER
-- these particular values establish an 8-tap schroeder reverb
signal FB_GAIN        : instcount_by_channelcount_by_delaytaps_by_ramwidth := (others=>(others=>(others=>"110000000000000000")));
signal COLOR_GAIN     : instcount_by_channelcount_by_delaytaps_by_ramwidth := (others=>(others=>(others=>"001100000000000000")));
signal FORWARD_GAIN   : instcount_by_channelcount_by_delaytaps_by_ramwidth := (others=>(others=>(others=>"001111111111111111")));
signal INPUT_GAIN     : instcount_by_channelcount_by_delaytaps_by_ramwidth := (others=>(others=>(others=>"000000000000000000")));
signal DELAY_SAMPLES  : instcount_by_channelcount_by_delaytaps_by_ramwidth := (others=>(others=>(others=>to_signed(50, RAM_WIDTH18))));

signal INST_SHIFT  : integer range 0 to instcount-1 := 2;
signal OUTSAMPLEF_ALMOSTFULL : std_logic := '0';

-- the sole input param: delay tap position relative to current address
signal TAP_LOCATION  : instcount_times_channelcount_times_delaytaps;

signal initRam100    : std_logic;
signal ram_rst100 : std_logic;

-- Clock period definitions
constant clk100_period : time := 10 ns;

constant instno : integer := 0;
constant channo : integer := 0;
constant tapno  : integer := 0;

constant squarePdInSamples : integer := 90;

BEGIN

i_instrument_effects: instrument_effects Port Map(    
    clk100         => clk100,
    Z00_ADDR       => Z00_ADDR,
    Z00_INSTFX_IN  => Z00_INSTFX_IN,
    OUTSAMPLEF_DI  => OUTSAMPLEF_DI,
    OUTSAMPLEF_WREN => OUTSAMPLEF_WREN,
    
    -- parameters for ALLPASS can be set for REVERBDELAYPHASERFLANGER
    FB_GAIN       => FB_GAIN,
    COLOR_GAIN    => COLOR_GAIN,
    FORWARD_GAIN  => FORWARD_GAIN,
    INPUT_GAIN    => INPUT_GAIN,
    DELAY_SAMPLES  => DELAY_SAMPLES,
    
    INST_SHIFT   => INST_SHIFT,
    
    initRam100      => initRam100,
    ram_rst100   => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
    
i_ram_active_rst: ram_active_rst port map(
    clksRdy            => clksRdy,
    clk100             => clk100,
    ram_rst100         => ram_rst100,
    initializeRam_out  => initRam100
    );

i_clocks: clocks port map(
    clksRdy   => clksRdy,
    clk100    => clk100,
    clk200    => clk200,
    GPIF_CLK  => GPIF_CLK
    );
    
       
-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

param_sendproc: process
begin
wait;
end process;


ie_testproc: process(clk100)
begin
if rising_edge(clk100) then

-- wait for sdram circuitry to fill in buffer
if initRam100 = '0' then
    ZN1_ADDR <= ZN1_ADDR + 1;
    Z00_ADDR <= ZN1_ADDR;
    if ZN1_ADDR = 0 then
        square <= square + 1;
        if square < squarePdInSamples / 2 then
            Z00_INSTFX_IN <= to_signed(-2**22, STD_FLOWWIDTH);
        else
            Z00_INSTFX_IN <= to_signed(2**22, STD_FLOWWIDTH);
        end if;
        
        if square = squarePdInSamples then
            square <= 0;
        end if;
    else
        Z00_INSTFX_IN <= to_signed(0, STD_FLOWWIDTH);
    end if;
end if;
end if;
end process;

END;