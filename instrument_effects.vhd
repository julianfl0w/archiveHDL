----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
-- This component sums instcount*channelcount total channels (32 total) 
-- channels are valid every 32nd sample, and shall be processed independently

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

entity instrument_effects is
Port ( 
    clk100        : in STD_LOGIC;
    Z00_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
    Z00_INSTSUM_IN : in sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    OUTSAMPLEF_DI   : out signed(i2s_width -1 downto 0) := (others=>'0');
    OUTSAMPLEF_WREN : out std_logic := '0';
    
    -- parameters for ALLPASS can be set for REVERBDELAYPHASERFLANGER
    FB_GAIN         : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    COLOR_GAIN      : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    FORWARD_GAIN    : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    INPUT_GAIN      : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    
    DELAY_SAMPLES   : in instcount_by_channelcount_by_delaytaps_by_ramaddrwidthu;
    
    INST_SHIFT  : in integer range 0 to instcount-1;
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
           
end instrument_effects;

architecture Behavioral of instrument_effects is


component SCHROEDER_ALLPASS is
Port ( 
    clk100          : in STD_LOGIC;
    ZN6_ADDR        : in unsigned (RAMADDR_WIDTH-1 downto 0);
    
    DELAY_SAMPLES   : in instcount_by_channelcount_by_delaytaps_by_ramaddrwidthu;
    FB_GAIN         : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    COLOR_GAIN      : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    FORWARD_GAIN    : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    INPUT_GAIN      : in instcount_by_channelcount_by_delaytaps_by_ramwidth;
    
    Z00_schroeder_IN : in  sfixed(1 downto -STD_FLOWWIDTH + 2);
    Z12_schroeder_OUT: out sfixed(1 downto -STD_FLOWWIDTH + 2);
    
    ram_rst100     : in std_logic;
    initRam100        : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

--component aShift is
--Generic(
--  shiftmin  : natural;
--  shiftmax  : natural
--);
--Port ( 
--   clk100 : in STD_LOGIC;
--   Z00_to_shift : in sfixed;
--   Z00_bitstoshift: in natural;
--   Z01_shifted  : out sfixed
--);
--end component;

type CHANNELSUMTYPE is array (0 to channelscount-1) of sfixed(1 + 4 downto -STD_FLOWWIDTH + 2);
signal Z12_runningSum : CHANNELSUMTYPE := (others=>(others=>'0'));
signal ZN5_ADDR   : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal ZN4_ADDR   : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal ZN3_ADDR   : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal ZN2_ADDR   : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal ZN1_ADDR   : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z01_ADDR   : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z11_ADDR   : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');

signal Z00_remainder: unsigned(RAMADDR_WIDTH - instcountlog2 - channelscountlog2 -1 downto 0);
signal Z11_remainder: unsigned(RAMADDR_WIDTH - instcountlog2 - channelscountlog2 -1 downto 0);

signal Z00_timeDiv  : unsigned(1 downto 0);
signal Z11_currinst : integer range 0 to instcount-1;
signal Z11_currChan : integer range 0 to 1;

signal Z01_INSTFX_IN   : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z03_ALLPASS_OUT : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z04_ALLPASS_OUT : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');

signal ZN2_OUTSAMPLEF_DI  : sfixed(1 downto -i2s_width + 2);
signal ZN1_OUTSAMPLEF_DI  : signed(i2s_width -1  downto 0) := (others=>'0');
    
--signal INST_SHIFT_MOD : integer := STD_FLOWWIDTH - i2s_width;
signal INST_SHIFT_MOD : integer := 0;

begin

--i_ashift: aShift
--Generic map(
--  shiftmin  => std_flowwidth - i2s_width,
--  shiftmax  => std_flowwidth - i2s_width + instcountlog2
--)
--Port map( 
--   clk100      => clk100,
--   Z00_to_shift=> ZN2_OUTSAMPLEF_DI_SIGNED,
--   Z00_bitstoshift => INST_SHIFT_MOD,
--   Z01_shifted => ZN1_OUTSAMPLEF_DI
--   );

i_schroeder_allpass: SCHROEDER_ALLPASS 
Port map ( 
    clk100          => clk100,
    ZN6_ADDR        => ZN5_ADDR,
    
    DELAY_SAMPLES   => DELAY_SAMPLES,
    FB_GAIN         => FB_GAIN,
    COLOR_GAIN      => COLOR_GAIN,
    FORWARD_GAIN    => FORWARD_GAIN,
    INPUT_GAIN      => INPUT_GAIN,
    
    Z00_schroeder_IN  => Z01_INSTFX_IN, -- clk diff: 1
    Z12_schroeder_OUT => Z03_ALLPASS_OUT, 
        
    ram_rst100      => ram_rst100,
    initRam100         => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );

Z00_remainder <= Z00_ADDR(RAMADDR_WIDTH - instcountlog2 - channelscountlog2 -1 downto 0);
Z11_remainder <= Z11_ADDR(RAMADDR_WIDTH - instcountlog2 - channelscountlog2 -1 downto 0);

Z00_timeDiv   <= Z00_ADDR(1 downto 0);
Z11_currinst  <= to_integer(Z11_ADDR(RAMADDR_WIDTH - 1 downto RAMADDR_WIDTH - instcountlog2));
Z11_currChan  <= to_integer(Z11_ADDR(RAMADDR_WIDTH - instcountlog2 - 1 downto RAMADDR_WIDTH - instcountlog2 - 1));

sum_proc: process(clk100)
begin
if rising_edge(clk100) then  
OUTSAMPLEF_WREN  <= '0';
    
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
--    INST_SHIFT_MOD <= INST_SHIFT + STD_FLOWWIDTH - i2s_width;
    ZN5_ADDR     <= Z00_ADDR + 6;
    ZN4_ADDR     <= ZN5_ADDR;
    ZN3_ADDR     <= ZN4_ADDR;
    ZN2_ADDR     <= ZN3_ADDR;
    ZN1_ADDR     <= ZN2_ADDR;
    Z01_ADDR     <= Z00_ADDR;
    Z04_ALLPASS_OUT <= Z03_ALLPASS_OUT;
    Z11_ADDR     <= ZN1_ADDR - 11;
    
    
    Z01_INSTFX_IN <= sfixed(Z00_INSTSUM_IN);
    
    -- run a grand total of TAPCOUNT allpasses, then add the result to the running sum
    -- summing procedure:
    -- either reset channel at beginning of cycle
    if Z11_remainder = 0 then
        if Z11_currinst = 0 then
            Z12_runningSum(Z11_currChan) <= resize(Z03_ALLPASS_OUT, Z12_runningSum(0));
        -- or otherwise increment it
        else
            Z12_runningSum(Z11_currChan) <= resize(Z12_runningSum(Z11_currChan) + Z03_ALLPASS_OUT, Z12_runningSum(Z11_currChan), fixed_wrap, fixed_truncate);
        end if;
    end if;
        
    -- begin output process:
    if ZN3_ADDR < channelscount then  
        ZN2_OUTSAMPLEF_DI  <= resize(Z12_runningSum(to_integer(ZN3_ADDR)) sra INST_SHIFT, ZN2_OUTSAMPLEF_DI);
    end if;
    ZN1_OUTSAMPLEF_DI <= signed(to_slv(ZN2_OUTSAMPLEF_DI));
    
    -- match the channels to the time slots
    if ZN1_ADDR < channelscount then
        OUTSAMPLEF_DI <= ZN1_OUTSAMPLEF_DI;
        OUTSAMPLEF_WREN  <= '1';
    end if;    
end if;
end if;
end process;
end Behavioral;