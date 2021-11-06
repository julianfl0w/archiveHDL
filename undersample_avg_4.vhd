----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------

-- here's what this nutso thing does
-- first, look at the flow diagram in Julius O Smith's paramstate Variable Filter writeup
-- we need to run a single pole twice, effectively doubling the input sample rate
-- thats what the OVERSAMPLEFACTOR is
-- the rest is just implimentation
-- and plumbing
-- hopefully this code never breaks lol


-- if each SVF oversample is 7 clocks (prime WRT 1024 so processes dont overlap)
-- and a new independant sample arrives every 4 clocks
-- total length of a process is 7*4 = 28 clocks

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


Library work;
use work.memory_word_type.all;

entity undersample_avg_4 is
    
Port ( clk100     : in STD_LOGIC;
    ZN5_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
            
    Z26_SAMPLE_OUT: out signed(std_flowwidth-1 downto 0) := (others=>'0');
    Z00_SAMPLE_IN : in  signed(std_flowwidth-1 downto 0);
    
    ram_rst100    : in std_logic;
    initRam100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL  : in std_logic
    );
           
end undersample_avg_4;

architecture Behavioral of undersample_avg_4 is

component ram_controller_18k_18 is
Port ( 
   DO             : out STD_LOGIC_VECTOR (ram_width18 - 1 downto 0);
   DI             : in  STD_LOGIC_VECTOR (ram_width18 - 1 downto 0);
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

component ram_controller_18k_25 is
Port ( 
   DO             : out STD_LOGIC_VECTOR (STD_FLOWWIDTH - 1 downto 0);
   DI             : in  STD_LOGIC_VECTOR (STD_FLOWWIDTH - 1 downto 0);
   RDADDR         : in  STD_LOGIC_VECTOR (8 downto 0);
   RDCLK          : in  STD_LOGIC;
   RDEN           : in  STD_LOGIC;
   REGCE          : in  STD_LOGIC;
   RST            : in  STD_LOGIC;
   WE             : in  STD_LOGIC_VECTOR (3 downto 0);
   WRADDR         : in  STD_LOGIC_VECTOR (8 downto 0);
   WRCLK          : in  STD_LOGIC;
   WREN           : in  STD_LOGIC);
end component;

constant MAX_PATH_LENGTH : integer := 7;
type polecount_by_stdflowwidth is array(0 to polecount-1) of signed(std_flowwidth-1 downto 0);

-- unused ram signals
signal RAM_REGCE : std_logic := '0';
signal RAM18_WE  : std_logic_vector(1 downto 0) := "11";
signal RAM18_WE_DUB  : std_logic_vector(3 downto 0) := "1111";

type outaverage_propagatetype is array (Z04 to Z10) of signed(STD_FLOWWIDTH + 1 downto 0);
signal OUT_AVERAGE   : outaverage_propagatetype := (others=>(others=>'0'));

begin

-- timing proc does basic plumbing and timing
-- kind of a catchall process
timing_proc: process(clk100)
begin 
if rising_edge(clk100) then
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    outaverage_proploop:
    for propnum in OUT_AVERAGE'low+1 to OUT_AVERAGE'high loop
        if (propnum - OUT_AVERAGE'low) mod MAX_PATH_LENGTH /= 0 then
            OUT_AVERAGE(propnum) <= OUT_AVERAGE(propnum-1);
        end if;
    end loop;
    
    OUT_AVERAGE(Z04) <= OUT_AVERAGE(Z10);
    -- add signal of interest to OUT_AVERAGE
    OUT_AVERAGE(Z05) <= OUT_AVERAGE(Z04) + Z00_SAMPLE_IN;
        
    case Z00_timeDiv is
                
    when "00" => 
        -- input to OUT_AVERAGE is 0 aligned
        OUT_AVERAGE(Z05) <= resize(Z04_FILTER_OUT, OUT_AVERAGE(0)'length);
        
    when "01" =>
        -- output is +1 aligned
        Z20_FILTER_OUT <= ADD(OUT_AVERAGE(Z04), Z04_FILTER_OUT, STD_FLOWWIDTH, 2);
        
    when "10"=>
                
    when others =>     
    end case;

end if;
end if;
end process;
end generate;
end Behavioral;
