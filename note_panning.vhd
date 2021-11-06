----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------

        
-- THIS PIPELINE:
-- panning
-- summing

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

entity note_panning is
Port ( 
    clk100        : in STD_LOGIC;
    
    INST_SHIFT   : in integer range 0 to instcount-1;
        
    ZN3_ADDR_ABS  : in unsigned (RAMADDR_WIDTH -1 downto 0);
    ZN2_ADDR   : in unsigned (RAMADDR_WIDTH -1 downto 0);
        
    Z00_PANNING_IN: in  sfixed(1 downto -STD_FLOWWIDTH + 2);
    OUTSAMPLEF_DI   : out signed(i2s_width -1 downto 0) := (others=>'0');
    OUTSAMPLEF_WREN : out std_logic := '0';
    
    ZN2_ONESHOT   : in oneshotspervoice_by_ramwidth18s;
    ZN2_COMPUTED_ENVELOPE   : in inputcount_by_ramwidth18s;
    
    VOICE_PAN_DRAW: in instcount_by_channelcount_by_panmodcount_by_drawslog2;
    VOICE_PAN : in instcount_by_channelcount_by_panmodcount_by_ramwidth18s;
    
    initRam100       : in std_logic;
    ram_rst100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL  : in std_logic
    );
           
end note_panning;

architecture Behavioral of note_panning is



type PANMULTTYPE is array (0 to panmodcount-1) of sfixed(1 downto -RAM_WIDTH18 + 2);
signal ZN1_PAN_MULT   : PANMULTTYPE := (others=>(others=>'0'));
signal Z00_POST_PAN_T : sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0'); 
signal Z00_POST_PAN_T_LPF  : sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');

signal ZN2_ADDR_abs : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN1_ADDR_abs : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');

signal ZN1_ADDR : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal Z00_ADDR : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal Z01_ADDR : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal Z02_ADDR : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal Z02_timeDiv : integer := 0;

signal ZN4_currchan_ABS : integer range 0 to instcount-1 := 0;
signal ZN3_currchan_ABS : integer range 0 to instcount-1 := 0;

signal ZN2_currinst  : integer range 0 to instcount-1 := 0;
signal ZN1_currinst  : integer range 0 to instcount-1 := 0;
signal Z00_currinst  : integer range 0 to instcount-1 := 0;
signal Z01_currinst  : integer range 0 to instcount-1 := 0;
signal Z02_currinst  : integer range 0 to instcount-1 := 0;

signal ZN2_currchan  : integer := 0;
signal ZN1_currchan  : integer := 0;
signal Z00_currchan  : integer := 0;
signal Z01_currchan  : integer := 0;
signal Z02_currchan  : integer := 0;

signal LPF_SHIFT : integer := 4;

signal Z01_channel        : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
type channels_by_stdflowwidth_plus5 is array (0 to channelscount -1) of sfixed(6 downto -STD_FLOWWIDTH + 2);
signal Z02_ALLCHANNELS    : channels_by_stdflowwidth_plus5 := (others=>(others=>'0'));
signal ZN2_PANNING_OUT    : sfixed(6 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal ZN1_PANNING_OUT    : sfixed(6 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal ZN2_INST_SHIFT : integer := 0;

component shiftLPF is
Port ( 
    clk100       : in STD_LOGIC;

    ZN2_ADDR_IN    : in unsigned (RAMADDR_WIDTH -1 downto 0); 
    Z00_PARAM_IN   : in sfixed(1 downto -ram_width18 + 2);
    Z01_SHIFT_IN   : in integer;
    Z00_PARAM_OUT  : out sfixed(1 downto -ram_width18 + 2);
    
    initRam100     : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

begin

ZN2_currchan <= to_integer(ZN2_ADDR(RAMADDR_WIDTH - instcountlog2 - 1 downto 0));
ZN2_currinst <= to_integer(ZN2_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH - instcountlog2));
ZN3_currchan_abs <= to_integer(ZN3_ADDR_abs(RAMADDR_WIDTH - instcount - 1 downto 0));

i_shiftLPF: shiftLPF port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => ZN2_ADDR, 
    Z00_PARAM_IN  => Z00_POST_PAN_T, 
    Z01_SHIFT_IN  => LPF_SHIFT, 
    Z00_PARAM_OUT => Z00_POST_PAN_T_LPF, 
    
    initRam100   => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
        
-- channels contains panning, and all processes after (IE. summing ATM)
-- apply panning
pan_proc: process(clk100)
begin


if rising_edge(clk100) then  
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    
    ZN1_currchan <= ZN2_currchan;
    Z00_currchan <= ZN1_currchan;
    Z01_currchan <= Z00_currchan;
    Z02_currchan <= Z01_currchan;
    
    ZN1_currinst <= ZN2_currinst;
    Z00_currinst <= ZN1_currinst;
    Z01_currinst <= Z00_currinst;
    Z02_currinst <= Z01_currinst;
    
    ZN1_ADDR <= ZN2_ADDR;
    Z00_ADDR <= ZN1_ADDR;
    Z01_ADDR <= Z00_ADDR;
    Z02_ADDR <= Z01_ADDR;
    
    ZN2_ADDR_abs <= ZN3_ADDR_abs;
    ZN1_ADDR_abs <= ZN2_ADDR_abs;
    
    
    panloop:
    for panmod in 0 to panmodcount-1 loop
        -- step 1 : calculate the pan modifiers
        if ZN2_currchan < channelscount then 
            ZN1_PAN_MULT(panmod) <= 
            sfixed(CHOOSEMOD3(VOICE_PAN_DRAW(ZN2_currinst, ZN2_currchan, panmod),
            VOICE_PAN(ZN2_currinst, ZN2_currchan, panmod),
            ZN2_ONESHOT,ZN2_COMPUTED_ENVELOPE));
        end if;
    end loop;
            
    -- step 1 : multiply these together to produce total modifier
    Z00_POST_PAN_T <= resize(ZN1_PAN_MULT(0) * ZN1_PAN_MULT(1), Z00_POST_PAN_T, fixed_wrap, fixed_truncate);
    
    -- step 2 : multiply instvol-modded input signal with pan modifier
    Z01_channel <= resize(Z00_POST_PAN_T_LPF * Z00_PANNING_IN, Z01_channel, fixed_wrap, fixed_truncate);
    
    -- step 3 : add to running sum, resetting every cycle
    channelloop:
    for channel in 0 to channelscount-1 loop
        -- reset on inst 0
        if Z01_ADDR = channel then
            Z02_ALLCHANNELS(channel) <= 
            resize(Z01_channel, Z02_ALLCHANNELS(0), fixed_wrap, fixed_truncate);
        elsif Z01_currChan = channel then
            Z02_ALLCHANNELS(channel) <= 
            resize(Z02_ALLCHANNELS(channel) + Z01_channel, Z02_ALLCHANNELS(0), fixed_wrap, fixed_truncate);
        end if;
    end loop;
    
    -- output process: read from runningsum
    if ZN3_currchan_ABS < channelscount then
        ZN2_PANNING_OUT <= Z02_ALLCHANNELS(ZN3_currchan_ABS);
    end if;
    
    ZN2_INST_SHIFT  <= INST_SHIFT - 1;   
    ZN1_PANNING_OUT <= ZN2_PANNING_OUT sra ZN2_INST_SHIFT; 
    
    OUTSAMPLEF_WREN <= '0';
    if ZN1_ADDR_ABS < channelscount then
        OUTSAMPLEF_DI   <= signed(to_slv(resize(ZN1_PANNING_OUT, 1, -i2s_width + 2))); 
        OUTSAMPLEF_WREN <= '1';
    end if;
end if;
end if;
end process;
end Behavioral;