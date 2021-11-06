----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------

        
-- THIS PIPELINE:
-- note volume (fixed, from memory)
-- note volume (from env*lfo)
-- Filter
-- panning
-- summing

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

entity envelopes is
    
Port ( 
    clk100     : in STD_LOGIC;

    MEM_WRADDR    : in STD_LOGIC_VECTOR (RAMADDR_WIDTH-1 downto 0)  := (others=>'0');            
    MEM_IN        : in STD_LOGIC_VECTOR (17 downto 0);   
    ZN12_ADDR     : in unsigned (RAMADDR_WIDTH-1 downto 0)  := (others=>'0'); 
    VOICE_ENVVAL_WREN   : in std_logic;
    VOICE_ENV_DRAW : in instcount_by_envspervoice_by_drawslog2;
    
    -- midpoint needs to be doubled
    UNISON_MIDPOINT  : in instcount_by_ramwidth18;
    UNISON_ENDPOINT  : in instcount_by_ramwidth18;
    UNISON_VOICES_LOG2   : in instcount_by_integer;
    
    Z01_ENV_OUT : out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    Z00_ENV_IN  : in  sfixed(1 downto -std_flowwidth + 2);
    
    ZN6_OS      : in oneshotspervoice_by_ramwidth18s;
    ZN6_COMPUTED_ENVELOPE : in inputcount_by_ramwidth18s;

    ram_rst100     : in std_logic;
    OUTSAMPLEF_ALMOSTFULL: in std_logic;
    initRam100      : in std_logic
    );
           
end envelopes;

architecture Behavioral of envelopes is

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

component bezier is
Port (
    clk100       : in STD_LOGIC;
    ZN5_Phase    : in std_logic_vector(STD_FLOWWIDTH - 1 downto 0);
        
    ZN3_STARTPOINT: in sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
    ZN3_ENDPOINT: in sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
    -- midpoint needs to be doubled
    ZN3_MIDPOINT: in sfixed(2 downto -RAM_WIDTH18 + 3) := (others=>'0');
    
    Z00_BEZIER_OUT    : out std_logic_vector(ram_width18 - 1 downto 0);
    
    initRam100      : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

    
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
    
attribute mark_debug : string;

signal ENV_ALPHA : integer := 4;

signal ZN4_ADDR     : unsigned (RAMADDR_WIDTH-1 downto 0)  := (others=>'0'); 
signal ZN3_ADDR     : unsigned (RAMADDR_WIDTH-1 downto 0)  := (others=>'0'); 
    
signal RAM_WE      : STD_LOGIC_VECTOR (1 downto 0) := "11";
signal RAM_REGCE   : std_logic := '0';
signal RAM_RDEN    : STD_LOGIC := '0';

signal ZN5_ENV0_ZN4_ENV1_ZN3_ENV2_ZN2_ENV3  : STD_LOGIC_VECTOR (RAM_WIDTH18-1 downto 0) := (others => '0');
signal ZN5_ENV0_ZN4_ENV1_ZN3_ENV2_ZN2_ENV3_LPF  : sfixed(1 downto -ram_width18 + 2) := (others => '0');
attribute mark_debug of ZN5_ENV0_ZN4_ENV1_ZN3_ENV2_ZN2_ENV3: signal is "true";

signal ZN11_ADDR     : unsigned (RAMADDR_WIDTH-1 downto 0)  := (others=>'0'); 
signal ZN10_ADDR     : unsigned (RAMADDR_WIDTH-1 downto 0)  := (others=>'0'); 
signal ZN9_ADDR     : unsigned (RAMADDR_WIDTH-1 downto 0)  := (others=>'0'); 
signal ZN8_ADDR: unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN11_ADDR_ufixed: ufixed(1 downto -STD_FLOWWIDTH +2) := (others=>'0');
signal ZN7_ADDR: unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN6_ADDR: unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN5_ADDR: unsigned(RAMADDR_WIDTH -1 downto 0) := (others=>'0');

signal ZN11_UNISON_SHIFT : integer := 0;

signal ZN4_ENV_MOD : sfixed(1 downto -ram_width18 + 2) := (others=>'0');
signal ZN4_ENV_MOD_probe  : STD_LOGIC_VECTOR (RAM_WIDTH18-1 downto 0) := (others => '0');
signal Z00_MOD_ACCUM : sfixed(1 downto -ram_width18 + 2) := (others=>'0');
    
signal ZN12_currinst     : integer range 0 to instcount -1 := 0;
signal ZN10_currinst     : integer range 0 to instcount -1 := 0;
signal ZN9_currinst      : integer range 0 to instcount -1 := 0;
signal ZN8_currinst      : integer range 0 to instcount -1 := 0;
signal ZN6_currinst      : integer range 0 to instcount -1 := 0;
signal ZN5_currinst      : integer range 0 to instcount -1 := 0;
signal ZN4_currinst      : integer range 0 to instcount -1 := 0;
signal ZN3_currinst      : integer range 0 to instcount -1 := 0;
signal ZN2_currinst      : integer range 0 to instcount -1 := 0;
signal ZN1_currinst      : integer range 0 to instcount -1 := 0;

signal ZN5_ENV_DRAW  : unsigned(drawslog2-1 downto 0) := (others=>'0');

signal Z00_timeDiv : integer := 0;
signal Z01_timeDiv : integer := 0;
signal Z02_timeDiv : integer := 0;

signal ZN5_OS: oneshotspervoice_by_ramwidth18s    := (others=>(others=>'0'));
signal ZN5_COMPUTED_ENVELOPE  : inputcount_by_ramwidth18s := (others=>(others=>'0'));

signal ZN6_os_probe  : signed (RAM_WIDTH18-1 downto 0) := (others => '0');
attribute mark_debug of ZN6_os_probe: signal is "true";
        
signal ZN8_STARTPOINT: sfixed(1 downto -RAM_WIDTH18 + 2) := to_sfixed(1, 1, -RAM_WIDTH18 + 2);
signal ZN8_ENDPOINT  : sfixed(1 downto -RAM_WIDTH18 + 2) := to_sfixed(0, 1, -RAM_WIDTH18 + 2);
signal ZN8_MIDPOINT  : sfixed(1 downto -RAM_WIDTH18 + 2) := to_sfixed(0, 1, -RAM_WIDTH18 + 2);
signal ZN10_UNISON_PHASE  : std_logic_vector(STD_FLOWWIDTH - 1 downto 0) := (others=>'0');
signal ZN5_UNISON_MULT  : std_logic_vector(RAM_WIDTH18 - 1 downto 0) := (others=>'0');
signal ZN4_UNISON_MULT  : sfixed(1 downto -RAM_WIDTH18 + 2) := to_sfixed(0, 1, -RAM_WIDTH18 + 2);

signal ZN12_ADDR_long : unsigned (STD_FLOWWIDTH-1 downto 0)  := (others=>'0'); 
   
signal FINAL_VOICE_IN_UNISON : ufixed(ZN5 downto ZN9) := (others=>'0');
--attribute mark_debug of ZN6_os_probe: signal is "true";

--attribute keep : string;  
--attribute keep of Z00_ENV_IN: signal is "true";  

begin
Z00_timeDiv <= to_integer(ZN4_ADDR(1 downto 0));
ZN6_os_probe   <= ZN6_OS(0);
ZN4_ENV_MOD_probe <= to_slv(ZN4_ENV_MOD);
ZN12_ADDR_long <= ZN12_ADDR(RAMADDR_WIDTH - instcountlog2 -1 downto 0) & "00000000000000000";

-- the pipeline:
-- 0: voicenote volume read                                     | ADDR_ZN4     = Z00_ADDR - 7
-- 1: multiply Z00_ENV_IN by note volume, premult of ENV*Z06_COMPUTED_ENVELOPE | currinst  = ADDR_ZN4        * BEGIN ZN1 HERE
-- 2: multiply post_volume by ENV*Z06_COMPUTED_ENVELOPE                        | POSTOSCVOICEVOL_ADDR= currinst     * PROPOGATE ZN1

-- per-voicenote volume. tie this one to the key velocity if desired
i_VOICEVOLS0_ram: ram_controller_18k_18 
port map (
    DO         => ZN5_ENV0_ZN4_ENV1_ZN3_ENV2_ZN2_ENV3,
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(ZN6_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => VOICE_ENVVAL_WREN);
    
    
i_shiftLPF: shiftLPF port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => ZN7_ADDR, 
    Z00_PARAM_IN  => sfixed(ZN5_ENV0_ZN4_ENV1_ZN3_ENV2_ZN2_ENV3), 
    Z01_SHIFT_IN  => ENV_ALPHA, 
    Z00_PARAM_OUT => ZN5_ENV0_ZN4_ENV1_ZN3_ENV2_ZN2_ENV3_LPF, 
    
    initRam100      => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
        

i_bezier: bezier Port map(
    clk100       => clk100, 
    ZN5_Phase    => ZN10_UNISON_PHASE,
        
    ZN3_STARTPOINT=> ZN8_STARTPOINT,
    ZN3_ENDPOINT  => ZN8_ENDPOINT,
    -- midpoint needs to be doubled
    ZN3_MIDPOINT  => ZN8_MIDPOINT,
    
    Z00_BEZIER_OUT => ZN5_UNISON_MULT,
    
    initRam100       => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
        
RAM_RDEN <= not OUTSAMPLEF_ALMOSTFULL;
ZN12_currinst <= to_integer(ZN12_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
ZN10_currinst <= to_integer(ZN10_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
ZN9_currinst <= to_integer(ZN9_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
ZN8_currinst <= to_integer(ZN8_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
ZN6_currinst <= to_integer(ZN6_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));

-- process the volume effects:
-- note volume, env volume, trem volume, channel volume
OSCVOICEVOL_fx: process(clk100)
begin
if rising_edge(clk100) then  
    if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
        Z01_timeDiv <= Z00_timeDiv;
        Z02_timeDiv <= Z01_timeDiv;
        
        ZN11_ADDR <= ZN12_ADDR;
        ZN10_ADDR <= ZN11_ADDR;
        ZN9_ADDR <= ZN10_ADDR;
        ZN8_ADDR <= ZN9_ADDR;
        ZN7_ADDR <= ZN8_ADDR;
        ZN6_ADDR <= ZN7_ADDR;
        ZN5_ADDR <= ZN6_ADDR;
        ZN4_ADDR <= ZN5_ADDR;
        ZN3_ADDR <= ZN4_ADDR;
        
        -- ZN8 is the phase within this instrument
        -- add 1 if Z12 addr is odd and unison is not 0
        if ZN12_ADDR_long(17) = '1' and UNISON_VOICES_LOG2(ZN12_currInst) /= 0 then
            ZN11_ADDR_ufixed <= ufixed(ZN12_ADDR_long + "100000000000000000");
        else
            ZN11_ADDR_ufixed <= ufixed(ZN12_ADDR_long);
        end if;
        
        ZN5_currinst <= ZN6_currinst;
        ZN4_currinst <= ZN5_currinst;
        ZN3_currinst <= ZN4_currinst;
        ZN2_currinst <= ZN3_currinst;
        ZN1_currinst <= ZN2_currinst;
        
        FINAL_VOICE_IN_UNISON <= (FINAL_VOICE_IN_UNISON(ZN6 downto ZN9) & '0');
        
        ZN11_UNISON_SHIFT <= (RAMADDR_WIDTH - instcountlog2 - UNISON_VOICES_LOG2(ZN12_currInst) - 2); -- subtract 2 because voices are every 4
        ZN10_UNISON_PHASE <= to_slv(ZN11_ADDR_ufixed sla ZN11_UNISON_SHIFT); -- shift phase within instrument left to accomodate unison voices
        -- if the new phase is 0, but addr is odd, and unison is non-zero, silence this voice
        if unsigned(ZN10_UNISON_PHASE) = 0 and ZN10_ADDR(0) = '1' and UNISON_VOICES_LOG2(ZN10_currInst) /= 0 then
            FINAL_VOICE_IN_UNISON(ZN9) <= '1';
        end if; 
        
        ZN8_MIDPOINT <= sfixed(UNISON_MIDPOINT(ZN6_currInst));
        ZN8_ENDPOINT <= sfixed(UNISON_ENDPOINT(ZN6_currInst));
        -- its timediv Z02 because ??
        ZN5_ENV_DRAW <= VOICE_ENV_DRAW(ZN6_currinst,Z02_timeDiv);
        
        -- usually, draw env mod from ZCD memory
        ZN4_ENV_MOD  <= sfixed(CHOOSEMOD3(ZN5_ENV_DRAW, signed(to_slv(ZN5_ENV0_ZN4_ENV1_ZN3_ENV2_ZN2_ENV3_LPF)), ZN5_OS, ZN5_COMPUTED_ENVELOPE));
        -- usually, multiply Z00_MOD_ACCUM by previous ENV_READ
        Z00_MOD_ACCUM <= resize(Z00_MOD_ACCUM * ZN4_ENV_MOD, Z00_MOD_ACCUM, fixed_wrap, fixed_truncate);
        
        if FINAL_VOICE_IN_UNISON(ZN5) = '0' then 
            ZN4_UNISON_MULT <= sfixed(ZN5_UNISON_MULT);
        else
            ZN4_UNISON_MULT <= (others=>'0');
        end if;
        
        -- when Z00_timeDiv is 0, reset Z00_MOD_ACCUM to the first modulator times unison amp, and send the output
        if Z00_timeDiv = 0 then
            Z01_ENV_OUT    <= resize(Z00_MOD_ACCUM *  Z00_ENV_IN, 1 , -std_flowwidth + 2, fixed_wrap, fixed_truncate);
            Z00_MOD_ACCUM  <= resize(ZN4_ENV_MOD   * ZN4_UNISON_MULT, Z00_MOD_ACCUM, fixed_wrap, fixed_truncate);
        -- store mods once per cycle
        elsif  Z00_timeDiv = 2 then
            ZN5_OS <= ZN6_OS;
            ZN5_COMPUTED_ENVELOPE  <= ZN6_COMPUTED_ENVELOPE;
        end if;
                
    end if;
end if;
end process;
end Behavioral;