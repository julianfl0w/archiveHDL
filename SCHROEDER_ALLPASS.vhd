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

entity SCHROEDER_ALLPASS is
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
           
end SCHROEDER_ALLPASS;

architecture Behavioral of SCHROEDER_ALLPASS is

component ram_controller_18k_18 is
Port ( 
    DO             : out STD_LOGIC_VECTOR (RAM_WIDTH18-1 downto 0);
    DI             : in  STD_LOGIC_VECTOR (RAM_WIDTH18-1 downto 0);
    RDADDR         : in  STD_LOGIC_VECTOR (RAMADDR_WIDTH-1 downto 0);
    RDCLK          : in  STD_LOGIC;
    RDEN           : in  STD_LOGIC;
    REGCE          : in  STD_LOGIC;
    RST            : in  STD_LOGIC;
    WE             : in  STD_LOGIC_VECTOR (1 downto 0);
    WRADDR         : in  STD_LOGIC_VECTOR (RAMADDR_WIDTH-1 downto 0);
    WRCLK          : in  STD_LOGIC;
    WREN           : in  STD_LOGIC);
end component;

component shiftLPF is
Port ( 
    clk100       : in STD_LOGIC;

    ZN2_ADDR_IN    : in unsigned (RAMADDR_WIDTH -1 downto 0); 
    Z00_PARAM_IN   : in sfixed(1 downto -ram_width18 + 2);
    Z01_SHIFT_IN   : in integer;
    Z00_PARAM_OUT  : out sfixed(1 downto -ram_width18 + 2) := (others=>'0');
    
    initRam100     : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

component linear_interp is
Port ( 
    Z00_A : in sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
    Z00_B : in sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
    clk100       : in STD_LOGIC;
    Z00_PHASE_in : in  sfixed;
    Z03_Interp_Out : out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;


signal ZN8_currInst    : integer range 0 to instcount -1 := 0;
signal ZN7_currInst    : integer range 0 to instcount -1 := 0;
signal ZN6_currInst    : integer range 0 to instcount -1 := 0;
signal ZN5_currInst    : integer range 0 to instcount -1 := 0;
signal ZN4_currInst    : integer range 0 to instcount -1 := 0;
signal ZN3_currInst    : integer range 0 to instcount -1 := 0;
signal ZN2_currInst    : integer range 0 to instcount -1 := 0;
signal ZN1_currInst    : integer range 0 to instcount -1 := 0;
signal Z00_currInst    : integer range 0 to instcount -1 := 0;
signal Z01_currInst    : integer range 0 to instcount -1 := 0;

signal ZN8_currTap  : integer := 0;
signal ZN7_currTap  : integer := 0;
signal ZN6_currTap  : integer := 0;
signal ZN5_currTap  : integer := 0;
signal ZN4_currTap  : integer := 0;
signal ZN3_currTap  : integer := 0;
signal ZN2_currTap  : integer := 0;
signal ZN1_currTap  : integer := 0;
signal Z00_currTap  : integer := 0;
signal Z01_currTap  : integer := 0;
signal Z02_currTap  : integer := 0;
signal Z03_currTap  : integer := 0;

signal Z00_timeDiv  : integer range 0 to time_divisions -1 := 0;
signal Z01_timeDiv  : integer range 0 to time_divisions -1 := 0;
signal Z02_timeDiv  : integer range 0 to time_divisions -1 := 0;
signal Z03_timeDiv  : integer range 0 to time_divisions -1 := 0;

signal ZN7_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN6_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN5_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN4_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN3_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN2_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN1_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal Z00_ADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');

attribute mark_debug : string;
type MEMARRAY is array (0 to instcount - 1, 0 to tapsperinst - 1) of STD_LOGIC_VECTOR(RAM_WIDTH18-1 downto 0);
signal ZN5_ZN4_DELAY_OUT  : MEMARRAY := (others=>(others=>(others=>'0')));
signal ZN4_ZN3_DELAY_SIG  : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal Z01_DELAY_SIG  : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z01_DELAY_SIG_slv  : STD_LOGIC_VECTOR(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
attribute mark_debug of Z01_DELAY_SIG_slv: signal is "true";
signal Z02_TO_DELAY   : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal Z02_TO_DELAY_slv  : STD_LOGIC_VECTOR(RAM_WIDTH18-1 downto 0) := (others=>'0');
attribute mark_debug of Z02_TO_DELAY_slv: signal is "true";

signal ZN1_FBGAIN      : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal Z00_FBGAIN      : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal Z00_FORWARDGAIN : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal Z01_FORWARDGAIN : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal Z01_COLORGAIN   : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal Z02_INPUT_GAIN  : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');

signal Z01_ALLPASS_IN   : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z01_FBPOSTGAIN   : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z02_RTPOSTGAIN   : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z02_POSTCOLORGAIN: sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z03_ALLPASS_OUT  : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z03_schroeder_IN : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z04_ALLPASS_OUT  : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');

signal Z02_RTPOSTGAIN_slv  : std_logic_vector(std_flowwidth -1 downto 0);
signal Z00_FORWARDGAIN_slv : std_logic_vector(RAM_WIDTH18 -1 downto 0);
signal Z03_ALLPASS_OUT_slv : std_logic_vector(std_flowwidth -1 downto 0);
signal Z04_ALLPASS_OUT_slv : std_logic_vector(std_flowwidth -1 downto 0);
attribute mark_debug of Z02_RTPOSTGAIN_slv : signal is "true";
attribute mark_debug of Z00_FORWARDGAIN_slv: signal is "true";
attribute mark_debug of Z03_ALLPASS_OUT_slv : signal is "true";
attribute mark_debug of Z04_ALLPASS_OUT_slv: signal is "true";

signal RAM_WE      : STD_LOGIC_VECTOR (1 downto 0) := "11";
signal RAM_REGCE   : std_logic := '0';
signal RAM_RDEN    : STD_LOGIC := '0';

type RAM_EN is array (0 to instcount-1, 0 to tapsperinst-1) of std_logic;
signal ZN6_ZN5_RAM_RDEN    : RAM_EN := (others=>(others=>'0'));
signal Z02_RAM_WREN    : RAM_EN := (others=>(others=>'0'));

signal ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');
signal ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT_LPF : sfixed(1 downto -ram_width18+2) := (others=>'0');

signal ZN6_ZN5_RDADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN8_WRADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal Z02_WRADDR : unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');

signal GAIN_ALPHA  : integer := 3; 
signal DELAY_ALPHA : integer := 9; 

signal ZN3_LOW   : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal ZN2_LOW   : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal ZN2_HIGH  : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal ZN2_LOW_slv   : STD_LOGIC_VECTOR(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal ZN2_HIGH_slv  : STD_LOGIC_VECTOR(RAM_WIDTH18-1 downto 0) := (others=>'0');

type DELAY_SAMPLES_TYPE is array (0 to instcount-1, 0 to tapsperinst-1) of unsigned(RAM_WIDTH18 -1 downto 0);
signal DELAY_SAMPLES_CURR : DELAY_SAMPLES_TYPE := (others=>(others=>(others=>'0')));
signal ZN7_DELAY_SAMPLES_CURR_MAIN : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN3_DELAY_SAMPLES_RESIDUAL : unsigned(RAM_WIDTH18 - RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN2_DELAY_SAMPLES      : signed(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal ZN1_DELAY_SAMPLES      : signed(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal ZN1_DELAY_SAMPLES_LPF  : sfixed(1 downto -RAM_WIDTH18 + 2)  := (others=>'0');
signal ZN2_DELAY_SAMPLES_DRAW : unsigned(drawslog2-1 downto 0) := (others=>'0');
    
signal ZN2_PHASE_RESIDUAL : sfixed(0 downto - RAM_WIDTH18 + RAMADDR_WIDTH) := (others=>'0');

begin

Z02_RTPOSTGAIN_slv  <= to_slv(Z02_RTPOSTGAIN);
Z00_FORWARDGAIN_slv <= to_slv(Z00_FORWARDGAIN);
Z03_ALLPASS_OUT_slv <= to_slv(Z03_ALLPASS_OUT);
Z04_ALLPASS_OUT_slv <= to_slv(Z04_ALLPASS_OUT);

Z01_DELAY_SIG_slv <= to_slv(Z01_DELAY_SIG);
ZN2_LOW_slv       <= to_slv(ZN2_LOW);
ZN2_HIGH_slv      <= to_slv(ZN2_HIGH);
Z02_TO_DELAY_slv  <= to_slv(Z02_TO_DELAY);

RAM_RDEN <= not OUTSAMPLEF_ALMOSTFULL;
Z00_timeDiv  <= to_integer(ZN4_ADDR(1 downto 0));
ZN8_currInst <= to_integer(ZN8_ADDR(RAMADDR_WIDTH -1  downto RAMADDR_WIDTH - instcountlog2));
ZN8_currTap  <= to_integer(ZN8_ADDR(RAMADDR_WIDTH - instcountlog2 - 1 downto 2));

i_gain_ram: ram_controller_18k_18 
port map (
    DO         => ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT,
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(ZN3_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM_WE,
    WRADDR     => std_logic_vector(MEM_WRADDR),
    WRCLK      => clk100,
    WREN       => GAIN_WREN
    );

i_gain_lpf: shiftLPF port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => ZN4_ADDR, 
    Z00_PARAM_IN  => sfixed(ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT), 
    Z01_SHIFT_IN  => GAIN_ALPHA, 
    Z00_PARAM_OUT => ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT_LPF, 
    
    initRam100      => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
   
i_delay_lpf: shiftLPF port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => ZN4_ADDR, 
    Z00_PARAM_IN  => sfixed(ZN1_DELAY_SAMPLES), 
    Z01_SHIFT_IN  => DELAY_ALPHA, 
    Z00_PARAM_OUT => ZN1_DELAY_SAMPLES_LPF, 
    
    initRam100      => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
             
i_linear_interp : linear_interp Port Map ( 
    Z00_A => ZN2_HIGH,
    Z00_B => ZN2_LOW, -- SWITCHED!
    clk100         => clk100,
    Z00_PHASE_in   => ZN2_PHASE_RESIDUAL,
    Z03_Interp_Out => Z01_DELAY_SIG,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );

-- make a memory for each channel
memloop_out:
for inst in 0 to instcount -1 generate
taploop:
for tap  in 0 to tapsperinst -1 generate
-- delay memory
i_delay_ram: ram_controller_18k_18 
port map (
    DO         => ZN5_ZN4_DELAY_OUT(inst, tap),
    DI         => to_slv(Z02_TO_DELAY),
    RDADDR     => std_logic_vector(ZN6_ZN5_RDADDR),
    RDCLK      => clk100,
    RDEN       => ZN6_ZN5_RAM_RDEN(inst, tap),
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM_WE,
    WRADDR     => std_logic_vector(Z02_WRADDR),
    WRCLK      => clk100,
    WREN       => Z02_RAM_WREN(inst, tap));
end generate;
end generate;

sum_proc: process(clk100)
begin    

if rising_edge(clk100) then  
ZN6_ZN5_RAM_RDEN <= (others=>(others=>'0'));
Z02_RAM_WREN <= (others=>(others=>'0'));
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then

    -- propagations
    
    Z01_timeDiv  <= Z00_timeDiv;
    Z02_timeDiv  <= Z01_timeDiv;
    Z03_timeDiv  <= Z02_timeDiv;
    
    ZN7_currInst <= ZN8_currInst;
    ZN6_currInst <= ZN7_currInst;
    ZN5_currInst <= ZN6_currInst;
    ZN4_currInst <= ZN5_currInst;
    ZN3_currInst <= ZN4_currInst;
    ZN2_currInst <= ZN3_currInst;
    ZN1_currInst <= ZN2_currInst;
    Z00_currInst <= ZN1_currInst;
    Z01_currInst <= Z00_currInst;
    
    ZN7_currTap <= ZN8_currTap;
    ZN6_currTap <= ZN7_currTap;
    ZN5_currTap <= ZN6_currTap;
    ZN4_currTap <= ZN5_currTap;
    ZN3_currTap <= ZN4_currTap;
    ZN2_currTap <= ZN3_currTap;
    ZN1_currTap <= ZN2_currTap;
    Z00_currTap <= ZN1_currTap;
    Z01_currTap <= Z00_currTap;
    Z02_currTap <= Z01_currTap;
    Z03_currTap <= Z02_currTap;
    
    ZN7_ADDR <= ZN8_ADDR;
    ZN6_ADDR <= ZN7_ADDR;
    ZN5_ADDR <= ZN6_ADDR;
    ZN4_ADDR <= ZN5_ADDR;
    ZN3_ADDR <= ZN4_ADDR;
    ZN2_ADDR <= ZN3_ADDR;
    ZN1_ADDR <= ZN2_ADDR;
    Z00_ADDR <= ZN1_ADDR;

    Z00_FBGAIN      <= ZN1_FBGAIN;
    Z01_FORWARDGAIN <= Z00_FORWARDGAIN;
    
    if ZN8_currTap < tapsperinst then
        ZN7_DELAY_SAMPLES_CURR_MAIN <= DELAY_SAMPLES_CURR(ZN8_currInst, ZN8_currTap)(RAM_WIDTH18 -1 downto RAM_WIDTH18-RAMADDR_WIDTH);
    end if;
    
    if Z01_timeDiv = 0 and ZN7_currTap < tapsperinst then
        ZN6_ZN5_RAM_RDEN(ZN7_currInst, ZN7_currTap) <= '1';
        -- subtract 2 so that the read address and rdaddr+1 always preceeds wraddr
        ZN6_ZN5_RDADDR <= ZN8_WRADDR - ZN7_DELAY_SAMPLES_CURR_MAIN - 2;
    end if;
    
    -- the other sample is one higher 
    if Z02_timeDiv = 0 and ZN6_currTap < tapsperinst then
        ZN6_ZN5_RAM_RDEN(ZN6_currInst, ZN6_currTap) <= '1';
        ZN6_ZN5_RDADDR <= ZN6_ZN5_RDADDR + 1;
    end if;
    -- wait for read
    -- Save DELAY out to DELAY_SIG
    if ZN5_currTap < tapsperinst then
        ZN4_ZN3_DELAY_SIG <= sfixed(ZN5_ZN4_DELAY_OUT(ZN5_currInst, ZN5_currTap));
    end if;
        
    if Z00_timeDiv = 0 and ZN4_currTap < tapsperinst then
        -- save the output as low
        ZN3_LOW <= ZN4_ZN3_DELAY_SIG;
        -- read delay samples residual
        ZN3_DELAY_SAMPLES_RESIDUAL <= DELAY_SAMPLES_CURR(ZN4_currInst, ZN4_currTap)(RAM_WIDTH18-RAMADDR_WIDTH -1 downto 0);
    end if;
    -- finally, pass along the high value
    if Z01_timeDiv = 0 and ZN3_currTap < tapsperinst then
        ZN2_LOW  <= ZN3_LOW;
        -- save the output as high
        ZN2_HIGH <= ZN4_ZN3_DELAY_SIG;
        -- save the phase residual 
        ZN2_PHASE_RESIDUAL <= sfixed('0' & ZN3_DELAY_SAMPLES_RESIDUAL);
        -- prepare draw and value
        ZN2_DELAY_SAMPLES_DRAW <= DELAY_SAMPLES_DRAW(ZN3_currInst, ZN3_currTap);
        ZN2_DELAY_SAMPLES      <= signed(DELAY_SAMPLES(ZN3_currInst, ZN3_currTap));
    end if;
    
    
    -- write when time div is 2 and tap count has not been exceeded
    if Z01_timeDiv = 0 and Z01_currTap < tapsperinst then
        Z02_RAM_WREN(Z01_currInst, Z01_currTap) <= '1';
    end if;
    
    -- increase tap address once a cycle
    if signed(ZN7_ADDR) = -2 then
        ZN8_WRADDR <= ZN8_WRADDR + 1;
    end if;
    -- Z02 addr tracks ZN6 addr
    if ZN6_ADDR = 7 then
        Z02_WRADDR <= ZN8_WRADDR;
    end if;
    
    -- chain subsequant allpass units
    -- but read the first from input
    if Z00_timeDiv = 0 then
        if Z00_currTap = 0 then
            Z01_ALLPASS_IN <= Z00_schroeder_IN;
        else
            Z01_ALLPASS_IN <= Z04_ALLPASS_OUT;
        end if;
    end if;
        
    -- determine what the delay sample count is
    if Z02_timeDiv = 0 and ZN2_currTap < tapsperinst then
        ZN1_DELAY_SAMPLES <= CHOOSEMOD3(ZN2_DELAY_SAMPLES_DRAW, ZN2_DELAY_SAMPLES, ZN2_OS, ZN2_COMPUTED_ENVELOPE);
    end if;
    
    -- update for the next cycle
    if Z03_timeDiv = 0 and ZN1_currTap < tapsperinst then
        DELAY_SAMPLES_CURR(ZN1_currInst, ZN1_currTap) <= unsigned(ZN1_DELAY_SAMPLES_LPF);
    end if;

    -- read from memory into registers as is appropriate
    case Z00_timeDiv is
    when 0 =>
        Z01_COLORGAIN   <= ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT_LPF;
    when 1 =>
        Z02_INPUT_GAIN  <= ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT_LPF;
    when 2 =>
        ZN1_FBGAIN      <= ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT_LPF;
    when others =>
        Z00_FORWARDGAIN <= ZN2_FB_ZN1_FWD_Z00_COLOR_Z01_INPUT_LPF;
    end case;
    
    -- the actual math :)
    Z01_FBPOSTGAIN    <= resize(ZN4_ZN3_DELAY_SIG* Z00_FBGAIN,       Z01_FBPOSTGAIN,   fixed_saturate, fixed_truncate);
    Z02_TO_DELAY      <= resize(Z01_FBPOSTGAIN   + Z01_ALLPASS_IN,   Z02_TO_DELAY,     fixed_saturate, fixed_truncate);
    Z02_RTPOSTGAIN    <= resize(Z01_ALLPASS_IN   * Z01_FORWARDGAIN,  Z02_RTPOSTGAIN,   fixed_saturate, fixed_truncate);
    Z02_POSTCOLORGAIN <= resize(Z01_DELAY_SIG    * Z01_COLORGAIN,    Z02_POSTCOLORGAIN,fixed_saturate, fixed_truncate);
    Z03_ALLPASS_OUT   <= resize(Z02_RTPOSTGAIN   + Z02_POSTCOLORGAIN,Z03_ALLPASS_OUT,  fixed_saturate, fixed_truncate);
    Z03_schroeder_IN  <= resize(Z00_schroeder_IN * Z02_INPUT_GAIN,   Z03_schroeder_IN, fixed_saturate, fixed_truncate);
    Z04_ALLPASS_OUT   <= resize(Z03_ALLPASS_OUT  + Z03_schroeder_IN, Z04_ALLPASS_OUT,  fixed_saturate, fixed_truncate);
    
    if Z03_currTap = tapsperinst-1 then
        Z12_schroeder_OUT  <= resize(Z03_ALLPASS_OUT + Z03_schroeder_IN, Z04_ALLPASS_OUT,   fixed_saturate, fixed_truncate);
    end if;
end if;
end if;
end process;
end Behavioral;
