----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>, Julian Loiacono 
-- 
-- Module Name: fm_engine_top - Behavioral
--
-- Description: a synth controlled over SPI
----------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

Library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity fm_engine_top is
Port ( 
    -- clk signals
    clk100     : in STD_LOGIC;
    
    -- division length in samples
    SAMPLES_PER_DIV_DO : in STD_LOGIC_VECTOR(std_flowwidth downto 0);
        
    -- out fifo signals
    OUTSAMPLEF_ALMOSTFULL: in std_logic;
    OUTSAMPLEF_DI      : out signed (i2s_width -1 downto 0) := (others=>'0');
    OUTSAMPLEF_WREN    : out std_logic;
    
    -- in fifo signals
    INPARAMF_EMPTY    : in std_logic;
    INPARAMF_DO       : in std_logic_vector (gpif_width -1 downto 0);
    INPARAMF_RDEN     : out std_logic := '0';
        
    -- in sample signals
    INSAMPLEF_ALMOSTEMPTY: in std_logic;
    INSAMPLEF_DO       : in std_logic_vector (gpif_width -1 downto 0);
    INSAMPLEF_RDEN     : out std_logic;
      
    -- ram control signals
    FROM_RAMF_ALMOSTEMPTY   : in std_logic;
    ram_rst100 : in std_logic;
    initRam100 : in std_logic
    );
           
end fm_engine_top;

architecture Behavioral of fm_engine_top is

-- probe signals

attribute mark_debug : string;
signal OUTFIFO_PROBE  : signed(i2s_width-1 downto 0):= (others=>'0');
attribute mark_debug of OUTFIFO_PROBE: signal is "true";
signal OUTFIFOWREN_PROBE  : std_logic := '0';
attribute mark_debug of OUTFIFOWREN_PROBE: signal is "true";

-- parameter signals  
signal VOICE_SHIFT : instcount_by_integer := (others=>0);
signal INST_SHIFT  : integer range 0 to instcount-1 := 0;

signal OS_STAGE_SET_WREN : STD_LOGIC := '0';

signal bmADDR  : unsigned(RAMADDR_WIDTH -1 downto 0):= (others=>'0');
signal beginMeasure: std_logic := '0';

-- note-independant signals
signal MEM_IN25      : std_logic_vector(STD_FLOWWIDTH -1 downto 0):= (others=>'0');
signal MEM_IN36      : std_logic_vector(36 -1 downto 0)  := (others=>'0');
signal MEM_IN0       : std_logic_vector(ram_width18 -1 downto 0)  := (others=>'0');
signal VOICEIN       : std_logic_vector(ram_width18 -1 downto 0)  := (others=>'0');
constant VOICE_VALID : integer := 15;
constant VOICE_ARMED : integer := 16;
attribute mark_debug of MEM_IN0: signal is "true";
signal MEM_IN1       : std_logic_vector(ram_width18 -1 downto 0)  := (others=>'0');
signal DRAW_IN       : unsigned(drawslog2-1 downto 0) := (others=>'0');
attribute mark_debug of DRAW_IN: signal is "true";
signal INSTNO_i      : integer range 0 to instcount-1 := 0;
signal VOICENO       : std_logic_vector(GPIF_WIDTH -2 downto 0) := (others=>'0');
signal BY_TAG        : std_logic := '0';
signal ALL_VOICES    : std_logic := '0';
signal OPTIONS_TYPE  : std_logic_vector(3 downto 0) := (others=>'0');

signal MEM_WRADDR    : std_logic_vector(RAMADDR_WIDTH -1 downto 0):= (others=>'0');
attribute mark_debug of MEM_WRADDR: signal is "true";

signal OSC_INCTARGET_RATE_WREN: std_logic := '0';
signal VOICE_ENVVAL_WREN : std_logic := '0';
signal OSC_MODAMP_WREN   : std_logic_vector(oscpervoice-1 downto 0) := (others=>'0');
signal OSC_VOL_WREN      : std_logic := '0';
signal VOICE_FILTQ_WREN  : std_logic := '0';
signal VOICE_FILTF_WREN  : std_logic := '0';
signal ONESHOTRATE_WREN  : std_logic_vector(stagecount-1 downto 0);
signal GAIN_WREN         : std_logic := '0';
attribute mark_debug of OSC_INCTARGET_RATE_WREN: signal is "true";
attribute mark_debug of VOICE_ENVVAL_WREN: signal is "true";

-- instrument-independant formative mux signals
signal OSC_RINGMOD : instcount_by_oscpervoice_by_oscpervoice := (others=>(others=>(others=>'0')));
signal OSC_DETUNE_WREN   : std_logic := '0';
signal OSC_DETUNE_DRAW   : instcount_by_oscpervoice_by_drawslog2 := (others=>(others=>(others=>'0')));
signal OSC_HARMONICITY_WREN  : std_logic := '0';
signal OSC_HARMONICITY_ALPHA_WREN : std_logic := '0';

-- instrument-independant effects mux signals
signal PITCH_SHIFT_DRAW : instcount_by_drawslog2  := (others=>(others=>'0'));
signal PITCH_SHIFT  : instcount_by_ramwidth18 := (others=>"000100000000000000");

signal DETUNE_RATIO       : instcount_by_2_by_ramwidth18 := (others=>(others=>(others=>'0')));
signal UNISON_VOICES_LOG2 : instcount_by_integer := (others=>0);
signal UNISON_MIDPOINT    : instcount_by_ramwidth18 := (others=>(others=>'0'));
signal UNISON_ENDPOINT    : instcount_by_ramwidth18 := (others=>(others=>'0'));
    
signal OSC_INC_DRAW      : instcount_by_oscpervoice_by_drawslog2 := (others=>(others=>(others=>'0')));  
signal OSC_MODAMP_DRAW   : instcount_by_oscpervoice_by_oscpervoice_by_drawslog2 := (others=>(others=>(others=>(others=>'0'))));
signal OSC_VOL_DRAW      : instcount_by_oscpervoice_by_drawslog2 := (others=>(others=>(others=>'0')));  

signal VOICE_ENV_DRAW : instcount_by_envspervoice_by_drawslog2   := (others=>(others=>(others=>'0')));  
signal VOICE_PAN_DRAW : instcount_by_channelcount_by_panmodcount_by_drawslog2   := (others=>(others=>(others=>(others=>'0'))));
signal VOICE_PAN  : instcount_by_channelcount_by_panmodcount_by_ramwidth18s := (others=>(others=>(others=>(others=>'0'))));

-- instrument-independant internal modulator control signals
signal FILT_FDRAW    : instcount_by_polecount_by_drawslog2  := (others=>(others=>(others=>'0')));  
signal FILT_QDRAW    : instcount_by_polecount_by_drawslog2  := (others=>(others=>(others=>'0')));  
signal FILT_FTYPE    : instcount_by_polecount_by_ftypeslog2 := (others=>(others=>0));  
signal ONESHOT_STARTPOINT_Y : insts_by_oneshotspervoice_by_stagecount_by_ramwidth18 := (others=>(others=>(others=>(others=>'0'))));
signal ONESHOT_MIDPOINT_Y : insts_by_oneshotspervoice_by_stagecount_by_ramwidth18 := (others=>(others=>(others=>(others=>'0'))));
--signal ONESHOT_SUSTAINSTAGE : insts_by_oneshotspervoice_by_stagecount := (others=>(others=>"10"));
    
-- parameters for ALLPASS can be set for REVERBDELAYPHASERFLANGER
signal DELAY_SAMPLES      : instcount_by_delaytaps_by_ramwidth18u := (others=>(others=>(others=>'0')));
signal DELAY_SAMPLES_DRAW : instcount_by_delaytaps_by_drawslog2 := (others=>(others=>(others=>'0')));
    
signal INSTVOL_VAL   : instcount_by_instmods_by_ramwidth18 := (others=>(others=>(others=>'0')));
    
-- paramstate signals for in stream parser
signal PARAMREAD_DELAYCOUNT : integer := 0;
signal paramA0 : integer range 0 to 2**10-1;
signal paramA1 : integer range 0 to 2**10-1;
attribute mark_debug of paramA1: signal is "true";
signal paramA1_low2 : std_logic_vector(1 downto 0);
signal INSTNO : unsigned(instcountlog2-1 downto 0) := (others=>'0');
signal paramno : unsigned(12 downto 0) := (others=>'0');
signal isdraw  : std_logic := '0';
attribute mark_debug of paramno: signal is "true";
signal PARAM_RDCOUNT : integer := 0;

signal SAMPLES_PER_DIV_DO_last : STD_LOGIC_VECTOR(std_flowwidth downto 0);
signal SAMPLES_PER_DIV : STD_LOGIC_VECTOR(std_flowwidth-1 downto 0);

type paramread_fsm_state is (
    s_idle,        -- 0
    s_wait_noread, -- 1 
    s_wait,        -- 2
    s_readParamNo, -- 3  
    s_readInstNo,  -- 4
    s_readVoiceNo, -- 5
    s_readA1,      -- 6
    s_readA0,      -- 7
    s_readPL2,     -- 8
    s_readPL1,     -- 9
    s_readPL0,     -- 10
    s_apply,       -- 11
    s_setVoices,    -- 12
    s_spawnVoicesTest,  -- 13
    s_spawnVoicesWait,  -- 14
    s_spawnVoiceClaim,   -- 15
    s_patchinit -- 16
    );
signal paramstate     : paramread_fsm_state := s_idle;
signal paramstate_next: paramread_fsm_state := s_idle;
attribute FSM_ENCODING : string;
attribute FSM_ENCODING of paramstate : signal is "ONE-HOT";
attribute mark_debug of paramstate: signal is "true";
attribute mark_debug of INPARAMF_DO: signal is "true";

constant LFO_DUMMY : inputcount_by_ramwidth18s := (others=>(others=>'0'));

-- internal mod signals
signal ZN4_OS   : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));

--propagation signals
constant maxMODpropagate  : integer := Z39 / 4;
type   OSPROPAGATETYPE is array (0 to maxMODpropagate) of oneshotspervoice_by_ramwidth18s;
signal OS_PROPAGATE : OSPROPAGATETYPE := (others=>(others=>(others=>'0')));
signal ADDR : address_type := (others=>(others=>'0'));

-- dataflow signals
signal Z38_FILT_OUT     : sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
signal Z38_FILT_OUT_slv : std_logic_vector(std_flowwidth - 1 downto 0 ) := (others=>'0');
attribute mark_debug of Z38_FILT_OUT_slv: signal is "true";
signal Z16_OSC_OUT      : sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
signal Z16_OSC_OUT_slv  : std_logic_vector(std_flowwidth - 1 downto 0 ) := (others=>'0');
attribute mark_debug of Z16_OSC_OUT_slv: signal is "true";
constant ENV_TO_FILT0_BASE: natural := 17;
signal Z17_ENV_OUT     : sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
signal Z17_ENV_OUT_slv : std_logic_vector(std_flowwidth - 1 downto 0 ) := (others=>'0');
attribute mark_debug of Z17_ENV_OUT_slv: signal is "true";
signal Z18_INTERP_OUT    : sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
signal Z18_INTERP_OUT_slv: std_logic_vector(std_flowwidth - 1 downto 0 ) := (others=>'0');
attribute mark_debug of Z18_INTERP_OUT_slv: signal is "true";
signal Z00_INSTSUM_OUT    : sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
signal Z00_INSTSUM_OUT_slv: std_logic_vector(std_flowwidth - 1 downto 0 ) := (others=>'0');
attribute mark_debug of Z00_INSTSUM_OUT_slv: signal is "true";
signal Z12_ALLPASS_OUT    : sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
signal Z12_ALLPASS_OUT_slv: std_logic_vector(std_flowwidth - 1 downto 0 ) := (others=>'0');
attribute mark_debug of Z12_ALLPASS_OUT_slv: signal is "true";

signal RATE_DRAW  : insts_by_oneshotspervoice_by_drawslog2 := (others=>(others=>(others=>'0')));
       
-- bullshit VHDL 93 signals
signal I2S_BCLK_OUT  : STD_LOGIC := '0';
signal I2S_LRCLK_INT : STD_LOGIC := '0';
 
signal Z00_timeDiv : integer := 0;
 
type fivetimes_type is array (0 to polecount -1) of unsigned(4 downto 0);
constant fivetimes : fivetimes_type :=
(to_unsigned(0, 5),
to_unsigned(5,  5),
to_unsigned(10, 5),
to_unsigned(15, 5));
 
signal DPS_WREN : std_logic := '0';
signal DPS_WE   : STD_LOGIC_VECTOR (3 downto 0) := (others=>'0');
 
signal ZN6_ADDR_uFixed  : ufixed(1 downto -ramaddr_width+2):= (others=>'0');
signal ZN6_LEFTSHIFT    : integer := 0;
signal ZN6_currInst     : integer range 0 to instcount := 0;
signal ZN7_currInst     : integer range 0 to instcount := 0;

signal RAM18_WE  : std_logic_vector(1 downto 0) := "11";
signal RAM_RDEN  : std_logic :='0';
signal RAM_REGCE : std_logic :='0';

signal ZN6_voiceTag_DO : std_logic_vector(RAM_WIDTH18 -1 downto 0) := (others=>'0');
attribute mark_debug of ZN6_voiceTag_DO: signal is "true";
signal donestAddress : std_logic_vector(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal donestValue   : unsigned(stagecountlog2 + std_flowwidth-1 downto 0) := (others=>'0');
signal ZN6_voiceTag_RDADDR     : std_logic_vector(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal ZN7_voiceTag_RDADDR     : std_logic_vector(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
attribute mark_debug of ZN7_voiceTag_RDADDR: signal is "true";
signal voiceTag_RDEN : std_logic := '0';
signal voiceTag_WREN : std_logic := '0';
signal VOICES_TO_SET : unsigned(voicesperinstlog2-1 downto 0);
signal ZN6_OS_DONENESS : unsigned(stagecountlog2 + std_flowwidth-1 downto 0) := (others=>'0');
attribute mark_debug of ZN6_OS_DONENESS: signal is "true";

signal VOICE_COUNTDOWN : unsigned(voicecountlog2 + 2 downto 0) := (others=>'0');

signal FIRST_CLOCK_IN_IDLE : std_logic_vector(1 downto 0) := "11";

component ram_controller_18k_18 is
Port ( 
   DO             : out STD_LOGIC_VECTOR (17 downto 0);
   DI             : in  STD_LOGIC_VECTOR (17 downto 0);
   RDADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
   RDCLK          : in  STD_LOGIC;
   RDEN           : in  STD_LOGIC;
   REGCE          : in  STD_LOGIC;
   RST            : in  STD_LOGIC;
   WE             : in  STD_LOGIC_VECTOR (1 downto 0);
   WRADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
   WRCLK          : in  STD_LOGIC;
   WREN           : in  STD_LOGIC);
end component;

component chowning is
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
end component;
    
component oneshots is
Port (
    clk100       : in STD_LOGIC;
    ZN8_ADDR: in unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0'); 
        
    SAMPLES_PER_DIV : in STD_LOGIC_VECTOR(std_flowwidth-1 downto 0);
        
    ONESHOT_MIDPOINT_Y   : in insts_by_oneshotspervoice_by_stagecount_by_ramwidth18;    
    ONESHOT_STARTPOINT_Y : in insts_by_oneshotspervoice_by_stagecount_by_ramwidth18;

    MEM_WRADDR   : in std_logic_vector(ramaddr_width -1 downto 0);
    MEM_IN       : in std_logic_vector(ram_width18   -1 downto 0);
    MEM_IN36    : in std_logic_vector(36   -1 downto 0);
    ONESHOTRATE_WREN : in std_logic_vector(stagecount-1 downto 0);
    OS_STAGE_SET_WREN : in STD_LOGIC;
    DPS_WREN : IN STD_LOGIC;
    DPS_WE   : IN STD_LOGIC_VECTOR (3 downto 0) := (others => '0');   
    
    RATE_DRAW  : in insts_by_oneshotspervoice_by_drawslog2;
    ZN6_COMPUTED_ENVELOPE    : in inputcount_by_ramwidth18s;
    
    beginMeasure: in std_logic;
    Z00_OS    : out oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
    ZN2_DONENESS : out unsigned(stagecountlog2 + std_flowwidth -1 downto 0) := (others=>'0');
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

component envelopes is
Port ( 
    clk100     : in STD_LOGIC;

    MEM_WRADDR    : in STD_LOGIC_VECTOR (RAMADDR_WIDTH-1 downto 0)  := (others=>'0');            
    MEM_IN        : in STD_LOGIC_VECTOR (17 downto 0);   
    ZN12_ADDR     : in unsigned (RAMADDR_WIDTH-1 downto 0)  := (others=>'0'); 
    VOICE_ENVVAL_WREN   : in std_logic;
    VOICE_ENV_DRAW : in instcount_by_envspervoice_by_drawslog2;
    
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
end component;

component interpolate_oversample_4 is  
Port ( 
    clk100     : in STD_LOGIC;
    
    ZN1_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
    Z01_INTERP_OUT: out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    Z00_INTERP_IN : in  sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    
    ram_rst100    : in std_logic;
    initRam100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL  : in std_logic
);     
end component;

component note_svf is
Port (
    clk100     : in STD_LOGIC;
    ZN5_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
            
    Z20_FILTER_OUT: out sfixed(1 downto -STD_FLOWWIDTH + 2);
    Z00_FILTER_IN : in  sfixed(1 downto -STD_FLOWWIDTH + 2);
    
    Z05_OS     : in oneshotspervoice_by_ramwidth18s;
    Z05_COMPUTED_ENVELOPE: in inputcount_by_ramwidth18s;
    
    MEM_WRADDR    : in STD_LOGIC_VECTOR(RAMADDR_WIDTH-1 downto 0);
    MEM_IN        : in STD_LOGIC_VECTOR(ram_width18-1 downto 0); 
    VOICE_FILTQ_WREN: in STD_LOGIC;
    VOICE_FILTF_WREN: in STD_LOGIC;
    FILT_FDRAW : in instcount_by_polecount_by_drawslog2;
    FILT_QDRAW : in instcount_by_polecount_by_drawslog2;
    FILT_FTYPE : in instcount_by_polecount_by_ftypeslog2;
    
    ram_rst100    : in std_logic;
    initRam100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL  : in std_logic
    );
end component;


component instrument_sum is
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
end component;

component SCHROEDER_ALLPASS is
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
end component;

component note_panning is
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
end component;


begin
OUTSAMPLEF_DI <= OUTFIFO_PROBE;
Z00_timeDiv <= to_integer(ADDR(0)(1 downto 0));

Z16_OSC_OUT_slv     <= to_slv(Z16_OSC_OUT);
Z17_ENV_OUT_slv     <= to_slv(Z17_ENV_OUT);
Z18_INTERP_OUT_slv  <= to_slv(Z18_INTERP_OUT);
Z38_FILT_OUT_slv    <= to_slv(Z38_FILT_OUT);
Z00_INSTSUM_OUT_slv <= to_slv(Z00_INSTSUM_OUT);
Z12_ALLPASS_OUT_slv <= to_slv(Z12_ALLPASS_OUT);
OUTSAMPLEF_WREN     <= OUTFIFOWREN_PROBE;

-- voice occupation ram
i_voiceTag_ram: ram_controller_18k_18 port map (
    DO         => ZN6_voiceTag_DO,
    DI         => VOICEIN,
    RDADDR     => ZN7_voiceTag_RDADDR,
    RDCLK      => clk100,
    RDEN       => voiceTag_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => donestAddress,
    WRCLK      => clk100,
    WREN       => voiceTag_WREN
    );

-- oneSHOTS is a ZN4 signal so it can be used in computation of POLYLFOs
i_oneshots: oneshots port map(
    clk100         => clk100,
    ZN8_ADDR       => ADDR(ZN12),
        
    SAMPLES_PER_DIV => SAMPLES_PER_DIV,
        
    ONESHOT_MIDPOINT_Y    => ONESHOT_MIDPOINT_Y,
    ONESHOT_STARTPOINT_Y  => ONESHOT_STARTPOINT_Y,

    MEM_WRADDR   => MEM_WRADDR,
    MEM_IN       => MEM_IN0,
    MEM_IN36    => MEM_IN36,
    ONESHOTRATE_WREN  => ONESHOTRATE_WREN,
    OS_STAGE_SET_WREN => OS_STAGE_SET_WREN,
    DPS_WREN => DPS_WREN, 
    DPS_WE   => DPS_WE,
    
    Z00_OS   => ZN4_OS,
    ZN2_DONENESS => ZN6_OS_DONENESS,
    RATE_DRAW  => RATE_DRAW,
    ZN6_COMPUTED_ENVELOPE  => LFO_DUMMY,
    beginMeasure => beginMeasure, 
    
    initRam100      => initRam100,
    ram_rst100   => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
);

i_chowning: chowning Port map ( 
    clk100       => clk100,
    
    ADDR         => ADDR,
    
    MEM_IN       => MEM_IN1,
    MEM_IN25     => MEM_IN25,
    MEM_WRADDR   => MEM_WRADDR,
    OSC_INCTARGET_RATE_WREN => OSC_INCTARGET_RATE_WREN,
    OSC_VOL_WREN     => OSC_VOL_WREN,
    OSC_MODAMP_WREN  => OSC_MODAMP_WREN,
    OSC_DETUNE_WREN  => OSC_DETUNE_WREN,
    
    OSC_RINGMOD     => OSC_RINGMOD,
    OSC_HARMONICITY_WREN => OSC_HARMONICITY_WREN,
    OSC_HARMONICITY_ALPHA_WREN => OSC_HARMONICITY_ALPHA_WREN,
    PITCH_SHIFT    => PITCH_SHIFT,
    DETUNE_RATIO   => DETUNE_RATIO, 
    UNISON_VOICES_LOG2 => UNISON_VOICES_LOG2,
    
    OSC_MODAMP_DRAW  => OSC_MODAMP_DRAW,
    OSC_INC_DRAW     => OSC_INC_DRAW,
    OSC_VOL_DRAW     => OSC_VOL_DRAW,
    OSC_DETUNE_DRAW  => OSC_DETUNE_DRAW,
    PITCH_SHIFT_DRAW=> PITCH_SHIFT_DRAW,
    
    Z01_OS  => OS_PROPAGATE(0),
    Z01_COMPUTED_ENVELOPE => LFO_DUMMY,
    
    Z16_OSC_OUT  => Z16_OSC_OUT,
        
    initRam100      => initRam100,
    ram_rst100   => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
);

i_envelopes: envelopes Port Map(    
    clk100     => clk100,
    
    MEM_WRADDR    => MEM_WRADDR,
    MEM_IN        => MEM_IN1,
    ZN12_ADDR      => ADDR(ZN12 + 16),
    VOICE_ENVVAL_WREN => VOICE_ENVVAL_WREN,
    
    Z01_ENV_OUT => Z17_ENV_OUT,
    Z00_ENV_IN  => Z16_OSC_OUT, -- 16 clk difference
    
    UNISON_MIDPOINT    => UNISON_MIDPOINT,
    UNISON_ENDPOINT    => UNISON_ENDPOINT,
    UNISON_VOICES_LOG2 => UNISON_VOICES_LOG2,
        
    ZN6_OS      => OS_PROPAGATE((-6 + 16)/4), 
    ZN6_COMPUTED_ENVELOPE => LFO_DUMMY,
    
    VOICE_ENV_DRAW =>VOICE_ENV_DRAW,
    
    ram_rst100    => ram_rst100,
    initRam100       => initRam100,
    OUTSAMPLEF_ALMOSTFULL  => OUTSAMPLEF_ALMOSTFULL
);

i_interpolate_oversample_4: interpolate_oversample_4 Port map( 
    clk100      => clk100,

    ZN1_ADDR      => ADDR(Z16),
    Z01_INTERP_OUT=> Z18_INTERP_OUT,
    Z00_INTERP_IN => Z17_ENV_OUT,
    
    ram_rst100    => ram_rst100,
    initRam100       => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
    
i_note_svf: note_svf Port map(
    clk100        => clk100,
    ZN5_ADDR      => ADDR(-5 + 18),
            
    Z20_FILTER_OUT=> Z38_FILT_OUT, -- 20 + 18 = 38
    Z00_FILTER_IN => Z18_INTERP_OUT, -- 18 CLK Difference
    
    Z05_OS   => OS_PROPAGATE((5 + 18)/4),
    Z05_COMPUTED_ENVELOPE => LFO_DUMMY,
    
    MEM_WRADDR    => MEM_WRADDR,
    MEM_IN        => MEM_IN1,
    VOICE_FILTQ_WREN => VOICE_FILTQ_WREN,
    VOICE_FILTF_WREN => VOICE_FILTF_WREN,
    FILT_FDRAW    => FILT_FDRAW,
    FILT_QDRAW    => FILT_QDRAW,
    FILT_FTYPE    => FILT_FTYPE,
    
    ram_rst100    => ram_rst100,
    initRam100       => initRam100,
    OUTSAMPLEF_ALMOSTFULL  => OUTSAMPLEF_ALMOSTFULL
);

i_instrument_sum: instrument_sum Port Map(        
    clk100         => clk100,
    Z00_IN_ADDR    => ADDR(Z38), 
    Z00_INSTSUM_IN => Z38_FILT_OUT, 
    ZN7_ABS_ADDR   => ADDR(ZN7),
    Z00_INSTSUM_OUT=> Z00_INSTSUM_OUT,
    
    VOICE_SHIFT     => VOICE_SHIFT,
    INSTVOL_VAL     => INSTVOL_VAL,
    
    initRam100      => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
           
i_schroeder_allpass: SCHROEDER_ALLPASS 
Port map ( 
    clk100        => clk100,
    ZN8_ADDR      => ADDR(ZN8),
    
    DELAY_SAMPLES => DELAY_SAMPLES,
    DELAY_SAMPLES_DRAW => DELAY_SAMPLES_DRAW,
    MEM_IN        => MEM_IN1,
    MEM_WRADDR    => MEM_WRADDR, 
    GAIN_WREN     => GAIN_WREN, 
    
    Z00_schroeder_IN  => Z00_INSTSUM_OUT,
    Z12_schroeder_OUT => Z12_ALLPASS_OUT, 
        
    ZN2_OS  => ZN4_OS,
    ZN2_COMPUTED_ENVELOPE => LFO_DUMMY,
        
    ram_rst100      => ram_rst100,
    initRam100         => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );

i_note_panning: note_panning Port map(
    clk100        => clk100,
    INST_SHIFT   => INST_SHIFT,
    
    ZN3_ADDR_ABS  => ADDR(ZN3),
    ZN2_ADDR      => ADDR(Z12 - 2),
        
    Z00_PANNING_IN  => Z12_ALLPASS_OUT,
    OUTSAMPLEF_DI   => OUTFIFO_PROBE,
    OUTSAMPLEF_WREN => OUTFIFOWREN_PROBE,
    
    ZN2_ONESHOT   => OS_PROPAGATE(Z00),
    ZN2_COMPUTED_ENVELOPE   => LFO_DUMMY,
    
    VOICE_PAN_DRAW=> VOICE_PAN_DRAW,
    VOICE_PAN => VOICE_PAN,
    
    ram_rst100      => ram_rst100,
    initRam100       => initRam100,
    OUTSAMPLEF_ALMOSTFULL  => OUTSAMPLEF_ALMOSTFULL
);

timing_proc: process(clk100) begin
    if rising_edge(clk100) then
        INSAMPLEF_RDEN <= '0';
        
        SAMPLES_PER_DIV_DO_last <= SAMPLES_PER_DIV_DO;
        if SAMPLES_PER_DIV_DO_last /= SAMPLES_PER_DIV_DO then 
            if SAMPLES_PER_DIV_DO(std_flowwidth) = '1' then
                beginMeasure <= '1';
                bmADDR <= ADDR(0);
            else
                SAMPLES_PER_DIV <= SAMPLES_PER_DIV_DO(std_flowwidth-1 downto 0);
            end if;
        end if;
        
        -- leave Begin Measure up for an entire cycle
        if bmADDR = ADDR(0) then
            beginMeasure <= '0';
        end if;
        
        if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
            if Z00_timeDiv = 3 then
            
                OS_PROPAGATE(OS_PROPAGATE'low) <= ZN4_OS;
                for i in OS_PROPAGATE'low + 1 to OS_PROPAGATE'high loop
                    OS_PROPAGATE(i) <= OS_PROPAGATE(i-1);
                end loop;
            end if;
            
            ADDR(ADDR'low) <= ADDR(ADDR'low) + 1;
            for iteration in ADDR'low+1 to ADDR'high loop
                ADDR(iteration) <= ADDR(iteration-1);
            end loop;
            
            -- the following code reads 2 samples 
            -- (1 from each usb in channel)
            -- every 1024-clock cycle
            -- provided buffer is not almostempty
            if (signed(ADDR(-1)) = 0 or signed(ADDR(0)) = 0) and INSAMPLEF_ALMOSTEMPTY = '0' then
                INSAMPLEF_RDEN <= '1';
            end if;
        end if;
    end if;
end process;


-- interpret infifo into parameter changes
infifo_proc: process(clk100) begin
if rising_edge(clk100) then
    ZN7_currinst <= to_integer(ADDR(ZN8)(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
    ZN6_currinst <= to_integer(ADDR(ZN7)(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
    ZN6_ADDR_uFixed <= ufixed(ADDR(ZN7));

    -- clear all writes
    OSC_INCTARGET_RATE_WREN<= '0';
    VOICE_ENVVAL_WREN <= '0';
    OSC_VOL_WREN      <= '0';
    OSC_DETUNE_WREN   <= '0';
    VOICE_FILTQ_WREN  <= '0';
    VOICE_FILTF_WREN  <= '0';
    ONESHOTRATE_WREN  <= (others => '0');
    OS_STAGE_SET_WREN <= '0';
    OSC_HARMONICITY_WREN <= '0';
    OSC_HARMONICITY_ALPHA_WREN <= '0';
    OSC_MODAMP_WREN <= (others=>'0');
    GAIN_WREN <= '0';
    DPS_WREN <= '0';
    DPS_WE <= (others=>'0');
    voiceTag_WREN <= '0';
    FIRST_CLOCK_IN_IDLE <= "11";
    
    case(paramstate) is
    when s_idle =>
        FIRST_CLOCK_IN_IDLE <= FIRST_CLOCK_IN_IDLE(0) & '0';
    
        -- count up to 32 if inparamfifo not empty
        -- to allow buffer to fill on input side
        if INPARAMF_EMPTY = '0' and initRam100 = '0' then
            PARAMREAD_DELAYCOUNT <= PARAMREAD_DELAYCOUNT+1;
        end if;
        
        if PARAMREAD_DELAYCOUNT > 16 and INPARAMF_EMPTY = '0' then
            PARAMREAD_DELAYCOUNT <= 0;
            INPARAMF_RDEN <= '1';
            paramstate   <= s_wait_noread;
            paramstate_next <= s_readParamNo;
        end if; 
        
        
        ZN7_voiceTag_RDADDR <= std_logic_vector(ADDR(ZN8));
        -- search for ARMED voices where the OS has begun, and disarm them
        if ZN6_voiceTag_DO(VOICE_ARMED) = '1' and FIRST_CLOCK_IN_IDLE = "00" then
            -- if envelope has begun disarm it
            if ZN6_OS_DONENESS > 0 then
                VOICEIN <= ZN6_voiceTag_DO;
                VOICEIN(VOICE_ARMED) <= '0';
                voiceTag_WREN <= '1';
                donestAddress <= std_logic_vector(ADDR(ZN6)); -- donestAddress is the write address
            end if;
        end if;

    when s_wait_noread => 
        paramstate <= paramstate_next;
        INPARAMF_RDEN <= '0';
    when s_wait => 
        if paramstate_next = s_setVoices then
            ZN7_voiceTag_RDADDR <= std_logic_vector(unsigned(ZN7_voiceTag_RDADDR) + 4);
            ZN6_voiceTag_RDADDR <= ZN7_voiceTag_RDADDR;
        end if; 
        paramstate <= paramstate_next;
    when s_readParamNo => 
        -- if this read was sync bit, read A3,
        -- and continute to read A2 after a wait
        if INPARAMF_DO(INPARAMF_DO'high) = '1' then
            INPARAMF_RDEN <= '1';
            paramno <= unsigned(INPARAMF_DO(12 downto 0));
            isdraw  <= INPARAMF_DO(13);
            paramstate <= s_wait;
            paramstate_next <= s_readInstNo;
            PARAM_RDCOUNT <=  PARAM_RDCOUNT + 1;
        else
            paramstate <= s_idle;
        end if;
    when s_readInstNo => 
        INSTNO <= unsigned(INPARAMF_DO(instcountlog2-1 downto 0));
        INSTNO_i <= to_integer(unsigned(INPARAMF_DO(14 downto 0)));
        paramstate <= s_readVoiceNo;
    when s_readVoiceNo => 
        VOICENO <= INPARAMF_DO(GPIF_WIDTH -2 downto 0);
        paramstate <= s_readA1;
    when s_readA1 => 
        paramA1 <= to_integer(unsigned(INPARAMF_DO(9 downto 0)));
        paramA1_low2 <= INPARAMF_DO(1 downto 0);
        paramstate <= s_readA0;
    when s_readA0 => 
        paramA0 <= to_integer(unsigned(INPARAMF_DO(9 downto 0)));
        paramstate <= s_readPL2;
    when s_readPL2 => 
        BY_TAG  <= INPARAMF_DO(8);
        ALL_VOICES  <= INPARAMF_DO(9);
        OPTIONS_TYPE<= INPARAMF_DO(14 downto 11);
        paramstate <= s_readPL1;
    when s_readPL1 => 
        MEM_IN25(24 downto 15) <= INPARAMF_DO(9 downto 0);
        MEM_IN0 (17 downto 15) <= INPARAMF_DO(2 downto 0);
        MEM_IN1 (17 downto 15) <= INPARAMF_DO(2 downto 0);
        
        INPARAMF_RDEN <= '0';
        paramstate <= s_readPL0;
        
    when s_readPL0=>
        DRAW_IN <= unsigned(INPARAMF_DO(DRAWSLOG2 - 1 downto 0));
        MEM_IN25(14 downto 0)  <= INPARAMF_DO(14 downto 0);
        MEM_IN0 (14 downto 0)  <= INPARAMF_DO(14 downto 0);
        MEM_IN1 (14 downto 0)  <= INPARAMF_DO(14 downto 0);
        paramstate <= s_apply;
    
    when s_apply=>
        -- many parameters are not voice-independant,
        -- including all draw parameters
        -- so idle state will normally be next
        paramstate <= s_idle;
        
        -- deal with draws case separately
        if unsigned(OPTIONS_TYPE) = OPTIONS_DRAW then
            case(to_integer(paramno)) is
            when P_VOICE_INC =>
                OSC_INC_DRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when P_VOICE_ENV      =>
                VOICE_ENV_DRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when P_VOICE_PAN     =>
                VOICE_PAN_DRAW(INSTNO_i, paramA1, paramA0) <= DRAW_IN;
            when P_VOICE_FILT_Q =>
                FILT_QDRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when P_VOICE_FILT_F =>
                FILT_FDRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when P_OSC_DETUNE   =>
                OSC_DETUNE_DRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when P_OSC_MODAMP   =>
                OSC_MODAMP_DRAW(INSTNO_i, paramA1, paramA0) <= DRAW_IN;
            when P_OSC_VOLUME   =>
                OSC_VOL_DRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when P_ONESHOT_RATE       => 
                RATE_DRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when P_INST_DET =>
                PITCH_SHIFT_DRAW(INSTNO_i) <= DRAW_IN;
            when P_DELAY_SAMPLES    =>
                DELAY_SAMPLES_DRAW(INSTNO_i, paramA1) <= DRAW_IN;
            when others=>
                -- assume no draw is voice-independant
            end case;
        else
            
            case(to_integer(paramno)) is
            when P_VOICESHIFT       => 
                VOICE_SHIFT(INSTNO_i) <= to_integer(unsigned(MEM_IN0(voicesperinstlog2 downto 0)));   
            when P_VOICE_PAN        =>
                VOICE_PAN(INSTNO_i, paramA1, paramA0)  <= signed(MEM_IN1);
            when P_VOICE_UNISON   =>
                UNISON_VOICES_LOG2(INSTNO_i) <= to_integer(unsigned(MEM_IN1));
            when P_VOICE_UNISON_DET=>
                DETUNE_RATIO(INSTNO_i, paramA1) <= signed(MEM_IN1);
            when P_VOICE_UNISON_MIDPOINT=>
                if paramA1 = 0 then 
                    UNISON_MIDPOINT(INSTNO_i) <=  signed(MEM_IN0);
                else
                    UNISON_ENDPOINT(INSTNO_i) <=  signed(MEM_IN0);
                end if;
            when P_VOICE_FILT_TYP =>
                FILT_FTYPE(INSTNO_i, paramA1) <= to_integer(unsigned(MEM_IN1(ftypeslog2-1 downto 0)));
            when P_VOICE_SPAWN =>
                -- start reading the tags, so we can test for validity
                ZN7_voiceTag_RDADDR <= std_logic_vector(ADDR(ZN8));
                voiceTag_RDEN <= '1';
                -- wait for this read
                paramstate <= s_wait;
                paramstate_next <= s_spawnVoicesWait;
                -- reset wraddr to 0
                MEM_WRADDR <= (others=>'0');
            
            when P_OSC_RINGMOD     =>
                OSC_RINGMOD(INSTNO_i, paramA1) <= unsigned(MEM_IN1(oscpervoice-1 downto 0));
                
            when P_ONESHOT_STARTPOINT_Y =>
                ONESHOT_STARTPOINT_Y(INSTNO_i, paramA1, paramA0) <= signed(MEM_IN0);
            when P_ONESHOT_MIDPOINT_Y   =>
                ONESHOT_MIDPOINT_Y(INSTNO_i, paramA1, paramA0) <= signed(MEM_IN0);
              
            when P_DELAY_SAMPLES      =>
                DELAY_SAMPLES(INSTNO_i, paramA1) <= unsigned(MEM_IN1);
            when P_SAP_FB_GAIN        =>
                GAIN_WREN <= '1';
                MEM_WRADDR <= (others=>'0');
                MEM_WRADDR(3 downto 2) <= std_logic_vector(to_unsigned(paramA1,2));
                MEM_WRADDR(1 downto 0) <= FBGAIN_ADDR;
            when P_SAP_COLOR_GAIN     =>
                GAIN_WREN <= '1';
                MEM_WRADDR <= (others=>'0');
                MEM_WRADDR(3 downto 2) <= std_logic_vector(to_unsigned(paramA1,2));
                MEM_WRADDR(1 downto 0) <= COLORGAIN_ADDR;
            when P_SAP_FORWARD_GAIN   =>
                GAIN_WREN <= '1';
                MEM_WRADDR <= (others=>'0');
                MEM_WRADDR(3 downto 2) <= std_logic_vector(to_unsigned(paramA1,2));
                MEM_WRADDR(1 downto 0) <= FORWARDGAIN_ADDR;
            when P_SAP_INPUT_GAIN     =>
           
            when P_INSTVOL    =>
                INSTVOL_VAL(INSTNO_i, paramA1)  <= signed(MEM_IN1);
            when P_INST_DET   =>
                PITCH_SHIFT(INSTNO_i)  <= signed(MEM_IN1);
            when P_INSTSHIFT      =>
                INST_SHIFT <= to_integer(unsigned(MEM_IN0));  
             
            -- CLEAR EVERYTHING!!!
            when P_INIT      =>
                MEM_WRADDR <= (others=>'0');   
                MEM_IN36 <= (others=>'0'); 
                MEM_IN25 <= (others=>'0');
                MEM_IN0  <= (others=>'0');
                MEM_IN1  <= (others=>'0');
                
                -- instrument-independant formative mux signals
                OSC_RINGMOD   <= (others=>(others=>(others=>'0')));
                OSC_DETUNE_WREN     <= '0';
                OSC_DETUNE_DRAW     <= (others=>(others=>(others=>'0')));
                OSC_HARMONICITY_WREN    <= '0';
                OSC_HARMONICITY_ALPHA_WREN   <= '0';
                
                -- instrument-independant effects mux signals
                PITCH_SHIFT_DRAW    <= (others=>(others=>'0'));
                PITCH_SHIFT    <= (others=>"000100000000000000");
                
                DETUNE_RATIO         <= (others=>(others=>(others=>'0')));
                UNISON_VOICES_LOG2   <= (others=>0);
                UNISON_MIDPOINT      <= (others=>(others=>'0'));
                UNISON_ENDPOINT      <= (others=>(others=>'0'));
                    
                OSC_INC_DRAW        <= (others=>(others=>(others=>'0')));  
                OSC_MODAMP_DRAW     <= (others=>(others=>(others=>(others=>'0'))));
                OSC_VOL_DRAW        <= (others=>(others=>(others=>'0')));  
                
                VOICE_ENV_DRAW     <= (others=>(others=>(others=>'0')));  
                VOICE_PAN_DRAW     <= (others=>(others=>(others=>(others=>'0'))));
                VOICE_PAN    <= (others=>(others=>(others=>(others=>'0'))));
                
                -- instrument-independant internal modulator control signals
                FILT_FDRAW       <= (others=>(others=>(others=>'0')));  
                FILT_QDRAW       <= (others=>(others=>(others=>'0')));  
                FILT_FTYPE      <= (others=>(others=>0));  
                ONESHOT_STARTPOINT_Y   <= (others=>(others=>(others=>(others=>'0'))));
                ONESHOT_MIDPOINT_Y   <= (others=>(others=>(others=>(others=>'0'))));
                --ONESHOT_SUSTAINSTAGE  insts_by_oneshotspervoice_by_stagecount <= (others=>(others=>"10"));
                    
                -- parameters for ALLPASS can be set for REVERBDELAYPHASERFLANGER
                DELAY_SAMPLES        <= (others=>(others=>(others=>'0')));
                DELAY_SAMPLES_DRAW   <= (others=>(others=>(others=>'0')));
                    
                INSTVOL_VAL          <= (others=>(others=>(others=>'0')));
                paramstate <= s_patchinit;
                
                
            -- sysparams explicitly ignored here
            when P_NULL       =>
            when P_TEMPO      =>
            when P_BEATCOUNT  =>
            when P_SOF        =>
            when P_BEATPULSE  =>
                
            when others =>
                -- normally, voices are referenced by tag
                if BY_TAG = '1' then
                    -- reset wraddr to 0
                    MEM_WRADDR <= (others=>'0');
                    -- read that tag
                    voiceTag_RDEN <= '1';
                    -- wait for this read
                    paramstate <= s_wait;
                    paramstate_next <= s_setVoices;
                    -- start voice at first in this instrument
                    ZN7_voiceTag_RDADDR <= (others=>'0');
                    ZN7_voiceTag_RDADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-INSTCOUNTLOG2) <= std_logic_vector(INSTNO);
                else
                    paramstate <= s_setVoices;
                end if;
                
                -- prepare the max voice
                VOICE_COUNTDOWN <= (others=>'0');
                VOICE_COUNTDOWN(VOICE_SHIFT(INSTNO_i)) <= '1';
            end case;
        end if;
    
    when s_setVoices=>
        -- only go so far as voices in use
        VOICE_COUNTDOWN <= VOICE_COUNTDOWN -1;
    
        -- increase this voice by 4
        ZN7_voiceTag_RDADDR <= std_logic_vector(unsigned(ZN7_voiceTag_RDADDR) + 4);
        ZN6_voiceTag_RDADDR <= ZN7_voiceTag_RDADDR;
        if BY_TAG = '1' then
            MEM_WRADDR <= ZN6_voiceTag_RDADDR;
        end if;
    
        -- apply to this voice if ALL_VOICES is set, or tag matches and is valid, or by_tag is false
        if ALL_VOICES = '1' or (ZN6_voiceTag_DO(GPIF_WIDTH -2 downto 0) = VOICENO and ZN6_voiceTag_DO(VOICE_VALID) = '1') or BY_TAG = '0' then
            
            case(to_integer(paramno)) is
            
            when P_VOICE_INC   =>
                MEM_WRADDR(1 downto 0) <= "00";
                OSC_INCTARGET_RATE_WREN <= '1';
            when P_VOICE_ENV        =>
                -- lowest address bits indicate envnum
                MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(paramA1, envspervoicelog2));     
                VOICE_ENVVAL_WREN <= '1';
            when P_VOICE_PORTRATE =>
                MEM_WRADDR(1 downto 0) <= "01";
                OSC_INCTARGET_RATE_WREN <= '1';
            when P_VOICE_FILT_Q   =>
                MEM_WRADDR <= std_logic_vector(unsigned(MEM_WRADDR) + fivetimes(paramA1));
                VOICE_FILTQ_WREN <= '1';
            when P_VOICE_FILT_F   =>
                MEM_WRADDR <= std_logic_vector(unsigned(MEM_WRADDR) + fivetimes(paramA1));
                VOICE_FILTF_WREN <= '1';
            
            when P_OSC_DETUNE     =>
                MEM_WRADDR(1 downto 0) <= paramA1_low2;
                OSC_DETUNE_WREN <= '1';
            when P_OSC_MODAMP     =>
                MEM_WRADDR(1 downto 0) <= paramA1_low2;
                OSC_MODAMP_WREN(paramA0) <= '1';
            when P_OSC_VOLUME     =>
                MEM_WRADDR(1 downto 0) <= paramA1_low2;
                OSC_VOL_WREN <= '1';
            when P_OSC_WAVEFORM   =>
            when P_OSC_HARMONICITY =>
                MEM_WRADDR(1 downto 0) <= paramA1_low2;
                OSC_HARMONICITY_WREN <= '1';
            when P_OSC_HARMONICITY_A  =>
                MEM_WRADDR(1 downto 0) <= paramA1_low2;
                OSC_HARMONICITY_ALPHA_WREN <= '1';
            when P_ONESHOT_STAGESET     =>
                --   stage[2] inst[2] voice[6] os[2]
                -- where VOICE is indicated by MEM_WRADDR
                MEM_IN0 <= (others=>'0'); 
                MEM_IN0(11 downto 0 ) <= 
                    MEM_IN1(1 downto 0) &
                    std_logic_vector(instno(instcountlog2-1 downto 0)) & 
                    ZN6_voiceTag_RDADDR(voicesperinstlog2+1 downto 2) & -- need ro pull one address early, because of clock in assignment
                    std_logic_vector(to_unsigned(paramA1, OScountlog2)); 
                OS_STAGE_SET_WREN <= '1';
            when P_ONESHOT_RATE         =>
                -- low 2 address bits should indicate osnum
                MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(paramA1, OScountlog2));    
                -- paramA0 indicates stage
                ONESHOTRATE_WREN(paramA0) <= '1';
            when P_ONESHOT_DIVSPERSTAGE =>
                -- A0 : stage
                -- A1 : oneshotnum
                MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(paramA1, OScountlog2));     
                DPS_WE(paramA0) <= '1';
                case paramA0 is
                when 0 =>
                    MEM_IN36(8  downto  0) <= MEM_IN1(8  downto  0);
                when 1 => 
                    MEM_IN36(17 downto  9) <= MEM_IN1(8  downto  0);
                when 2 => 
                    MEM_IN36(26 downto 18) <= MEM_IN1(8  downto  0);
                when others =>
                    MEM_IN36(35 downto 27) <= MEM_IN1(8  downto  0);
                end case;
                DPS_WREN <= '1';
           
            when others =>
                -- explicitly do nothing
            end case;
        end if; 
        
        -- break if we've exceeded voice count, or direct set
        if VOICE_COUNTDOWN = to_unsigned(1, voicecountlog2 + 2) or BY_TAG = '0' then
            paramstate <= s_idle;
        end if;
             
        
    when s_spawnVoicesWait =>
        -- wait until OS addr is right before [INST & currvoice]
        if ADDR(ZN7) = unsigned(INSTNO) & "00000000" then
            -- we will only be testing voices which begin a unison
            -- to this end, the address will be shifted left by the unisonvoiceslog2
            -- prepare shift amount
            ZN6_LEFTSHIFT   <= INSTCOUNTLOG2 + voicesperinstlog2 - UNISON_VOICES_LOG2(ZN7_currInst);
            -- advance to test state
            paramstate <= s_spawnVoicesTest;
            -- reset donestvalue
            donestValue <= (others=>'0');
            -- and address
            donestAddress <= (others=>'0');
            donestAddress(ramaddr_width -1 downto ramaddr_width - instcountlog2) <= std_logic_vector(INSTNO);
            -- prepare the max voice
            VOICE_COUNTDOWN <= (others=>'0');
            VOICE_COUNTDOWN(VOICE_SHIFT(ZN7_currInst) + 2) <= '1'; -- +2 because voices are every 4th addr
            
        end if;       
        
        -- synchronize read address to ADDR
        ZN7_voiceTag_RDADDR <= std_logic_vector(ADDR(ZN8));
         
    when s_spawnVoicesTest =>
        VOICE_COUNTDOWN <= VOICE_COUNTDOWN -1;
                
        -- synchronize rdaddr to addr
        ZN7_voiceTag_RDADDR <= std_logic_vector(ADDR(ZN8));
                
        -- if OS addr indicates a unison-beginning voice, then check its doneness
        -- this complex instruction tests ZN6_ADDR_uFixed(unisonvoiceslog2-1 downto 0)
        -- to see if this voice begins a unison
        -- because vhdl doesnt allow variable length source operands 
            
        
        -- if this voicetag is already present and valid, break without claiming another
        if ZN6_voiceTag_DO(VOICE_VALID) = '1' and ZN6_voiceTag_DO(GPIF_WIDTH-2 downto 0) = VOICENO then 
            paramstate <= s_idle;
            
        -- if this is a unison-beginning voice and not armed
        elsif ZN6_ADDR_uFixed sll ZN6_LEFTSHIFT = 0 and ZN6_voiceTag_DO(VOICE_ARMED) = '0' then
            -- simple iterative maximum
            if ZN6_OS_DONENESS > donestValue then
                donestValue <= ZN6_OS_DONENESS;
                donestAddress <= std_logic_vector(ADDR(ZN6)(RAMADDR_WIDTH -1 downto 0));
            
            -- a completely done voice is frozen at 0
            -- an invalid voice receives the same treatment
            elsif ((ZN6_OS_DONENESS = 0 or ZN6_voiceTag_DO(VOICE_VALID) = '0') and signed(donestValue) /= -1) then
                donestValue <= (others=>'1');
                donestAddress <= std_logic_vector(ADDR(ZN6)(RAMADDR_WIDTH -1 downto 0));
            end if;
        end if;
        
       
        -- if the declared voicecount is exceeded, move to claim state
        --if ADDR(ZN7)(ramaddr_width -1 downto ramaddr_width - instcountlog2) /= INSTNO then 
        if VOICE_COUNTDOWN = to_unsigned(1, voicecountlog2 + 2) then
            -- set VOICES_TO_SET to the unison count
            VOICES_TO_SET <= (others=>'0');
            VOICES_TO_SET(UNISON_VOICES_LOG2(instno_i)) <= '1';
            
            -- specify the correct voice
            VOICEIN(GPIF_WIDTH -2 downto 0) <= VOICENO;
            -- armed and valid
            VOICEIN(VOICE_ARMED) <= '1';
            VOICEIN(VOICE_VALID) <= '1';
                    
            paramstate <= s_spawnVoiceClaim;
            -- write it!
            voiceTag_WREN <= '1';
        end if;
        
    -- write TAG in unisoncount after donest address and return to idle
    when s_spawnVoiceClaim =>
        donestAddress <= std_logic_vector(unsigned(donestAddress) + 4);
        VOICES_TO_SET <= VOICES_TO_SET-1;
        voiceTag_WREN <= '1';
        
        -- move to idle when all voices have been set
        if VOICES_TO_SET = 1 then
            voiceTag_WREN <= '0';
            paramstate <= s_idle;
        end if;
        
    -- write 0s everywhere
    when s_patchinit => 
        MEM_WRADDR <= std_logic_vector(unsigned(MEM_WRADDR) + 1);
        OSC_INCTARGET_RATE_WREN<= '1';
        VOICE_ENVVAL_WREN <= '1';
        OSC_VOL_WREN      <= '1';
        OSC_DETUNE_WREN   <= '1';
        VOICE_FILTQ_WREN  <= '1';
        VOICE_FILTF_WREN  <= '1';
        ONESHOTRATE_WREN  <= (others => '1');
        --OS_STAGE_SET_WREN <= '1';
        OSC_HARMONICITY_WREN <= '1';
        OSC_HARMONICITY_ALPHA_WREN <= '1';
        OSC_MODAMP_WREN <= (others=>'1');
        GAIN_WREN <= '1';
        DPS_WREN <= '1';
        DPS_WE <= (others=>'1');
        voiceTag_WREN <= '1';
        
        if signed(MEM_WRADDR) = -2 then
            paramstate <= s_idle;
        end if; 
        
    when others =>
    end case;
end if;
end process;

end Behavioral;
