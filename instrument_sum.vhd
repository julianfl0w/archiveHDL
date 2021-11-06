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

entity instrument_sum is
Port ( 
    clk100         : in STD_LOGIC;
    Z00_IN_ADDR    : in unsigned (RAMADDR_WIDTH-1 downto 0);
    Z00_INSTSUM_IN : in sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    ZN7_ABS_ADDR   : in unsigned (RAMADDR_WIDTH-1 downto 0);
    Z00_INSTSUM_OUT: out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    
    VOICE_SHIFT    : in instcount_by_integer;
        
    INSTVOL_VAL  : in instcount_by_instmods_by_ramwidth18;
        
    initRam100      : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
           
end instrument_sum;

architecture Behavioral of instrument_sum is

type INSTSUMTYPE is array (0 to instcount-1) of sfixed(1 + instcountlog2 downto -STD_FLOWWIDTH + 2);
signal Z01_runningSum  : INSTSUMTYPE := (others=>(others=>'0'));
signal ZN2_runningSum_ABS  : sfixed(1 + instcountlog2 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal ZN1_INST_POSTVOL: sfixed(1 + instcountlog2 downto -STD_FLOWWIDTH + 2) := (others=>'0');

signal ZN7_currinst_ABS : integer range 0 to instcount-1 := 0;
signal ZN6_currinst_ABS : integer range 0 to instcount-1 := 0;
signal ZN5_currinst_ABS : integer range 0 to instcount-1 := 0;
signal ZN4_currinst_ABS : integer range 0 to instcount-1 := 0;
signal ZN3_currinst_ABS : integer range 0 to instcount-1 := 0;
signal ZN2_currinst_ABS : integer range 0 to instcount-1 := 0;

signal ZN1_currinst : integer range 0 to instcount-1 := 0;
signal Z00_currinst : integer range 0 to instcount-1 := 0;
    
signal Z00_timeDiv   : integer range 0 to time_Divisions-1 := 0;
signal ZN7_remainder_ABS : integer := 0;
signal ZN6_remainder_ABS : integer := 0;
signal ZN5_remainder_ABS : integer := 0;
signal ZN4_remainder_ABS : integer := 0;
signal ZN3_remainder_ABS : integer := 0;
signal ZN2_remainder_ABS : integer := 0;
signal ZN1_remainder_ABS : integer := 0;
signal Z00_remainder     : integer := 0;

signal ZN6_INSTMOD_0 : sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
signal ZN6_INSTMOD_1 : sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
signal ZN5_INSTMOD_T : sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
signal ZN5_INSTMOD_T_LAST : sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
signal ZN2_INSTMOD_T_LPF : sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
signal Z01_SHIFT_IN  : integer := 4;

type INSTMOD_LAST_TYPE is array (0 to instcount-1) of sfixed(1 downto -RAM_WIDTH18 + 2);
signal INSTMOD_T_LAST : INSTMOD_LAST_TYPE := (others=>(others=>'0'));

component shiftLPFmath is
Port ( 
    clk100       : in STD_LOGIC;
    
    Z00_PARAM_THIS   : in sfixed;
    Z00_PARAM_LAST   : in sfixed;
    Z01_SHIFT_IN     : in integer;
    Z03_PARAM_OUT    : out sfixed := (others=>'0');
    
    initRam100      : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

begin
Z00_currinst <= to_integer(Z00_IN_ADDR(RAMADDR_WIDTH -1 downto RAMADDR_WIDTH - instcountlog2));
Z00_timeDiv  <= to_integer(Z00_IN_ADDR(instcountlog2 -1 downto 0));
Z00_remainder<= to_integer(Z00_IN_ADDR(RAMADDR_WIDTH - instcountlog2 -1 downto 0));
ZN7_remainder_ABS<= to_integer(ZN7_ABS_ADDR(RAMADDR_WIDTH - instcountlog2 -1 downto 0));
ZN7_currinst_ABS <= to_integer(ZN7_ABS_ADDR(RAMADDR_WIDTH -1 downto RAMADDR_WIDTH - instcountlog2));


shiftLPFmath_i: shiftLPFmath port map( 
    clk100       => clk100,
    
    Z00_PARAM_THIS  => ZN5_INSTMOD_T,
    Z00_PARAM_LAST  => ZN5_INSTMOD_T_LAST,
    Z01_SHIFT_IN    => Z01_SHIFT_IN,
    Z03_PARAM_OUT   => ZN2_INSTMOD_T_LPF,
    
    initRam100      => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
    
    
sum_proc: process(clk100)
begin
if rising_edge(clk100) then  
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    
    ZN6_currinst_ABS <= ZN7_currinst_ABS;       
    ZN5_currinst_ABS <= ZN6_currinst_ABS;       
    ZN4_currinst_ABS <= ZN5_currinst_ABS;       
    ZN3_currinst_ABS <= ZN4_currinst_ABS;                                   
    ZN2_currinst_ABS <= ZN3_currinst_ABS;
                       
    ZN6_remainder_ABS <= ZN7_remainder_ABS;
    ZN5_remainder_ABS <= ZN6_remainder_ABS;
    ZN4_remainder_ABS <= ZN5_remainder_ABS;
    ZN3_remainder_ABS <= ZN4_remainder_ABS;
    ZN2_remainder_ABS <= ZN3_remainder_ABS;
    ZN1_remainder_ABS <= ZN2_remainder_ABS;
                      
    ZN5_INSTMOD_T_LAST <= INSTMOD_T_LAST(ZN6_currinst_ABS);
                      
    -- reset runningsum once a cycle
    if Z00_remainder = 0 then
        Z01_runningSum(Z00_currinst) <= resize(Z00_INSTSUM_IN, Z01_runningSum(0), fixed_wrap, fixed_truncate);
    -- usually, add input to runningsum
    elsif Z00_timeDiv = 0 then
        Z01_runningSum(Z00_currinst) <= resize(Z01_runningSum(Z00_currinst) + Z00_INSTSUM_IN, Z01_runningSum(0), fixed_wrap, fixed_truncate);
    end if;
    if ZN3_remainder_abs = 0 then 
        ZN2_runningSum_ABS <= Z01_runningSum(ZN3_currinst_ABS);
    end if;
                       
    -- instmod 0 can only be fixed
    ZN6_INSTMOD_0 <= sfixed(INSTVOL_VAL(ZN7_currinst_ABS,0));
    -- instmod 1 can be any of the global signals. use M1 because sum follows addition cycle
    ZN6_INSTMOD_1 <= sfixed(INSTVOL_VAL(ZN7_currinst_ABS,1));
    ZN5_INSTMOD_T  <= resize(ZN6_INSTMOD_0 * ZN6_INSTMOD_1, ZN5_INSTMOD_T, fixed_wrap, fixed_truncate);

    
    -- output inst sum once a cycle
    if ZN2_remainder_ABS = 0 then
        ZN1_INST_POSTVOL <= resize(ZN2_runningSum_ABS * ZN2_INSTMOD_T_LPF, ZN1_INST_POSTVOL, fixed_saturate, fixed_truncate);
        INSTMOD_T_LAST(ZN2_currinst_ABS) <= ZN2_INSTMOD_T_LPF;
    elsif ZN1_remainder_ABS = 0 then
        --Z00_INSTSUM_OUT  <= resize(ZN1_INST_POSTVOL sra VOICE_SHIFT(ZN1_currInst), Z00_INSTSUM_IN, fixed_saturate, fixed_truncate);
        Z00_INSTSUM_OUT  <= resize(ZN1_INST_POSTVOL, Z00_INSTSUM_IN, fixed_saturate, fixed_truncate);
    end if;
    
    
end if;
end if;
end process;
end Behavioral;