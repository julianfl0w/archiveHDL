----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- Julian Loiacono 6/2016
--
-- Module Name: oscillators - Behavioral
--
-- Description: Generate an low-volume sine wave, at around 400 Hz
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

entity chowning is
Port ( 
    clk100       : in STD_LOGIC;
    
    ADDR         : in address_type;
    
    MEM_IN       : in std_logic_vector(ram_width18 -1 downto 0);
    MEM_IN25     : in std_logic_vector(STD_FLOWWIDTH -1 downto 0);
    MEM_WRADDR   : in std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    OSC_INCTARGET_RATE_WREN : in std_logic;
    OSC_VOL_WREN     : in std_logic;
    OSC_MODAMP_WREN  : in std_logic_vector(oscpervoice-1 downto 0);
    OSC_DETUNE_WREN  : in std_logic;
    OSC_HARMONICITY_WREN : in std_logic;
    OSC_HARMONICITY_ALPHA_WREN: in std_logic;
    
    OSC_RINGMOD     : in instcount_by_oscpervoice_by_oscpervoice;
    PITCH_SHIFT     : in instcount_by_ramwidth18;
    DETUNE_RATIO    : in instcount_by_2_by_ramwidth18;
    UNISON_VOICES_LOG2   : in instcount_by_integer;
    
    OSC_MODAMP_DRAW  : in instcount_by_oscpervoice_by_oscpervoice_by_drawslog2;
    OSC_INC_DRAW      : in instcount_by_oscpervoice_by_drawslog2;
    OSC_VOL_DRAW      : in instcount_by_oscpervoice_by_drawslog2;
    OSC_DETUNE_DRAW   : in instcount_by_oscpervoice_by_drawslog2;
    PITCH_SHIFT_DRAW  : in instcount_by_drawslog2;
    
    Z01_OS  : in oneshotspervoice_by_ramwidth18s;
    Z01_COMPUTED_ENVELOPE    : in inputcount_by_ramwidth18s;
    
    Z16_OSC_OUT  : out sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
        
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
           
end chowning;

architecture Behavioral of chowning is
component ram_controller_18k_18 is
Port ( 
    DO             : out STD_LOGIC_VECTOR (ram_width18 -1 downto 0);
    DI             : in  STD_LOGIC_VECTOR (ram_width18 -1 downto 0);
    RDADDR         : in  STD_LOGIC_VECTOR (ramaddr_width-1 downto 0);
    RDCLK          : in  STD_LOGIC;
    RDEN           : in  STD_LOGIC;
    REGCE          : in  STD_LOGIC;
    RST            : in  STD_LOGIC;
    WE             : in  STD_LOGIC_VECTOR (1 downto 0);
    WRADDR         : in  STD_LOGIC_VECTOR (ramaddr_width-1 downto 0);
    WRCLK          : in  STD_LOGIC;
    WREN           : in  STD_LOGIC);
end component;

component ram_controller_36k_25 is
Port ( 
    DO             : out STD_LOGIC_VECTOR (24 downto 0);
    DI             : in  STD_LOGIC_VECTOR (24 downto 0);
    RDADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
    RDCLK          : in  STD_LOGIC;
    RDEN           : in  STD_LOGIC;
    REGCE          : in  STD_LOGIC;
    RST            : in  STD_LOGIC;
    WE             : in  STD_LOGIC_VECTOR (3 downto 0);
    WRADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
    WRCLK          : in  STD_LOGIC;
    WREN           : in  STD_LOGIC);
end component;
   
component sine_lookup is
Port ( 
    clk100       : in STD_LOGIC;
    Z00_PHASE_in : in  signed(std_flowwidth - 1 downto 0);
    Z06_SINE_out : out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;
   
component rationalize is
Port ( 
    clk100       : in STD_LOGIC;
    
    ZN3_ADDR     : in unsigned (RAMADDR_WIDTH -1 downto 0); -- Z01
    Z00_IRRATIONAL: in signed (ram_width18 -1 downto 0); -- Z01
    OSC_HARMONICITY_WREN   : in std_logic;
    MEM_IN       : in std_logic_vector(ram_width18 -1 downto 0);
    MEM_WRADDR   : in std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    
    ZN2_RATIONAL : out signed(ram_width18-1 downto 0) := (others=>'0');
   
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;


component param_lpf is
Port ( 
    clk100       : in STD_LOGIC;
    
    ZN2_ADDR_IN      : in unsigned (RAMADDR_WIDTH -1 downto 0); 
    Z00_PARAM_IN     : in signed(ram_width18 -1 downto 0);
    Z01_ALPHA_IN     : in signed(ram_width18 -1 downto 0);
    Z00_PARAM_OUT    : out signed(ram_width18 -1 downto 0);
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;
   
component param_lpf_25 is
Port ( 
    clk100       : in STD_LOGIC;
    
    ZN2_ADDR_IN      : in unsigned (RAMADDR_WIDTH -1 downto 0); 
    Z00_PARAM_IN     : in signed(STD_FLOWWIDTH -1 downto 0);
    Z01_ALPHA_IN     : in signed(STD_FLOWWIDTH -1 downto 0);
    Z00_PARAM_OUT    : out signed(STD_FLOWWIDTH -1 downto 0);
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;
   
attribute mark_debug : string;

signal RAM_REGCE     : std_logic := '0';
signal RAM18_WE      : STD_LOGIC_VECTOR (1 downto 0) := (others => '1');   
signal RAM36_WE      : STD_LOGIC_VECTOR (3 downto 0) := (others => '1');   
signal RAM_RDEN      : std_logic := '0';

signal Z01_INCTARGET_Z02_RATE   : std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others => '0');
signal Z02_INCREMENT: signed(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z03_PORTRATE : signed(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z04_PORTRATE : signed(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z03_INCREMENT: signed(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z03_INCREMENT_LPF: signed(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z04_INCREMENT: sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z05_INCREMENT: sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');

signal Z07_PHASE_WREN  : std_logic := '0';

signal Z00_timeDiv0 : integer range 0 to time_divisions-1 := 0;
signal Z00_timeDiv1 : integer range 0 to time_divisions-1 := 0;
signal Z01_timeDiv  : integer range 0 to time_divisions-1 := 0;
signal Z02_timeDiv  : integer range 0 to time_divisions-1 := 0;
signal Z03_timeDiv  : integer range 0 to time_divisions-1 := 0;

type CURRINSTTYPE is array(ZN1 to Z14) of integer range 0 to instcount; 
signal currInst : CURRINSTTYPE := (others=>0);    
  
signal Z02_TEST_PHASE   : signed(ram_width18-1 downto 0):= (others=>'0');
signal Z00_TEST_ADDR    : unsigned(ramaddr_width-1 downto 0):= (others=>'0');
signal Z00_ADDR_uFixed  : ufixed(1 downto -ramaddr_width+2):= (others=>'0');
signal Z00_LEFTSHIFT    : integer := 0;
attribute mark_debug of Z02_TEST_PHASE: signal is "true";
attribute mark_debug of Z00_TEST_ADDR: signal is "true";

type oscpervoice_by_sfixed25 is array (0 to oscpervoice -1) of sfixed(1 downto -STD_FLOWWIDTH + 2);
type oscpervoice_by_sfixed18 is array (0 to oscpervoice -1) of sfixed(3 downto -ram_width18 + 4);

type phasetype is array(ZN9 to Z05) of signed(STD_FLOWWIDTH-1 downto 0);
signal PHASE     : phasetype     := ((others=>(others=>'0')));
signal ZN10_PHASE: std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
type MODAMP_TYPE is array (0 to oscpervoice-1) of std_logic_vector(ram_width18-1 downto 0);
signal Z02_OSC_MODAMP: MODAMP_TYPE := (others=>(others=>'0'));
type MODAMP_TYPE_s is array (0 to oscpervoice-1) of signed(ram_width18-1 downto 0);
signal Z02_OSC_MODAMP_lpf: MODAMP_TYPE_s := (others=>(others=>'0'));
signal ZN9_PHASE_trunc  : signed(ram_width18-1 downto 0):= (others=>'0');
signal Z07_PHASE: std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z06_OSC_VOLUME   : std_logic_vector(ram_width18-1 downto 0)     := (others=>'0');
signal Z03_OSC_DETUNE   : std_logic_vector(ram_width18-1 downto 0)     := (others=>'0');
signal Z07_OSCVOL   : sfixed(1 downto -ram_width18 + 2)  := (others=>'0');
signal Z07_OSCVOL_DEBUG  : signed(ram_width18-1 downto 0):= (others=>'0');
signal Z03_MODAMP   : oscpervoice_by_sfixed18 := (others=>(others=>'0'));
signal ZN2_waveform : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');

signal Z02_waveform_all : oscpervoice_by_sfixed25 := (others=>(others=>'0'));
-- Z02 waveform is ZN2 wf [0 1 2 3]
signal Z03_waveform_all : oscpervoice_by_sfixed25 := (others=>(others=>'0'));
signal Z04_waveform_all : oscpervoice_by_sfixed25 := (others=>(others=>'0'));
signal Z05_waveform_all : oscpervoice_by_sfixed25 := (others=>(others=>'0'));
signal Z06_waveform_all : oscpervoice_by_sfixed25 := (others=>(others=>'0'));
signal Z04_ADJ_CROSSMOD : oscpervoice_by_sfixed25 := (others=>(others=>'0'));
signal Z05_ADJ_CROSSMOD_3 : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');

signal Z02_PITCH_SHIFT      : sfixed(3 downto -ram_width18 + 4)  := (others=>'0');

signal Z01_DETUNE_RATIO_UP     : sfixed(1 downto -ram_width18 + 2)  := (others=>'0');
signal Z01_DETUNE_RATIO_DOWN   : sfixed(1 downto -ram_width18 + 2)  := (others=>'0');
signal Z01_UNISON_UP_DETUNE    : sfixed(1 downto -ram_width18 + 2)  := (others=>'0');
signal Z01_UNISON_DOWN_DETUNE  : sfixed(1 downto -ram_width18 + 2)  := (others=>'0');

signal Z02_UNISON_DETUNE     : sfixed(1 downto -ram_width18 + 2)  := (others=>'0');
signal Z03_VOICE_DETUNE      : sfixed(3 downto -ram_width18 + 4)  := (others=>'0');
signal Z04_OSC_DETUNE        : signed(ram_width18-1 downto 0)  := (others=>'0');
signal Z04_DETMODPROD        : sfixed(3 downto -ram_width18 + 4)  := (others=>'0');
signal Z05_DETUNED_INCREMENT : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z05_DETUNED_INCREMENT_debug : std_logic_vector(STD_FLOWWIDTH-1 downto 0);
signal Z05_ADJ_FEEDBACK      : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z05_MOD_SUM           : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z06_MOD_SUM           : signed(STD_FLOWWIDTH-1 downto 0)  := (others=>'0');
signal Z06_LINEAR_TOTAL      : signed(STD_FLOWWIDTH-1 downto 0)  := (others=>'0'); 
signal Z06_ADJ_FEEDBACK      : signed(STD_FLOWWIDTH-1 downto 0)  := (others=>'0');
signal Z08_VOLWAVEFORM       : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z08_VOLWAVEFORM_DEBUG : signed(STD_FLOWWIDTH-1 downto 0)  := (others=>'0');

signal Z09_SUM       : sfixed(1 downto -STD_FLOWWIDTH+2) := (others => '0');
signal Z09_SUM_LAST  : sfixed(1 downto -STD_FLOWWIDTH+2) := (others => '0');
signal Z11_SUM       : sfixed(2 downto -Z09_SUM'length + 2) := (others => '0');
signal Z13_Z11_SUM_LAST  : sfixed(2 downto -Z09_SUM'length + 2) := (others => '0');
signal Z15_SUM       : sfixed(3 downto -STD_FLOWWIDTH + 2) := (others => '0');

signal Z15_OSCSHIFT : natural := 0;

signal Z03_OSC_HARMONICITY_ALPHA : std_logic_vector(ram_width18-1 downto 0)  := (others=>'0'); 

signal Z02_RATIONAL : signed(ram_width18-1 downto 0)  := (others=>'0'); 
signal Z02_RATIONAL_LPF : signed(ram_width18-1 downto 0)  := (others=>'0'); 
signal Z03_RATIONAL : sfixed(3 downto -ram_width18 + 4)  := (others=>'0');

signal Z02_OS      : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal Z02_COMPUTED_ENVELOPE : inputcount_by_ramwidth18s := (others=>(others=>'0'));
signal Z03_OS      : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal Z03_COMPUTED_ENVELOPE : inputcount_by_ramwidth18s := (others=>(others=>'0'));

signal Z03_RINGMOD : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z04_RINGMOD : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z05_RINGMOD : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z06_RINGMOD : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z07_RINGMOD : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
-- DEBUG SHOWS SFIXED as AN ARRAY OF STD_LOGIC! THIS IS _BAD_
signal Z07_RINGMOD_DEBUG : signed(STD_FLOWWIDTH-1 downto 0)  := (others=>'0');
signal Z03_RINGMOD_DEBUG : signed(STD_FLOWWIDTH-1 downto 0)  := (others=>'0');

signal ZN1_waveform : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z00_waveform : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z01_waveform : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');
signal Z02_waveform : sfixed(1 downto -STD_FLOWWIDTH + 2)  := (others=>'0');

signal Z03_OSCDET_DRAW : unsigned(drawslog2-1 downto 0) := (others=>'0');

signal MODAMP_ALPHA : signed(ram_width18 -1 downto 0) := to_signed(2**12 + 2**11, ram_width18);

begin 

Z08_VOLWAVEFORM_DEBUG <= signed(to_slv(Z08_VOLWAVEFORM));
Z03_RINGMOD_DEBUG     <= signed(to_slv(Z03_RINGMOD));
Z07_RINGMOD_DEBUG     <= signed(to_slv(Z07_RINGMOD));
Z07_OSCVOL_DEBUG      <= signed(to_slv(Z07_OSCVOL));
Z05_DETUNED_INCREMENT_debug <= to_slv(Z05_DETUNED_INCREMENT);

ZN9_PHASE_trunc <= PHASE(ZN9)(STD_FLOWWIDTH-1 downto STD_FLOWWIDTH-RAM_WIDTH18);
Z02_TEST_PHASE  <= PHASE(Z02)(STD_FLOWWIDTH-1 downto STD_FLOWWIDTH-RAM_WIDTH18);

i_inc_target_and_rate_ram: ram_controller_36k_25 port map (
    DO         => Z01_INCTARGET_Z02_RATE,
    DI         => MEM_IN25,
    RDADDR     => std_logic_vector(ADDR(Z00)),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM36_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => OSC_INCTARGET_RATE_WREN);
    
i_sine_lookup: sine_lookup 
port map(
    clk100       => clk100,
    Z00_PHASE_in => PHASE(ZN8),
    Z06_SINE_out => ZN2_WAVEFORM,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
);

i_harmonicity_alpha_ram: ram_controller_18k_18 port map (
    DO         => Z03_OSC_HARMONICITY_ALPHA,
    DI         => std_logic_vector(MEM_IN),
    RDADDR     => std_logic_vector(ADDR(Z02)),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(MEM_WRADDR),
    WRCLK      => clk100,
    WREN       => OSC_HARMONICITY_ALPHA_WREN);
    
i_rationalize: rationalize 
port map(
    clk100          => clk100,
    
    MEM_IN       => MEM_IN,
    MEM_WRADDR   => MEM_WRADDR,
    
    ZN3_ADDR        => ADDR(Z01),
    Z00_IRRATIONAL  => Z04_OSC_DETUNE,
    OSC_HARMONICITY_WREN => OSC_HARMONICITY_WREN,
    
    ZN2_RATIONAL => Z02_RATIONAL,
    
    initRam100     => initRam100,
    ram_rst100  => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
);
        
i_harmonicity_lpf: param_lpf port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => ADDR(Z00), 
    Z00_PARAM_IN  => Z02_RATIONAL, 
    Z01_ALPHA_IN  => signed(Z03_OSC_HARMONICITY_ALPHA), 
    Z00_PARAM_OUT => Z02_RATIONAL_LPF, 
    
    initRam100      => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
    
i_porto_lpf: param_lpf_25 port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => ADDR(Z01), 
    Z00_PARAM_IN  => Z03_INCREMENT, 
    Z01_ALPHA_IN  => Z04_PORTRATE, 
    Z00_PARAM_OUT => Z03_INCREMENT_LPF, 
    
    initRam100      => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
        
i_OSCVOL_ram: ram_controller_18k_18 port map (
    DO         => Z06_OSC_VOLUME,
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(ADDR(Z05)),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => OSC_VOL_WREN);
    
i_OSCDET_ram: ram_controller_18k_18 port map (
    DO         => Z03_OSC_DETUNE,
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(ADDR(Z02)),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => OSC_DETUNE_WREN);
        
i_phase_ram: ram_controller_36k_25 port map (
    DO         => ZN10_PHASE,
    DI         => Z07_PHASE,
    RDADDR     => std_logic_vector(ADDR(ZN11)),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM36_WE,
    WRADDR     => std_logic_vector(ADDR(Z07)),
    WRCLK      => clk100,
    WREN       => Z07_PHASE_WREN);
    
        
amfm_gen:
for modulator in 0 to oscpervoice - 1 generate

i_modampram: ram_controller_18k_18 port map (
    DO         => Z02_OSC_MODAMP(modulator),
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(ADDR(Z01)),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => OSC_MODAMP_WREN(modulator));

i_modamp_lpf: param_lpf port map (
    clk100        => clk100, 
    
    ZN2_ADDR_IN   => ADDR(Z01), 
    Z00_PARAM_IN  => signed(Z02_OSC_MODAMP(modulator)), 
    Z01_ALPHA_IN  => MODAMP_ALPHA, 
    Z00_PARAM_OUT => Z02_OSC_MODAMP_lpf(modulator), 
    
    initRam100    => initRam100, 
    ram_rst100    => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
    
amfm_proc: process(clk100)
begin
if rising_edge(clk100) then
if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
    -- step 1: find actual modamp for each mod oscillator
    Z03_MODAMP(modulator)  <= sfixed(CHOOSEMOD3(OSC_MODAMP_DRAW(currinst(Z02), Z02_timeDiv, modulator), 
    Z02_OSC_MODAMP_lpf(modulator), Z03_OS, Z03_COMPUTED_ENVELOPE));
    
    -- step 2: multiply this modulator with waveform at same index
    Z04_ADJ_CROSSMOD(modulator) <= RESIZE(Z03_waveform_all(modulator) * Z03_MODAMP(modulator), Z04_ADJ_CROSSMOD(modulator), fixed_wrap, fixed_truncate);
end if;
end if;
end process;
end generate;
    
phase_proc: process(clk100)
begin
if rising_edge(clk100) then
if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
             
    -- sum up mod results which are not self
    Z05_MOD_SUM <= RESIZE(
    Z04_ADJ_CROSSMOD(Z03_timeDiv) + 
    Z04_ADJ_CROSSMOD(Z02_timeDiv)
    , 
    Z05_MOD_SUM, fixed_wrap, fixed_truncate);
    
    Z05_ADJ_CROSSMOD_3 <= Z04_ADJ_CROSSMOD(Z01_timeDiv);
    
    -- if this is self modulator (feedback), limit by increment
    Z05_ADJ_FEEDBACK <= sfixed(Z04_ADJ_CROSSMOD(Z00_timeDiv0));
    Z06_ADJ_FEEDBACK <= signed(to_slv(RESIZE(Z05_ADJ_FEEDBACK* Z05_INCREMENT, Z05_ADJ_FEEDBACK, fixed_wrap, fixed_truncate)));
    
    -- sum in the feedback
    Z06_MOD_SUM <= signed(to_slv(resize(Z05_MOD_SUM + Z05_ADJ_CROSSMOD_3, Z05_MOD_SUM, fixed_wrap, fixed_truncate)));
    
    -- DETUNE PROCESS
    Z03_RATIONAL <= sfixed(Z02_RATIONAL_LPF);
    -- total detune is the product of voice detune (dp. 14) with the rationalizer output (dp. 14)
    --Z04_DETMODPROD <= MULT(Z02_PITCH_SHIFT, Z03_RATIONAL, RAM_WIDTH18, 6) ;
    
    
    
--      function resize (
--        arg                     : sfixed;   -- input
--        size_res                : sfixed;   -- for size only
--        constant overflow_style : BOOLEAN := fixed_overflow_style;  -- saturate by default TRUE = SATURATE
--        constant round_style    : BOOLEAN := fixed_round_style)  -- rounding by default    TRUE = ROUND
--        return sfixed;
    Z04_DETMODPROD <= resize(Z03_VOICE_DETUNE * Z03_RATIONAL, Z04_DETMODPROD, fixed_wrap, fixed_truncate) ;
        
    Z03_OSCDET_DRAW <= OSC_DETUNE_DRAW(currinst(Z02), Z02_timeDiv);
    -- prepare osc detmod
    Z04_OSC_DETUNE <= CHOOSEMOD3(Z03_OSCDET_DRAW,
            signed(Z03_OSC_DETUNE), Z03_OS, Z03_COMPUTED_ENVELOPE);
    -- perform the multiplication
    Z05_DETUNED_INCREMENT <= resize(Z04_INCREMENT * Z04_DETMODPROD, Z05_DETUNED_INCREMENT, fixed_wrap, fixed_truncate) ;
    
    --STEP 4:
    
    --Z06_LINEAR_TOTAL = Increment + Phase
    Z06_LINEAR_TOTAL <= signed(to_slv(Z05_DETUNED_INCREMENT)) + PHASE(Z05);

    -- compute total phase
    Z07_PHASE <= STD_LOGIC_VECTOR(Z06_MOD_SUM + Z06_LINEAR_TOTAL + Z06_ADJ_FEEDBACK);
            
    -- if no movement has occurred and unsigned(phase) is not 0, add 1 to slowly wrap phase back around to 0
--    if Z06_LINEAR_TOTAL = PHASE(Z05) and Z05_MOD_TOTAL = 0 and unsigned(PHASE(Z05)) /= 0 then
--        -- compute total phase + 64
--        Z07_PHASE <= STD_LOGIC_VECTOR(Z05_MOD_TOTAL + Z06_LINEAR_TOTAL + 1);
--    end if;
    
    -- every voice, save all waveforms
    if Z02_timeDiv = 0 then
        Z03_waveform_all <= Z02_waveform_all;
    end if;
    
    -- STEP 3: ringmod
    Z03_RINGMOD <= Z02_waveform;
    Z04_RINGMOD <= Z03_RINGMOD;
    Z05_RINGMOD <= Z04_RINGMOD;
    Z06_RINGMOD <= Z05_RINGMOD;
    Z07_RINGMOD <= Z06_RINGMOD;
    
    ZN1_waveform <= ZN2_waveform;
    Z00_waveform <= ZN1_waveform;
    Z01_waveform <= Z00_waveform;
    Z02_waveform <= Z01_waveform;
    
    Z04_waveform_all <= Z03_waveform_all;
    Z05_waveform_all <= Z04_waveform_all;
    Z06_waveform_all <= Z05_waveform_all;
    
    -- multiply by 0th osc, if indicated
    if OSC_RINGMOD(currInst(Z03), Z03_timeDiv)(0) = '1' then
        Z04_RINGMOD <= resize(Z03_RINGMOD * Z03_WAVEFORM_ALL(0), Z04_RINGMOD, fixed_wrap, fixed_truncate) ;
    end if;
    -- multiply by osc 1 if indicated
    if OSC_RINGMOD(currInst(Z04), Z00_timeDiv1)(1) = '1' then
        Z05_RINGMOD <= resize(Z04_RINGMOD * Z04_WAVEFORM_ALL(1), Z05_RINGMOD, fixed_wrap, fixed_truncate) ;
        --Z05_RINGMOD <= resize(to_sfixed(1, Z05_RINGMOD) * Z04_WAVEFORM_ALL(1), Z05_RINGMOD, fixed_wrap, fixed_truncate) ;
    end if;
    -- multiply by osc 2 if indicated
    if OSC_RINGMOD(currInst(Z05), Z01_timeDiv)(2) = '1' then
        Z06_RINGMOD <= resize(Z05_RINGMOD * Z05_WAVEFORM_ALL(2), Z06_RINGMOD, fixed_wrap, fixed_truncate) ;
    end if;
    -- multiply by osc 3 if indicated
    if OSC_RINGMOD(currInst(Z06), Z02_timeDiv)(3) = '1' then
        Z07_RINGMOD <= resize(Z06_RINGMOD * Z06_WAVEFORM_ALL(3), Z07_RINGMOD, fixed_wrap, fixed_truncate) ;
    end if;
    
    Z07_OSCVOL <= sfixed(Z06_OSC_VOLUME);
    Z08_VOLWAVEFORM <= resize(Z07_RINGMOD * Z07_OSCVOL, Z08_VOLWAVEFORM, fixed_wrap, fixed_truncate);


end if;
end if;
end process;
    
RAM_RDEN   <= not OUTSAMPLEF_ALMOSTFULL;
        
timing_proc: process(clk100)
begin
if rising_edge(clk100) then
    
    if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
    
        Z00_timeDiv0 <= to_integer(ADDR(ZN1)(log2(time_divisions) - 1 downto 0 ));
        Z00_timeDiv1 <= to_integer(ADDR(ZN1)(log2(time_divisions) - 1 downto 0 ));
        Z01_timeDiv <= Z00_timeDiv1;
        Z02_timeDiv <= Z01_timeDiv;
        Z03_timeDiv <= Z02_timeDiv;
    
        Z00_TEST_ADDR   <= ADDR(ZN1);
            
        Z02_OS      <= Z01_OS;
        Z03_OS      <= Z02_OS;
        Z02_COMPUTED_ENVELOPE <= Z01_COMPUTED_ENVELOPE;
        Z03_COMPUTED_ENVELOPE <= Z02_COMPUTED_ENVELOPE;
    
        PHASE(ZN9) <= signed(ZN10_PHASE);
        
        PHASELOOP:
        for phasenum in PHASE'low + 1 to PHASE'high loop
            PHASE(phasenum) <= PHASE(phasenum-1);
        end loop;
        
        -- 2 shifts to divide by 4 from cross-time add
        -- one more to max value out at 1/2 unity
        -- Z15_OSCSHIFT <= 4(currinst(Z14)) + 3;
        Z15_OSCSHIFT <= 4;
    
        -- pull in pitch shift
        Z02_PITCH_SHIFT <= sfixed(CHOOSEMOD3(PITCH_SHIFT_DRAW(currinst(Z01)),
                    PITCH_SHIFT(currinst(Z01)), Z01_OS, Z01_COMPUTED_ENVELOPE));
                    
        -- multiply by the detune of this unison
        Z03_VOICE_DETUNE <= resize(Z02_PITCH_SHIFT * Z02_UNISON_DETUNE, Z03_VOICE_DETUNE, fixed_wrap, fixed_truncate);
        
                
        Z07_PHASE_WREN <= '1';
        
        
        currinst(ZN1) <= to_integer(ADDR(ZN2)(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
        instprop:
        for z in currinst'low + 1 to currinst'high loop
            currinst(z) <= currinst(z-1);
        end loop;
        
        Z03_INCREMENT <= CHOOSEMOD3(OSC_INC_DRAW(currinst(Z02), Z02_timeDiv), 
        Z02_INCREMENT, Z02_OS, Z02_COMPUTED_ENVELOPE );
        Z04_INCREMENT <= sfixed(Z03_INCREMENT_LPF);
        Z05_INCREMENT <= Z04_INCREMENT;
            
        Z02_waveform_all(Z02_timeDiv) <= ZN2_WAVEFORM;
        
        -- increment is given in the even ram addresses,
        -- portrate is in the odd
        case Z01_timeDiv is
        when 0 =>
            Z02_INCREMENT <= signed(Z01_INCTARGET_Z02_RATE);
        when 1 =>
            Z03_PORTRATE  <= signed(Z01_INCTARGET_Z02_RATE);
        when others =>
        end case;
        Z04_PORTRATE <= Z03_PORTRATE;
        
        --third output pipeline stage : add in groups of two (26 long now)
        -- first and only addition in address domain
        -- since there is now only 1 osc per address, pass Z08_WAVEORM through
        Z09_SUM <= Z08_VOLWAVEFORM;
        Z09_SUM_LAST <= Z09_SUM;
        
        -- first addition across time domain
        if Z01_timeDiv = 1 or Z01_timeDiv = 3 then
            Z11_SUM <= resize(Z09_SUM + Z09_SUM_LAST, Z11_SUM, fixed_wrap, fixed_truncate);
            Z13_Z11_SUM_LAST <= Z11_SUM;
        end if;
        
        -- second and final addition across time domain
        if Z02_timeDiv = 0 then
            Z15_SUM <= resize(Z11_SUM + Z13_Z11_SUM_LAST, Z15_SUM, fixed_wrap, fixed_truncate);
        end if;
        
        Z16_OSC_OUT <= resize(Z15_SUM sra Z15_OSCSHIFT, Z09_SUM, fixed_wrap, fixed_truncate);
        
        Z01_DETUNE_RATIO_UP   <= sfixed(DETUNE_RATIO(currInst(Z00), 0));
        Z01_DETUNE_RATIO_DOWN <= sfixed(DETUNE_RATIO(currInst(Z00), 1));
        
        -- prepare shift amount
        Z00_LEFTSHIFT <= INSTCOUNTLOG2 + 6 - UNISON_VOICES_LOG2(currInst(ZN1));
        Z00_ADDR_uFixed <= ufixed(ADDR(ZN1));
        
        -- prepare the unison multiplier
        -- reset every UNISONVOICES period
        -- this complex instruction tests Z00_ADDR_uFixed(unisonvoiceslog2-1 downto 0)
        -- because vhdl doesnt allow variable length source operands 
        if Z00_ADDR_uFixed sll Z00_LEFTSHIFT = 0 then
            -- restart up and down detune
            Z01_UNISON_UP_DETUNE   <= to_sfixed(1, Z01_UNISON_UP_DETUNE);
            Z01_UNISON_DOWN_DETUNE <= to_sfixed(1, Z01_UNISON_UP_DETUNE);
            
        -- else if Z00 time div 0 then 
        elsif Z00_timediv1 = 0 then
            if ADDR(Z00)(2) = '0' then
                Z01_UNISON_UP_DETUNE <= resize(Z01_UNISON_UP_DETUNE * Z01_DETUNE_RATIO_UP, Z01_UNISON_UP_DETUNE, fixed_wrap, fixed_truncate);
            else
                Z01_UNISON_DOWN_DETUNE <= resize(Z01_UNISON_DOWN_DETUNE * Z01_DETUNE_RATIO_DOWN, Z01_UNISON_DOWN_DETUNE, fixed_wrap, fixed_truncate);
            end if;
        end if;
                
        -- if Z02 time div 0 then 
        if Z01_timediv = 0 then
            if ADDR(Z01)(2) = '0' then
                Z02_UNISON_DETUNE    <= Z01_UNISON_UP_DETUNE;
            else
                Z02_UNISON_DETUNE    <= Z01_UNISON_DOWN_DETUNE;
            end if;
        end if;
        
    -- FIFO full or Initializing : don't process
    else
        Z07_PHASE_WREN <= '0';
    end if;
end if;
end process;

end Behavioral;