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
use work.fixed_pkg.all;

entity interpolate_oversample_4 is  
Port ( 
    clk100     : in STD_LOGIC;
    
    ZN1_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
    Z01_INTERP_OUT: out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    Z00_INTERP_IN : in  sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    
    ram_rst100    : in std_logic;
    initRam100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL  : in std_logic
);     
end interpolate_oversample_4;

architecture Behavioral of interpolate_oversample_4 is

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

-- unused ram signals
signal RAM_REGCE : std_logic := '0';
signal RAM18_WE  : std_logic_vector(1 downto 0) := "11";
signal RAM18_WE_DUB  : std_logic_vector(3 downto 0) := "1111";

signal Z00_INTERP_IN_LAST: std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');

type tofilt_propagatetype is array (Z00 to Z06) of sfixed(1 downto -std_flowwidth + 2);
signal INTERP_IN : tofilt_propagatetype := (others=>(others=>'0'));
signal INTERP_IN_LAST : tofilt_propagatetype := (others=>(others=>'0'));

signal LASTSAMPLE_WREN : std_logic := '0';
signal LASTSAMPLE_RDEN : std_logic := '0';

signal Z00_timeDiv : integer := 0;
signal Z00_ADDR    :  unsigned (RAMADDR_WIDTH-1 downto 0);
begin

Z00_timeDiv <= to_integer(Z00_ADDR(1 downto 0));

-- last sample ram
i_lastsample_ram: ram_controller_18k_25
port map (
    DO         => Z00_INTERP_IN_LAST,
    DI         => std_logic_vector(Z00_INTERP_IN),
    RDADDR     => std_logic_vector(ZN1_ADDR(9 downto 1)),
    RDCLK      => clk100,
    RDEN       => LASTSAMPLE_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE_DUB,
    WRADDR     => std_logic_vector(Z00_ADDR(9 downto 1)),
    WRCLK      => clk100,
    WREN       => LASTSAMPLE_WREN);
    
--only write sample on even address
LASTSAMPLE_WREN<= not Z00_ADDR(0);

-- timing proc does basic plumbing and timing
-- kind of a catchall process
timing_proc: process(clk100)
begin 
if rising_edge(clk100) then
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    LASTSAMPLE_RDEN <= '1';
    Z00_ADDR <= ZN1_ADDR;
    
    to_proploop:
    for propnum in INTERP_IN'low+1 to INTERP_IN'high loop
        INTERP_IN(propnum) <= INTERP_IN(propnum-1);
        INTERP_IN_LAST(propnum) <= INTERP_IN_LAST(propnum-1);
    end loop;
    
    -- likewise,
    INTERP_IN(Z00) <= INTERP_IN(Z06);
    INTERP_IN_LAST(Z00) <= INTERP_IN_LAST(Z06);
    
    case Z00_timeDiv is
                
    when 0 => 
        INTERP_IN(Z01) <= Z00_INTERP_IN;
        INTERP_IN_LAST(Z01) <= sfixed(Z00_INTERP_IN_LAST);
        -- first oversample is the previous read
        Z01_INTERP_OUT <= sfixed(Z00_INTERP_IN_LAST);
    when 1 =>
        -- final oversample is on (currsample - currsample/4 + lastsample/4) (1 aligned)
        Z01_INTERP_OUT <= resize(INTERP_IN(Z00) - scalb(INTERP_IN(Z00),-2) + scalb(INTERP_IN_LAST(Z00), -2), INTERP_IN(0), fixed_wrap, fixed_truncate);
    when 2 =>
        -- third oversample is the average of this sample and last sample (2-aligned)
        Z01_INTERP_OUT <= resize(scalb(INTERP_IN(Z00) + INTERP_IN_LAST(Z00), -1), INTERP_IN(0), fixed_wrap, fixed_truncate);
    when others =>
        -- second oversample is on (lastsample - lastsample/4 + currsample/4) (-1 aligned)
        Z01_INTERP_OUT <= resize(INTERP_IN_LAST(Z00) - scalb(INTERP_IN_LAST(Z00),-2) + scalb(INTERP_IN(Z00),-2), INTERP_IN(0), fixed_wrap, fixed_truncate);
    end case;
    

end if;
end if;
end process;
end Behavioral;
