library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY oneshots_tb IS 
END oneshots_tb;

ARCHITECTURE behavior OF oneshots_tb IS
-- Component Declaration for the Unit Under Test (UUT)

COMPONENT oneshots
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
    DPS_WE   : IN STD_LOGIC_VECTOR (3 downto 0);   
    
    RATE_DRAW  : in instcount_by_envspervoice_by_drawslog2;
    ZN6_COMPUTED_ENVELOPE    : in inputcount_by_ramwidth18s;
    
    beginMeasure: in std_logic;
    Z00_OS   : out oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );  
END COMPONENT; 

component ram_active_rst is
Port ( clkin      : in STD_LOGIC;
       clksRdy    : in STD_LOGIC;
       ram_rst    : out STD_LOGIC := '0';
       initializeRam_out : out std_logic := '1'
       );
end component;

-- Clock period definitions
constant clk100_period : time := 10 ns;
signal clk100          : STD_LOGIC := '0';
signal OS_STAGE_SET_WREN : STD_LOGIC := '0';
signal ONESHOT_MIDPOINT_Y   : insts_by_oneshotspervoice_by_stagecount_by_ramwidth18 := (others=>(others=>(others=>(others=>'0'))));    
signal ONESHOT_STARTPOINT_Y : insts_by_oneshotspervoice_by_stagecount_by_ramwidth18 := (others=>(others=>(others=>(others=>'0'))));    

signal MEM_WRADDR   : std_logic_vector(ramaddr_width -1 downto 0) := (others=>'0');
signal MEM_IN       : std_logic_vector(ram_width18   -1 downto 0) := (others=>'0');
signal ONESHOTRATE_WREN : std_logic_vector(stagecount-1 downto 0) := (others=>'0');
    
signal Z00_OS   : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
    
signal ZN8_ADDR: unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0'); 
    
signal instno   : integer := 0;
signal voiceno  : integer := 0;
signal polylfono: integer := 0;
    
signal initRam100      : std_logic;
signal ram_rst100   : std_logic;
signal clksRdy      : std_logic := '1';
signal OUTSAMPLEF_ALMOSTFULL : std_logic := '0';
signal ZN6_COMPUTED_ENVELOPE    : inputcount_by_ramwidth18s := (others=>(others=>'0'));

signal SAMPLES_PER_DIV : STD_LOGIC_VECTOR(std_flowwidth-1 downto 0) := STD_LOGIC_VECTOR(to_unsigned(25, std_flowwidth));

signal RATE_DRAW  : insts_by_oneshotspervoice_by_drawslog2 := (others=>(others=>to_unsigned(DRAW_FIXED_I, drawslog2)));
signal SAMPLECOUNT : integer := 0;
signal beginMeasure: std_logic := '0';

signal DPS_WREN : STD_LOGIC := '0';
signal MEM_IN36: std_logic_vector(36   -1 downto 0) := (others=>'0');

signal DPS_WE : STD_LOGIC_VECTOR (3 downto 0) := (others=>'0'); 

BEGIN
-- Instantiate the Unit Under Test (UUT)
i_oneshots: oneshots PORT MAP (
    clk100     => clk100,
    ZN8_ADDR  => ZN8_ADDR,
        
    SAMPLES_PER_DIV   => SAMPLES_PER_DIV,
        
    ONESHOT_MIDPOINT_Y     => ONESHOT_MIDPOINT_Y,
    ONESHOT_STARTPOINT_Y   => ONESHOT_STARTPOINT_Y,
    
    MEM_WRADDR  => MEM_WRADDR,
    MEM_IN      => MEM_IN,
    MEM_IN36   => MEM_IN36,
    ONESHOTRATE_WREN  => ONESHOTRATE_WREN,
    OS_STAGE_SET_WREN => OS_STAGE_SET_WREN,
    DPS_WREN => DPS_WREN,
    DPS_WE => DPS_WE,
    
    RATE_DRAW  => RATE_DRAW,
    ZN6_COMPUTED_ENVELOPE  => ZN6_COMPUTED_ENVELOPE,
    
    beginMeasure => beginMeasure,
    Z00_OS  => Z00_OS,
    
    initRam100  => initRam100,
    ram_rst100  => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL  => OUTSAMPLEF_ALMOSTFULL
    ); 

i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    clksRdy            => clksRdy, 
    ram_rst            => ram_rst100,
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
   
addr_proc: process(clk100)
begin
if rising_edge(clk100) then
    if initRam100 = '0' then
        ZN8_ADDR <= ZN8_ADDR + 1;
        if ZN8_ADDR = 0 then
            SAMPLECOUNT <= SAMPLECOUNT + 1;
        end if;
    end if;
end if;
end process;
   
ostest: process
begin
    --RATE_DRAW(instno,polylfono) <= to_unsigned(DRAW_BEAT_I, drawslog2);
    wait until initRam100 = '0';
    wait until rising_edge(clk100);
        
    polylfono <= 0;
    -- alternate os startpoints between 0 and max
    ONESHOT_STARTPOINT_Y(instno,polylfono,0) <= to_signed(0, ram_width18);
    ONESHOT_STARTPOINT_Y(instno,polylfono,1) <= to_signed(2**16, ram_width18);
    ONESHOT_STARTPOINT_Y(instno,polylfono,3) <= to_signed(0, ram_width18);
    ONESHOT_STARTPOINT_Y(instno,polylfono,2) <= to_signed(2**16, ram_width18);
    
    -- midpoints always half full
    ONESHOT_MIDPOINT_Y(instno,polylfono,0) <= to_signed(2**15, ram_width18);
    ONESHOT_MIDPOINT_Y(instno,polylfono,1) <= to_signed(2**15, ram_width18);
    ONESHOT_MIDPOINT_Y(instno,polylfono,2) <= to_signed(2**15, ram_width18);
    ONESHOT_MIDPOINT_Y(instno,polylfono,3) <= to_signed(2**15, ram_width18);
        
    -- oneSHOT rate
    MEM_WRADDR <= std_logic_vector(to_unsigned(instno, instcountlog2)) &
                  std_logic_vector(to_unsigned(voiceno, voicesperinstlog2)) &
                  std_logic_vector(to_unsigned(polylfono, POLYLFOSpervoicelog2));
    -- let the rate be, in all stages, 2**16
    MEM_IN <= STD_LOGIC_VECTOR(to_unsigned(2**18-1, 18));
    -- let the rate be, in all stages, 4 divs / stage
    --MEM_IN <= STD_LOGIC_VECTOR(to_unsigned(0, 18));
    
    ONESHOTRATE_WREN(0) <= '1';
    wait until rising_edge(clk100);
    ONESHOTRATE_WREN(0) <= '0';
    -- except stage 2&3, which waits for note-off event
    MEM_IN <= STD_LOGIC_VECTOR(to_unsigned(0, 18));
    ONESHOTRATE_WREN(1) <= '1';
    wait until rising_edge(clk100);
    ONESHOTRATE_WREN(1) <= '0';
    ONESHOTRATE_WREN(2) <= '1';
    wait until rising_edge(clk100);
    ONESHOTRATE_WREN(2) <= '0';
    ONESHOTRATE_WREN(3) <= '1';
    wait until rising_edge(clk100);
    ONESHOTRATE_WREN(3) <= '0';
    
    wait until rising_edge(clk100);
    polylfono <= 3;
    DPS_WREN <= '1';
    MEM_WRADDR <= std_logic_vector(to_unsigned(instno, instcountlog2)) &
                  std_logic_vector(to_unsigned(voiceno, voicesperinstlog2)) &
                  "00";
    MEM_IN36 <= STD_LOGIC_VECTOR(to_unsigned(4, 36));
    DPS_WE(0) <= '1';
    wait until rising_edge(clk100);
    DPS_WREN <= '0';
    DPS_WE <= (others=>'0');
    
    wait for 0.5ms;
    wait until rising_edge(clk100);
    --   stage[2] inst[3] voice[5] os[2]
    MEM_IN(11 downto 0 ) <=  "10" & std_logic_vector(to_unsigned(instno, instcountlog2)) &
                  std_logic_vector(to_unsigned(voiceno, voicesperinstlog2)) & "00"; 
    MEM_IN(17 downto 12) <= (others=>'0'); 
    OS_STAGE_SET_WREN <= '1';
    wait until rising_edge(clk100);
    OS_STAGE_SET_WREN <= '0';
    
    
--    -- do the same, but set polylfono to 7
--    -- alternate envelope startpoints between 0 and max
--    ONESHOT_STARTPOINT_Y(instno,polylfono,0) <= to_signed(0, ram_width18);
--    ONESHOT_STARTPOINT_Y(instno,polylfono,1) <= to_signed(2**16, ram_width18);
--    ONESHOT_STARTPOINT_Y(instno,polylfono,2) <= to_signed(0, ram_width18);
--    ONESHOT_STARTPOINT_Y(instno,polylfono,3) <= to_signed(2**16, ram_width18);
    
--    -- midpoints always quarter full
--    ONESHOT_MIDPOINT_Y(instno,polylfono,0) <= to_signed(2**15, ram_width18);
--    ONESHOT_MIDPOINT_Y(instno,polylfono,1) <= to_signed(2**15, ram_width18);
--    ONESHOT_MIDPOINT_Y(instno,polylfono,2) <= to_signed(2**15, ram_width18);
--    ONESHOT_MIDPOINT_Y(instno,polylfono,3) <= to_signed(2**15, ram_width18);
        
--    -- oneSHOT rate
--    -- let the rate be, in all stages, 2**16
--    MEM_WRADDR <= std_logic_vector(to_unsigned(instno, instcountlog2+1)) &
--                  std_logic_vector(to_unsigned(voiceno, 5)) &
--                  std_logic_vector(to_unsigned(polylfono, oneshotspervoicelog2));
--    MEM_IN <= STD_LOGIC_VECTOR(to_unsigned(2**16, 18));
--    ONESHOTRATE_WREN(0) <= '1';
--    wait until rising_edge(clk100);
--    ONESHOTRATE_WREN(0) <= '0';
--    ONESHOTRATE_WREN(1) <= '1';
--    wait until rising_edge(clk100);
--    ONESHOTRATE_WREN(1) <= '0';
--    ONESHOTRATE_WREN(2) <= '1';
--    wait until rising_edge(clk100);
--    ONESHOTRATE_WREN(2) <= '0';
--    -- except stage 3, which waits for note-off event
--    MEM_IN <= STD_LOGIC_VECTOR(to_unsigned(0, 18));
--    ONESHOTRATE_WREN(3) <= '1';
--    wait until rising_edge(clk100);
--    ONESHOTRATE_WREN(3) <= '0';
    wait for 2ms;
    
    beginMeasure <= '1';
    wait for clk100_period * 1024 * 2;
    wait until rising_edge(clk100);
    beginMeasure <= '0';
    
    
    wait for 100ms;
    -- set stage to 1
    wait until rising_edge(clk100);

    --  unused [4] inst[3] voice[5] os[2] stage[2]
    MEM_IN <= "000000" & "000" & "00000" & "00" & "01";
    OS_STAGE_SET_WREN <= '1';
    wait until rising_edge(clk100);
    OS_STAGE_SET_WREN <= '0';
    
    wait;
end process;

END;