----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--FIFO_SYNC_MACRO : In order to incorporate this function into the design,
--     VHDL      : the following instance declaration needs to be placed
--   instance    : in the architecture body of the design code.  The
--  declaration  : (FIFO_SYNC_MACRO_inst) and/or the port declarations
--     code      : after the "=>" assignment maybe changed to properly
--               : reference and connect this function to the design.
--               : All inputs and outputs must be connected.

--    Library    : In addition to adding the instance declaration, a use
--  declaration  : statement for the UNISIM.vcomponents library needs to be
--      for      : added before the entity declaration.  This library
--    Xilinx     : contains the component declarations for all Xilinx
--   primitives  : primitives and points to the models that will be used
--               : for simulation.

--  Copy the following four statements and paste them before the
--  Entity declaration, unless they already exist.

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;


entity oneshots is
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
           
end oneshots;

architecture Behavioral of oneshots is

component ram_controller_36k_36 is
Port ( 
   DO             : out STD_LOGIC_VECTOR (35 downto 0);
   DI             : in  STD_LOGIC_VECTOR (35 downto 0);
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


COMPONENT div_gen_0
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tdata  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_dividend_tvalid: IN STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tuser : out STD_LOGIC_VECTOR ( 0 to 0 );
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

component bezier is
Port (
    clk100       : in STD_LOGIC;
    ZN5_Phase    : in std_logic_vector(STD_FLOWWIDTH - 1 downto 0);
        
    ZN3_STARTPOINT: in sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
    ZN3_ENDPOINT  : in sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
    -- midpoint needs to be doubled
    ZN3_MIDPOINT  : in sfixed(2 downto -RAM_WIDTH18 + 3) := (others=>'0');
    
    Z00_BEZIER_OUT: out std_logic_vector(ram_width18 - 1 downto 0);
    
    initRam100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

constant dub0unsigned : unsigned(1 downto 0) := "00";
constant dub0slv      : std_logic_vector(1 downto 0) := "00";

attribute mark_debug : string;
attribute keep : string;
signal osevent     : std_logic := '0';

signal N_ALMOSTEMPTY : std_logic;
signal N_ALMOSTFULL  : std_logic;
signal N_DO          : std_logic_vector (eventtag_width-1 downto 0);
signal N_EMPTY       : std_logic;
signal N_FULL        : std_logic;
signal N_RDCOUNT     : std_logic_vector (9 downto 0);
signal N_RDERR       : std_logic;
signal N_WRCOUNT     : std_logic_vector (9 downto 0);
signal N_WRERR       : std_logic;
signal ZN5_N_RDEN    : std_logic := '0';
signal ZN4_N_RDEN    : std_logic := '0';
signal ZN3_N_RDEN    : std_logic := '0';
signal N_READWAIT    : boolean := false;

signal ZN6_OS   : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal ZN5_OS   : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal ZN4_OS   : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal ZN6_OS_int  : std_logic_vector(RAM_WIDTH18 - 1 downto 0) := (others => '0');
signal ZN5_OS_int  : std_logic_vector(RAM_WIDTH18 - 1 downto 0) := (others => '0');
signal ZN4_OS_int  : std_logic_vector(RAM_WIDTH18 - 1 downto 0) := (others => '0');
signal ZN3_OS_int  : std_logic_vector(RAM_WIDTH18 - 1 downto 0) := (others => '0');
    
signal ZN5_PHASE_OUT  : std_logic_vector(STD_FLOWWIDTH - 1 downto 0) := (others=>'0');
signal ZN4_PHASE_OUT  : unsigned(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal ZN3_PHASE_IN   : std_logic_vector(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
attribute mark_debug of ZN3_PHASE_IN: signal is "true";
--attribute mark_debug of ZN3_PHASE_IN: signal is "true";
signal ZN3_PHASE_WREN : std_logic := '0';
attribute mark_debug of ZN3_PHASE_WREN: signal is "true";

signal ZN5_STARTPOINT: std_logic_vector(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal ZN4_STARTPOINT: signed(RAM_WIDTH18 -1 downto 0) := (others=>'0');
signal ZN3_STARTPOINT_WREN : std_logic := '0';
--attribute mark_debug of ZN3_STARTPOINT_WREN: signal is "true";

signal ZN3_STARTPOINT: sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
signal ZN3_ENDPOINT: sfixed(1 downto -RAM_WIDTH18 + 2) := (others=>'0');
-- midpoint needs to be doubled
signal ZN3_MIDPOINT: sfixed(2 downto -RAM_WIDTH18 + 3) := (others=>'0');

signal ZN4_PHASE_CANDIDATE: unsigned(STD_FLOWWIDTH -1 downto 0) := (others=>'0');

signal ZN7_STAGE_OUT : std_logic_vector(RAM_WIDTH18 - 1 downto 0) := (others=>'0');
signal ZN6_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal ZN5_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal ZN4_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal ZN3_STAGE_IN  : unsigned(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal ZN3_STAGE_WREN : std_logic :='0';
signal ZN3_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal ZN2_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal ZN1_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal Z00_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal Z01_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal Z02_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');
signal Z03_STAGE     : unsigned(stagecountlog2-1 downto 0) := (others=>'0');

signal RAM18_WE  : std_logic_vector(1 downto 0) := "11";
signal RAM36_WE  : STD_LOGIC_VECTOR (3 downto 0) := (others => '1');   
signal RAM_RDEN  : std_logic :='0';
signal RAM_REGCE : std_logic :='0';


type stagecount_by_ramwidth18 is array(0 to stagecount-1) of std_logic_vector(RAM_WIDTH18 - 1 downto 0);
signal ZN7_RATE_OUT   : stagecount_by_ramwidth18 := (others =>(others => '0'));
signal ZN6_RATE   : unsigned(RAM_WIDTH18 - 1 downto 0) := (others => '0');
signal ZN5_RATE   : unsigned(std_flowwidth - 1 downto 0) := (others => '0');


signal ZN36_DIVS_PER_STAGE    : ufixed(9 - 1 downto 0) := (others => '0');
signal ZN35_SAMPLES_PER_STAGE : ufixed(std_flowwidth - 1 downto 0) := (others => '0');


signal ZN4_WREN : std_logic := '0';
signal ZN7_OS_OUT  : std_logic_vector(ram_width18 - 1 downto 0) := (others=>'0');
signal Z00_OS_IN   : std_logic_vector(ram_width18 - 1 downto 0) := (others=>'0');
signal Z00_OS_WREN : std_logic := '0';

signal ZN4_currinst: integer range 0 to instcount-1 := 0;
signal ZN3_currinst: integer range 0 to instcount-1 := 0;

signal ZN7_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN6_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN5_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN4_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN3_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
attribute mark_debug of ZN3_ADDR: signal is "true";
signal ZN2_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN1_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal Z00_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN39_ADDR: unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN38_ADDR: unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
--constant WAIT_BETWEEN_UPDATE_LOG2: natural := 5;
----constant WAIT_BETWEEN_UPDATE_LOG2: natural := 1;
--signal ZN6_alpha : unsigned(WAIT_BETWEEN_UPDATE_LOG2 downto 0) := (others => '0');
--signal ZN5_alpha : unsigned(WAIT_BETWEEN_UPDATE_LOG2 downto 0) := (others => '0');
--signal ZN4_alpha : unsigned(WAIT_BETWEEN_UPDATE_LOG2 downto 0) := (others => '0');

signal ZN36_SAMPLES_PER_DIV : ufixed(std_flowwidth-1 downto 0) := (others => '0');

signal Z00_timeDiv: integer := 0;
signal Z01_timeDiv: integer := 0;
signal Z02_timeDiv: integer := 0;
signal Z03_timeDiv: integer := 0;

signal ALWAYSVALID: std_logic:= '1';
signal DIVOUT_VALID: std_logic:= '1';
signal UNITY_SHIFTED: std_logic_vector(32-1 downto 0) := std_logic_vector(to_unsigned(2**(std_flowwidth-2), 32)); 
signal ZN7_currInst : integer := 0;
signal ZN6_BEATLOCKED: std_logic_vector(std_flowwidth-1 downto 0) := (others=>'1'); 
signal ZN6_RATEDRAW : unsigned(drawslog2-1 downto 0) := (others => '0');
signal ZN5_RATEDRAW : unsigned(drawslog2-1 downto 0) := (others => '0');
signal ZN4_RATEDRAW : unsigned(drawslog2-1 downto 0) := (others => '0');

signal ZN6_DIV_BY_0 : STD_LOGIC_VECTOR ( 0 to 0 );
signal ZN35_s_axis_divisor_tdata     : std_logic_vector(31 downto 0) := (others => 'X');  -- TDATA for channel B
signal m_axis_dout_tdata  : std_logic_vector(31 downto 0) := (others => '0');  -- TDATA for channel DOUT

signal ZN37_DIVSPERSTAGE_DO : std_logic_vector(36-1 downto 0);
type DPS_ARRAY is array(0 to stagecount) of std_logic_vector(9-1 downto 0);
signal ZN37_DIVSPERSTAGE : DPS_ARRAY := (others=>(others=>'0'));

signal ZN38_STAGE_OUT : std_logic_vector(ram_width18 - 1 downto 0) := (others=>'0');
signal ZN3_TRIGGER : integer := 0;
begin

ZN37_DIVSPERSTAGE(0) <= ZN37_DIVSPERSTAGE_DO(8  downto  0);
ZN37_DIVSPERSTAGE(1) <= ZN37_DIVSPERSTAGE_DO(17 downto  9);
ZN37_DIVSPERSTAGE(2) <= ZN37_DIVSPERSTAGE_DO(26 downto 18);
ZN37_DIVSPERSTAGE(3) <= ZN37_DIVSPERSTAGE_DO(35 downto 27);

ZN7_currInst <= to_integer(ZN7_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));

ZN35_s_axis_divisor_tdata <= std_logic_vector(resize(unsigned(ZN35_SAMPLES_PER_STAGE), ZN35_s_axis_divisor_tdata'length));
ZN6_BEATLOCKED <= m_axis_dout_tdata(std_flowwidth-1 downto 0);


-- LATENCY : 29
division : div_gen_0
  PORT MAP (
    aclk => clk100,
    s_axis_divisor_tvalid => ALWAYSVALID,
    s_axis_divisor_tdata => ZN35_s_axis_divisor_tdata,
    s_axis_dividend_tvalid => ALWAYSVALID,
    s_axis_dividend_tdata => UNITY_SHIFTED,
    m_axis_dout_tvalid => DIVOUT_VALID,
    m_axis_dout_tuser => ZN6_DIV_BY_0,
    m_axis_dout_tdata => m_axis_dout_tdata
  );

i_bezier: bezier Port map(
    clk100       => clk100, 
    ZN5_Phase    => ZN5_Phase_out,
        
    ZN3_STARTPOINT=> ZN3_STARTPOINT,
    ZN3_ENDPOINT  => ZN3_ENDPOINT,
    -- midpoint needs to be doubled
    ZN3_MIDPOINT => ZN3_MIDPOINT,
    
    Z00_BEZIER_OUT => Z00_OS_IN,
    
    initRam100      => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
);

   -- FIFO_SYNC_MACRO: Synchronous First-In, First-Out (FIFO) RAM Buffer
   --                  Artix-7
   -- Xilinx HDL Language Template, version 2016.1

   -- Note -  This Unimacro model assumes the port directions to be "downto". 
   --         Simulation of this model with "to" in the port directions could lead to erroneous results.

   -----------------------------------------------------------------
   -- DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width --
   -- ===========|===========|============|=======================--
   --   37-72    |  "36Kb"   |     512    |         9-bit         --
   --   19-36    |  "36Kb"   |    1024    |        10-bit         --
   --   19-36    |  "18Kb"   |     512    |         9-bit         --
   --   10-18    |  "36Kb"   |    2048    |        11-bit         --
   --   10-18    |  "18Kb"   |    1024    |        10-bit         --
   --    5-9     |  "36Kb"   |    4096    |        12-bit         --
   --    5-9     |  "18Kb"   |    2048    |        11-bit         --
   --    1-4     |  "36Kb"   |    8192    |        13-bit         --
   --    1-4     |  "18Kb"   |    4096    |        12-bit         --
   
FIFO_SYNC_MACRO_inst : FIFO_SYNC_MACRO
   generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5, "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0080",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold
      DATA_WIDTH => 12,               -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb"
      FIFO_SIZE => "18Kb")            -- Target BRAM, "18Kb" or "36Kb" 
   port map (
      ALMOSTEMPTY => N_ALMOSTEMPTY,   -- 1-bit output almost empty
      ALMOSTFULL => N_ALMOSTFULL,     -- 1-bit output almost full
      DO => N_DO,                     -- Output data, width defined by DATA_WIDTH parameter
      EMPTY => N_EMPTY,               -- 1-bit output empty
      FULL => N_FULL,                 -- 1-bit output full
      RDCOUNT => N_RDCOUNT,           -- Output read count, width determined by FIFO depth
      RDERR => N_RDERR,               -- 1-bit output read error
      WRCOUNT => N_WRCOUNT,           -- Output write count, width determined by FIFO depth
      WRERR => N_WRERR,               -- 1-bit output write error
      CLK  => clk100,                  -- 1-bit input clock
      DI   => STD_LOGIC_VECTOR(MEM_IN(11 downto 0)),-- Input data, width defined by DATA_WIDTH parameter
      RDEN => ZN5_N_RDEN,                 -- 1-bit input read enable
      RST  =>  ram_rst100,              -- 1-bit input reset
      WREN => OS_STAGE_SET_WREN                 -- 1-bit input write enable
   );
   -- End of FIFO_SYNC_MACRO_inst instantiation


i_stage: ram_controller_18k_18 port map (
    DO         => ZN7_STAGE_OUT,
    DI         => std_logic_vector(ZN3_STAGE_IN),
    RDADDR     => std_logic_vector(ZN8_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(ZN3_ADDR),
    WRCLK      => clk100,
    WREN       => ZN3_STAGE_WREN
    );

i_stage_reposition: ram_controller_18k_18 port map (
    DO         => ZN38_STAGE_OUT,
    DI         => std_logic_vector(ZN3_STAGE_IN),
    RDADDR     => std_logic_vector(ZN39_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(ZN3_ADDR),
    WRCLK      => clk100,
    WREN       => ZN3_STAGE_WREN
    );
        
i_os_startpoint: ram_controller_18k_18 port map (
    DO         => ZN5_STARTPOINT,
    DI         => ZN3_OS_int, -- when changing states, refer to the last OS value as Y startpoint
    RDADDR     => std_logic_vector(ZN6_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(ZN3_ADDR),
    WRCLK      => clk100,
    WREN       => ZN3_STARTPOINT_WREN
    );
    
i_os_phase: ram_controller_36k_25 port map (
    DO         => ZN5_PHASE_OUT,
    DI         => ZN3_PHASE_IN,
    RDADDR     => std_logic_vector(ZN6_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM36_WE,
    WRADDR     => std_logic_vector(ZN3_ADDR),
    WRCLK      => clk100,
    WREN       => ZN3_PHASE_WREN
    );
        
i_OS_ram: ram_controller_18k_18 port map (
    DO         => ZN7_OS_OUT,
    DI         => Z00_OS_IN,
    RDADDR     => std_logic_vector(ZN8_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(Z00_ADDR),
    WRCLK      => clk100,
    WREN       => Z00_OS_WREN
);
   
i_divsperstage_ram: ram_controller_36k_36 port map (
    DO         => ZN37_DIVSPERSTAGE_DO,
    DI         => MEM_IN36,
    RDADDR     => std_logic_vector(ZN38_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => DPS_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => DPS_WREN
    );
        
STAGELOOP:
for stage in 0 to stagecount-1 generate
i_rate_ram: ram_controller_18k_18 port map (
    DO         => ZN7_RATE_OUT(stage),
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(ZN8_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => ONESHOTRATE_WREN(stage)
    );  

outproc: process(clk100)
begin
if rising_edge(clk100) then
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    ZN6_OS(Z01_timeDiv) <= signed(ZN7_OS_OUT);
    ZN5_OS <= ZN6_OS;
    ZN4_OS <= ZN5_OS;
end if;
end if;
end process;

end generate;
       
timingproc: process(clk100)
begin
if rising_edge(clk100) then    
    if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
        Z00_timeDiv <= to_integer(ZN1_ADDR(1 downto 0));
        Z01_timeDiv <= Z00_timeDiv;
        Z02_timeDiv <= Z01_timeDiv;
        Z03_timeDiv <= Z02_timeDiv;

        if Z00_timeDiv = 3 then
            Z00_OS <= ZN4_OS;
        end if;
        
        ZN6_STAGE <= unsigned(ZN7_STAGE_OUT(stagecountlog2-1 downto 0));
        ZN5_STAGE <= ZN6_STAGE;
        ZN4_STAGE <= ZN5_STAGE;
        ZN4_STARTPOINT <= signed(ZN5_STARTPOINT);
        ZN3_STAGE <= ZN4_STAGE;
        ZN2_STAGE <= ZN3_STAGE;
        ZN1_STAGE <= ZN2_STAGE;
        Z00_STAGE <= ZN1_STAGE;
        Z01_STAGE <= Z00_STAGE;
        Z02_STAGE <= Z01_STAGE;
        Z03_STAGE <= Z02_STAGE;
        
        if Z01_timeDiv = 0 then 
            ZN2_DONENESS <= ZN3_STAGE & unsigned(ZN3_PHASE_IN);
        end if;
        
        ZN39_ADDR <= ZN1_ADDR + 39;
        ZN38_ADDR <= ZN39_ADDR;
        ZN7_ADDR <= ZN8_ADDR;
        ZN6_ADDR <= ZN7_ADDR;
        ZN5_ADDR <= ZN6_ADDR;
        ZN4_ADDR <= ZN5_ADDR;
        ZN3_ADDR <= ZN4_ADDR;
        ZN2_ADDR <= ZN3_ADDR;
        ZN1_ADDR <= ZN2_ADDR;
        Z00_ADDR <= ZN1_ADDR;
        
        ZN4_currinst <= to_integer(ZN5_ADDR(RAMADDR_WIDTH-1 downto RAMADDR_WIDTH-instcountlog2));
        ZN3_currinst <= ZN4_currinst;

        ZN6_OS_int <= ZN7_OS_OUT;
        ZN5_OS_int <= ZN6_OS_int;
        ZN4_OS_int <= ZN5_OS_int;
        ZN3_OS_int <= ZN4_OS_int;
                
        ZN4_PHASE_OUT <= unsigned(ZN5_PHASE_OUT);
        
        ZN5_RATEDRAW <= ZN6_RATEDRAW;
        ZN4_RATEDRAW <= ZN5_RATEDRAW;
        
        ZN6_RATE <= unsigned(ZN7_RATE_OUT(to_integer(unsigned(ZN7_STAGE_OUT(stagecountlog2-1 downto 0)))));
    end if;
end if;
end process;
       
RAM_RDEN <= not OUTSAMPLEF_ALMOSTFULL;

phase_proc: process(clk100)
begin    
if rising_edge(clk100) then    
ZN3_STARTPOINT_WREN <= '0';
ZN3_PHASE_WREN <= '0';     
ZN3_STAGE_WREN <= '0';   

if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then

    -- this block of code manages events from the FIFO
    ZN4_N_RDEN <= ZN5_N_RDEN;        
    ZN3_N_RDEN <= ZN4_N_RDEN;
    --default : no read
    ZN5_N_RDEN <= '0';
    -- if not waiting for read and no event right now and buffer is nonempty
    if N_READWAIT = false and osevent = '0' and N_EMPTY = '0' then
        -- start a read and wait for it
        ZN5_N_RDEN <= '1';
        N_READWAIT <= true;
    end if;
    -- when the read arrives
    if ZN3_N_RDEN = '1' then
        -- declare an event
        osevent <= '1';
        N_READWAIT <= false;
    end if;
    
    
    -- we have SAMPLES /  DIV
    -- need to convert to INCREMENT / SAMPLE (RATE)
    -- given DIVS / STAGE
    -- such that IPS * SPD = COUNTERMAX / DPS
    -- samples per stage = (divs/stage) * (samples per div)
    -- IPS (rate) = COUNTERMAX / (SPS)
    
    ZN36_DIVS_PER_STAGE <= ufixed(ZN37_DIVSPERSTAGE(to_integer(unsigned(ZN38_STAGE_OUT(stagecountlog2-1 downto 0)))));
    ZN36_SAMPLES_PER_DIV <= ufixed(SAMPLES_PER_DIV);
    ZN35_SAMPLES_PER_STAGE <= resize(ZN36_DIVS_PER_STAGE * ZN36_SAMPLES_PER_DIV, ZN35_SAMPLES_PER_STAGE, fixed_wrap, fixed_truncate);
    -- ZN6_BEATLOCKED
    ZN6_RATEDRAW <= RATE_DRAW(ZN7_currInst, Z01_timeDiv);
    if ZN6_DIV_BY_0(0) = '0' then
        ZN5_RATE <= CHOOSEMOD4(ZN6_RATEDRAW, ZN6_RATE, unsigned(ZN6_BEATLOCKED), ZN6_OS, ZN6_COMPUTED_ENVELOPE);
    else
        ZN5_RATE <= CHOOSEMOD4(ZN6_RATEDRAW, ZN6_RATE, "0000000000000000000000000", ZN6_OS, ZN6_COMPUTED_ENVELOPE);
    end if;

    -- step 2: update phase
    ZN4_PHASE_CANDIDATE <= unsigned(ZN5_PHASE_OUT) + ZN5_RATE;
    
    --  usually save the candidate
    ZN3_PHASE_IN <= std_logic_vector(ZN4_PHASE_CANDIDATE);
    -- and maintain all stages
    ZN3_STAGE_IN(stagecountlog2-1 downto 0) <= ZN4_STAGE;

    ZN3_TRIGGER <= 0;
    -- step 3: reset stage and phase if indicated
    if beginMeasure = '1' and ZN4_RATEDRAW = DRAW_BEAT_I then
        -- reset to stage 0
        ZN3_STAGE_IN(stagecountlog2-1 downto 0) <= (others=>'0');
        -- reset phase to zero
        ZN3_PHASE_IN <= (others=>'0');
        -- set start y to current amplitude
        ZN3_STARTPOINT_WREN <= '1';
        
        ZN3_TRIGGER <= 1;
    
    elsif osevent = '1' and unsigned(N_DO(RAMADDR_WIDTH-1 downto 0)) = ZN4_ADDR then
        -- reset to requested stage
        ZN3_STAGE_IN(stagecountlog2-1 downto 0) <= unsigned(N_DO(11 downto 10));
        -- reset phase to zero
        ZN3_PHASE_IN <= (others=>'0');
        -- set start y to current amplitude
        ZN3_STARTPOINT_WREN <= '1';
        ZN3_TRIGGER <= 2;
        -- end event
        osevent <= '0';
    -- otherwise, reset to 0 if 
    -- reset phase and increment state when phase is about to overflow,
    -- and OSs are active
    elsif ZN4_PHASE_CANDIDATE < ZN4_PHASE_OUT then
        -- increase stage by one
        ZN3_STAGE_IN(stagecountlog2-1 downto 0) <= ZN4_STAGE + 1; 
        -- reset phase to zero
        ZN3_PHASE_IN <= (others=>'0');
        -- write this startpoint
        ZN3_STARTPOINT_WREN <= '1';
        ZN3_TRIGGER <= 3;
    end if;
    
    ZN3_STAGE_WREN <= '1';
    ZN3_PHASE_WREN <= '1';
end if;
end if;
end process;

bezier_proc: process(clk100)
begin    
if rising_edge(clk100) then    
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    -- send the appropriate points to bezier
    ZN3_STARTPOINT <= sfixed(ZN4_STARTPOINT);
    ZN3_ENDPOINT <= sfixed(ONESHOT_STARTPOINT_Y(ZN4_currinst, Z00_timeDiv, to_integer(ZN4_STAGE +1) mod stagecount));
    ZN3_MIDPOINT <= sfixed(ONESHOT_MIDPOINT_Y  (ZN4_currinst, Z00_timeDiv, to_integer(ZN4_STAGE)));
    
    Z00_OS_WREN <= '1';
end if;
end if;
end process;
end Behavioral;