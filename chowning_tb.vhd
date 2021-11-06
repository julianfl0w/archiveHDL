library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY chowning_tb IS 
END chowning_tb;

ARCHITECTURE behavior OF chowning_tb IS
-- Component Declaration for the Unit Under Test (UUT)
--just copy and paste the input and output ports of your module as such. 
COMPONENT chowning

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
END COMPONENT;


component ram_active_rst is
Port ( 
    clkin       : in STD_LOGIC;
    ram_rst     : out STD_LOGIC;
    clksRdy     : in STD_LOGIC;
    initializeRam_out : out std_logic
    );
end component;
   
-- Clock period definitions
constant clk100_period : time := 10 ns;
constant OSCNUM  : integer:= 0;
constant MODDIFF  : integer:= 3;
constant VOICENUM: integer:= 1;
signal clk100       : STD_LOGIC := '0';
    
signal OUTSAMPLEF_ALMOSTFULL : std_logic := '0';

signal ADDR : address_type := (others=>(others=>'0'));

signal MEM_IN25     : STD_LOGIC_VECTOR(std_flowwidth -1 downto 0) := (others=>'0');
signal MEM_IN       : STD_LOGIC_VECTOR(ram_width18 -1 downto 0)   := (others=>'0');
signal MEM_WRADDR   : STD_LOGIC_VECTOR(RAMADDR_WIDTH -1 downto 0) := (others=>'0');
signal OSC_INCTARGET_RATE_WREN : std_logic := '0';
signal OSC_VOL_WREN     : std_logic  := '0';
signal OSC_MODAMP_WREN  : std_logic_vector(oscpervoice-1 downto 0) := (others=>'0');
signal OSC_MODAMP_DRAW  : instcount_by_oscpervoice_by_oscpervoice_by_drawslog2  := (others=>(others=>(others=>(others=>'0'))));
signal OSC_RINGMOD     : instcount_by_oscpervoice_by_oscpervoice := (others=>(others=>(others=>'0')));
    
signal OSC_INC_DRAW      : instcount_by_oscpervoice_by_drawslog2 := (others=>(others=>(others=>'0')));
signal OSC_VOL_DRAW      : instcount_by_oscpervoice_by_drawslog2 := (others=>(others=>(others=>'0')));
signal OSC_DETUNE_WREN   : std_logic  := '0';
signal OSC_DETUNE_DRAW   : instcount_by_oscpervoice_by_drawslog2 := (others=>(others=>(others=>'0')));
signal OSC_HARMONICITY_WREN   : std_logic  := '0';
signal OSC_HARMONICITY_ALPHA_WREN : std_logic  := '0';
    
signal PITCH_SHIFT_DRAW  : instcount_by_drawslog2   := (others=>(others=>'0'));
signal PITCH_SHIFT   : instcount_by_ramwidth18 := (others=>"000100000000000000");
signal DETUNE_RATIO   : instcount_by_2_by_ramwidth18 := (others=>("010000000000100101", "001111111111011010"));
--signal DETUNE_RATIO   : instcount_by_2_by_ramwidth18 := (others=>(to_signed((2**16) * 1.005, ram_width18), to_signed((2**16) * (1/1.005), ram_width18)));

signal UNISON_VOICES_LOG2   : instcount_by_integer := (others=>6);
    
signal Z16_OSC_OUT  : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
    
signal Z01_OS  : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal Z01_COMPUTED_ENVELOPE    : inputcount_by_ramwidth18s := (others=>(others=>'0'));

signal clksRdy    : std_logic := '1';
signal initRam100    : std_logic;
signal ram_rst100 : std_logic;

signal SAMPLECOUNT : integer := 0;

BEGIN

i_chowning: chowning Port map ( 
    clk100       => clk100,
    
    ADDR         => ADDR,
    
    MEM_IN       => MEM_IN,
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
    DETUNE_RATIO      => DETUNE_RATIO,
    UNISON_VOICES_LOG2=> UNISON_VOICES_LOG2,
    
    OSC_MODAMP_DRAW  => OSC_MODAMP_DRAW,
    OSC_INC_DRAW     => OSC_INC_DRAW,
    OSC_VOL_DRAW     => OSC_VOL_DRAW,
    OSC_DETUNE_DRAW  => OSC_DETUNE_DRAW,
    PITCH_SHIFT_DRAW=> PITCH_SHIFT_DRAW,
    
    Z01_OS  => Z01_OS,
    Z01_COMPUTED_ENVELOPE => Z01_COMPUTED_ENVELOPE,
    
    Z16_OSC_OUT  => Z16_OSC_OUT,
        
    initRam100      => initRam100,
    ram_rst100   => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
);

i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    ram_rst            => ram_rst100,
    clksRdy            => clksRdy,
    initializeRam_out  => initRam100
    );

-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

timing_proc: process(clk100)
begin
    if rising_edge(clk100) then
        ADDR(ADDR'low) <= ADDR(ADDR'low) + 1;
        for iteration in ADDR'low+1 to ADDR'high loop
            ADDR(iteration) <= ADDR(iteration-1);
        end loop;
        
--        SAMPLECOUNT <= SAMPLECOUNT + 1;
--        if SAMPLECOUNT < 1024 then
--            OUTSAMPLEF_ALMOSTFULL <= '1';
--        else
--            OUTSAMPLEF_ALMOSTFULL <= '0';
--        end if;
        
--        --OUTSAMPLEF_ALMOSTFULL <= '0';
--        if SAMPLECOUNT = 1024*3 then
--            samplecount <= 0;
--        end if;
    end if;
end process;
   
envtest: process
begin
    wait until initRam100 = '0';
    wait until rising_edge(clk100);
    
    -- SET VOICE PARAMS: INCREMENT AND PORTRATE
    MEM_WRADDR <= "00" & std_logic_vector(to_unsigned(voicenum, 6)) & "00";
    MEM_IN25 <= std_logic_vector(to_signed(2**20, STD_FLOWWIDTH));
    OSC_INCTARGET_RATE_WREN <= '1';
    wait until rising_edge(clk100);
    -- write portamento value to odd address
    MEM_IN25 <= std_logic_vector(to_signed(2**22, STD_FLOWWIDTH));
    MEM_WRADDR(0) <= '1';
    
    wait until rising_edge(clk100);
    OSC_INCTARGET_RATE_WREN <= '0';
    
    -- set volume of OSCNUM
    MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(OSCNUM, 2));
    MEM_IN <= std_logic_vector(to_signed(2**16, 18));
    OSC_VOL_WREN <= '1';
    wait until rising_edge(clk100);
    OSC_VOL_WREN <= '0';
    
    -- set crossmod of oscnum
    wait until rising_edge(clk100);
    OSC_MODAMP_WREN((OSCNUM+MODDIFF) mod OSCPERVOICE) <= '1';
    --OSC_MODAMP_WREN(OSCNUM) <= '1';
    MEM_IN <= std_logic_vector(to_signed(2**12, RAM_WIDTH18));
    MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(OSCNUM, 2));
    
    wait until rising_edge(clk100);
    OSC_MODAMP_WREN((OSCNUM+MODDIFF) mod OSCPERVOICE) <= '0';
    --OSC_MODAMP_WREN(OSCNUM) <= '0';
    
    -- SET ALL DETUNES
    OSC_DETUNE_WREN <= '1';
                  
--     non-zero where desired
    MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(OSCNUM, 2));
    MEM_IN <= std_logic_vector(to_signed(2**14, RAM_WIDTH18));
    wait until rising_edge(clk100);
--    MEM_IN <= std_logic_vector(to_signed(2**12, RAM_WIDTH18));
--    MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(OSCNUM, 2) + MODDIFF);
    
    wait until rising_edge(clk100);
    OSC_DETUNE_WREN <= '0';
    -- ring mod oscnum with oscnum + moddiff
    --OSC_RINGMOD(0, oscnum)((OSCNUM+MODDIFF) mod OSCPERVOICE) <= '1';
    wait until rising_edge(clk100);
    
    --set harmonicity of oscnum+1
    MEM_WRADDR(1 downto 0) <= std_logic_vector(to_unsigned(OSCNUM, 2));
    MEM_IN <= std_logic_vector(to_signed(2**15, RAM_WIDTH18));
    OSC_HARMONICITY_ALPHA_WREN <= '1';
    wait until rising_edge(clk100);
    OSC_HARMONICITY_ALPHA_WREN <= '0';
    MEM_IN <= std_logic_vector(to_signed(0, RAM_WIDTH18));
    --OSC_HARMONICITY_WREN <= '1';
    wait until rising_edge(clk100);
    OSC_HARMONICITY_WREN <= '0';
--        -- detune osc 1 to 2**15, rationalized
    wait for 1ms;
    
    --OSC_DETUNE(0,1) <= to_signed(0, RAM_WIDTH18);
        
    wait;
end process;
END;