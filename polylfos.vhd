----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Julian Juixxxe Loiacono
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library work;
use work.memory_word_type.all;

entity polylfos is

-- when draw is 1, least significant 2 bits of ALIGN, DEPTH, and INCREMENT are ZN4_OSZCD
Port ( 
    clk100               : in  STD_LOGIC;
    ZN6_ADDR             : in  unsigned(RAMADDR_WIDTH -1 downto 0);
    ZN4_OS            : in  oneshotspervoice_by_ramwidth18s;
    POLYLFOWAVEFORM      : in  insts_by_COMPUTED_ENVELOPESpervoice_by_wfcountlog2;
    POLYLFOALIGN_DRAW    : in  insts_by_COMPUTED_ENVELOPESpervoice_by_drawslog2;
    POLYLFODEPTH_DRAW    : in  insts_by_COMPUTED_ENVELOPESpervoice_by_drawslog2;
    POLYLFOINC_DRAW      : in  insts_by_COMPUTED_ENVELOPESpervoice_by_drawslog2;
    Z00_COMPUTED_ENVELOPE       : out inputcount_by_ramwidth18s := (others=>(others=>'0'));
    Z00       : out inputcount_by_ramwidth18s := (others=>(others=>'0'));
    ZN4_ZERO_CROSS       : in  std_logic;
    
    MEM_WRADDR           : in std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    MEM_IN               : in std_logic_vector(ram_width18-1 downto 0); 
    
    POLYLFOALIGN_WREN    : in std_logic;
    POLYLFO_INC_WREN     : in std_logic;
    POLYLFODEPTH_WREN    : in std_logic;
    
    initRam100              : in std_logic;
    ram_rst100           : in std_logic;
    OUTSAMPLEF_ALMOSTFULL: in std_logic
    );
end polylfos;


architecture Behavioral of polylfos is

component ram_controller_18k_18 is
Port ( 
   DO             : out STD_LOGIC_VECTOR (ram_width18-1 downto 0);
   DI             : in  STD_LOGIC_VECTOR (ram_width18-1 downto 0);
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

signal ZN5_ADDR :  unsigned(ramaddr_width-1 downto 0) := (others=>'0');
signal ZN4_ADDR :  unsigned(ramaddr_width-1 downto 0) := (others=>'0');
signal ZN3_ADDR :  unsigned(ramaddr_width-1 downto 0) := (others=>'0');
signal ZN2_ADDR : unsigned(ramaddr_width-1 downto 0) := (others=>'0');
signal ZN1_ADDR : unsigned(ramaddr_width-1 downto 0) := (others=>'0');
signal Z00_ADDR : unsigned(ramaddr_width-1 downto 0) := (others=>'0');

signal ZN3_COMPUTED_ENVELOPEALIGN       : std_logic_vector(ram_width18 -1 downto 0) := (others=>'0');
signal ZN4_COMPUTED_ENVELOPEINCREMENT: std_logic_vector(ram_width18 -1 downto 0) := (others=>'0');
signal ZN4_COMPUTED_ENVELOPEDEPTH    : std_logic_vector(ram_width18 -1 downto 0) := (others=>'0');

signal ZN4 : inputcount_by_ramwidth18s;
signal ZN3 : inputcount_by_ramwidth18s;
signal ZN4_COMPUTED_ENVELOPE : inputcount_by_ramwidth18s;

signal ZN4_COMPUTED_ENVELOPEphase     : signed(ram_width18-1 downto 0) := (others=>'0');
signal ZN3_COMPUTED_ENVELOPEbasewaveform : signed(ram_width18-1 downto 0) := (others=>'0');
signal ZN3_OS             : oneshotspervoice_by_ramwidth18s;
signal ZN2_COMPUTED_ENVELOPEalignbase : signed(ram_width18-1 downto 0) := (others=>'0');
signal ZN3_COMPUTED_ENVELOPEmultiplicand : signed(ram_width18-1 downto 0) := (others=>'0');
signal ZN2_COMPUTED_ENVELOPEafterdepth   : signed(ram_width18-1 downto 0) := (others=>'0');

signal RAM_REGCE   : std_logic := '0';
signal RAM_RDEN    : STD_LOGIC := '0';

signal ZN5_COMPUTED_ENVELOPE_PHASE   : STD_LOGIC_VECTOR(ram_width18 -1 downto 0) := (others=>'0');
signal ZN3_PHASE_IN  : signed (ram_width18-1 downto 0) := (others => '0');

signal ZN3_COMPUTED_ENVELOPEPHASE_WREN    : std_logic;
signal ZN1_COMPUTED_ENVELOPE_WF_WREN      : std_logic;

signal RAM18_WE   : STD_LOGIC_VECTOR (1 downto 0) := (others=>'1');   
   
signal ZN5_COMPUTED_ENVELOPE_OUT  : STD_LOGIC_VECTOR (ram_width18-1 downto 0) := (others => '0');
signal ZN4_COMPUTED_ENVELOPE_IN   : STD_LOGIC_VECTOR (ram_width18-1 downto 0) := (others => '0');

signal ZN5_OUT  : STD_LOGIC_VECTOR(ram_width18 -1 downto 0) := (others=>'0');
signal ZN1_IN   : STD_LOGIC_VECTOR (ram_width18-1 downto 0) := (others => '0');

signal ZN5_currinst  : integer range 0 to instcount - 1;
signal ZN4_currinst: integer range 0 to instcount - 1;
signal ZN3_currinst: integer range 0 to instcount - 1;

signal ZN4_isActive : unsigned(5 downto 0) := (others => '0');
signal ZN3_isActive : unsigned(5 downto 0) := (others => '0');
signal ZN2_isActive : unsigned(5 downto 0) := (others => '0');

signal Z00_timeDiv : integer := 0;
signal Z01_timeDiv : integer := 0;
signal Z02_timeDiv : integer := 0;
signal Z03_timeDiv : integer := 0;

begin
Z00_timeDiv <= to_integer(ZN4_ADDR(1 downto 0));

i_ZN4_COMPUTED_ENVELOPEincrement_ram: ram_controller_18k_18 
port map (
DO         => ZN4_COMPUTED_ENVELOPEINCREMENT,
DI         => MEM_IN,
RDADDR     => std_logic_vector(ZN5_ADDR),
RDCLK      => clk100,
RDEN       => RAM_RDEN,
REGCE      => RAM_REGCE,
RST        => ram_rst100,
WE         => RAM18_WE,
WRADDR     => MEM_WRADDR,
WRCLK      => clk100,
WREN       => POLYLFO_INC_WREN);

i_ZN4_COMPUTED_ENVELOPEdepth_ram: ram_controller_18k_18 
port map (
DO         => ZN4_COMPUTED_ENVELOPEDEPTH,
DI         => MEM_IN,
RDADDR     => std_logic_vector(ZN5_ADDR),
RDCLK      => clk100,
RDEN       => RAM_RDEN,
REGCE      => RAM_REGCE,
RST        => ram_rst100,
WE         => RAM18_WE,
WRADDR     => MEM_WRADDR,
WRCLK      => clk100,
WREN       => POLYLFODEPTH_WREN);

i_ZN4_COMPUTED_ENVELOPEalign_ram: ram_controller_18k_18 
port map (
DO         => ZN3_COMPUTED_ENVELOPEALIGN,
DI         => MEM_IN,
RDADDR     => std_logic_vector(ZN4_ADDR),
RDCLK      => clk100,
RDEN       => RAM_RDEN,
REGCE      => RAM_REGCE,
RST        => ram_rst100,
WE         => RAM18_WE,
WRADDR     => MEM_WRADDR,
WRCLK      => clk100,
WREN       => POLYLFOALIGN_WREN);

-- env. dependent ZN4_COMPUTED_ENVELOPEs
i_PHASE_ram: ram_controller_18k_18 
port map (
DO         => ZN5_COMPUTED_ENVELOPE_PHASE,
DI         => std_logic_vector(ZN3_PHASE_IN),
RDADDR     => std_logic_vector(ZN6_ADDR),
RDCLK      => clk100,
RDEN       => RAM_RDEN,
REGCE      => RAM_REGCE,
RST        => ram_rst100,
WE         => RAM18_WE,
WRADDR     => std_logic_vector(ZN3_ADDR),
WRCLK      => clk100,
WREN       => ZN3_COMPUTED_ENVELOPEPHASE_WREN);
  
-- env. dependent ZN4_COMPUTED_ENVELOPEs waveform, before zero-cross detection
i_COMPUTED_ENVELOPE_waveform: ram_controller_18k_18 
port map (
DO         => ZN5_OUT,
DI         => std_logic_vector(ZN1_IN),
RDADDR     => std_logic_vector(ZN6_ADDR),
RDCLK      => clk100,
RDEN       => RAM_RDEN,
REGCE      => RAM_REGCE,
RST        => ram_rst100,
WE         => RAM18_WE,
WRADDR     => std_logic_vector(ZN1_ADDR),
WRCLK      => clk100,
WREN       => ZN1_COMPUTED_ENVELOPE_WF_WREN);
    
-- env. dependent ZN4_COMPUTED_ENVELOPEs, updated on zero-cross
i_COMPUTED_ENVELOPE_ram: ram_controller_18k_18 
port map (
DO         => ZN5_COMPUTED_ENVELOPE_OUT,
DI         => ZN4_COMPUTED_ENVELOPE_IN,
RDADDR     => std_logic_vector(ZN6_ADDR),
RDCLK      => clk100,
RDEN       => RAM_RDEN,
REGCE      => RAM_REGCE,
RST        => ram_rst100,
WE         => RAM18_WE,
WRADDR     => std_logic_vector(ZN4_ADDR),
WRCLK      => clk100,
WREN       => ZN4_ZERO_CROSS);

zerocrossproc: process(clk100)
begin
if rising_edge(clk100) then
    if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
        
        case Z00_timeDiv is
        when 0 =>
            ZN4_COMPUTED_ENVELOPE(1) <= signed(ZN5_COMPUTED_ENVELOPE_OUT);
            ZN4(1) <= signed(ZN5_OUT);
        when 1 =>
            ZN4_COMPUTED_ENVELOPE(2) <= signed(ZN5_COMPUTED_ENVELOPE_OUT);
            ZN4(2) <= signed(ZN5_OUT);
        when 2 =>
            -- output the zcd amp directly
            ZN4_COMPUTED_ENVELOPE(3) <= signed(ZN5_COMPUTED_ENVELOPE_OUT);
            ZN4(3) <= signed(ZN5_OUT);
        when others =>
            ZN4_COMPUTED_ENVELOPE(0) <= signed(ZN5_COMPUTED_ENVELOPE_OUT);
            ZN4(0) <= signed(ZN5_OUT);
        end case;
    end if;
end if;
end process;


-- pipeline step 1: read phase
-- pipeline step 2: increment phase
-- pipeline step 3: convert to wave
-- pipeline step 4: multiply by depth
-- pipeline step 5: align as appropriate, write

timingproc: process(clk100)
begin
if rising_edge(clk100) then
    if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
        Z01_timeDiv <= Z00_timeDiv;
        Z02_timeDiv <= Z01_timeDiv;
        Z03_timeDiv <= Z02_timeDiv;
    
        if Z00_timeDiv = 3 then
            Z00_COMPUTED_ENVELOPE <= ZN4_COMPUTED_ENVELOPE;
            Z00 <= ZN4;
        end if;
        ZN3 <= ZN4;
        
        ZN4_COMPUTED_ENVELOPE_IN <= ZN5_OUT;
        
        ZN3_OS <= ZN4_OS;
              
        ZN5_ADDR <= ZN6_ADDR;
        ZN4_ADDR <= ZN5_ADDR;
        ZN3_ADDR <= ZN4_ADDR;
        ZN2_ADDR <= ZN3_ADDR;
        ZN1_ADDR <= ZN2_ADDR;
        Z00_ADDR <= ZN1_ADDR;
        
        ZN5_currinst <= to_integer(ZN6_ADDR(ZN6_ADDR'high downto ZN6_ADDR'length - instcountlog2));
        ZN4_currinst <= ZN5_currinst;
        ZN3_currinst <= ZN4_currinst;

        if ZN5_ADDR = 0 then
            ZN4_isActive <= ZN4_isActive + 1;
        end if;
        ZN3_isActive <= ZN4_isActive;
        ZN2_isActive <= ZN3_isActive;
        end if;
    end if;
end process;

-- enable reads
RAM_RDEN <= not OUTSAMPLEF_ALMOSTFULL;

POLYLFOsummer: process(clk100)
begin
if rising_edge(clk100) then
    if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    
    -- Step 1: read phase
    ZN4_COMPUTED_ENVELOPEphase <= signed(ZN5_COMPUTED_ENVELOPE_PHASE); 

    -- Step 2: increment the ZN4_COMPUTED_ENVELOPE phase, dependant on the draw of increment
    -- prepare to write to phase ram
    -- only write to the appropriate spot
    ZN3_COMPUTED_ENVELOPEPHASE_WREN <= '0';     
    if ZN4_isActive = 0 then     
        ZN3_COMPUTED_ENVELOPEPHASE_WREN <= '1';
    end if;
    
    ZN3_PHASE_IN <= ZN4_COMPUTED_ENVELOPEphase +
    CHOOSEMOD3(POLYLFOINC_DRAW(ZN4_currinst, Z00_timeDiv),
    signed(ZN4_COMPUTED_ENVELOPEINCREMENT), ZN4_OS, ZN4);
    
    -- output side: convert to wave, dependant only on the type
    ZN3_COMPUTED_ENVELOPEbasewaveform <= GETWF(POLYLFOWAVEFORM(ZN4_currinst, Z00_timeDiv), ZN4_COMPUTED_ENVELOPEphase);
    
    -- prepare multiply by depth multiplicand
    -- dependent on draw
    ZN3_COMPUTED_ENVELOPEmultiplicand <= 
    CHOOSEMOD3(POLYLFODEPTH_DRAW(ZN4_currinst, Z00_timeDiv),
    signed(ZN4_COMPUTED_ENVELOPEDEPTH), 
    ZN4_OS, 
    ZN4);
    
    --step 3: perform the multiplication
    ZN2_COMPUTED_ENVELOPEafterdepth <= MULS(ZN3_COMPUTED_ENVELOPEbasewaveform, ZN3_COMPUTED_ENVELOPEmultiplicand, ram_width18, 0);
    ZN2_COMPUTED_ENVELOPEalignbase  <= CHOOSEMOD3(POLYLFOALIGN_DRAW(ZN3_currinst, Z01_timeDiv),
        signed(ZN3_COMPUTED_ENVELOPEALIGN), ZN3_OS, ZN3);
     
    --step 4: align as appropriate, store to POLYLFO_WF
    -- only write to the appropriate spot
    -- when LFOs are active
    ZN1_COMPUTED_ENVELOPE_WF_WREN <= '0';        
    if ZN2_isActive = 0 then
        ZN1_COMPUTED_ENVELOPE_WF_WREN <= '1';
    end if;
    
    ZN1_IN <= std_logic_vector(ADDS(ZN2_COMPUTED_ENVELOPEafterdepth, ZN2_COMPUTED_ENVELOPEalignbase));
        
    end if;
end if;
end process;

end Behavioral;