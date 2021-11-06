----------------------------------------------------------------------------------
-- Julian Loiacono 01/2018
--
-- 25 bits
-- Basic building block which takes any param value as input and returns the 
-- low-passed version of it.
-- consider using shift instead of multiply to reduce resource count
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

entity param_lpf_25 is
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
end param_lpf_25;

architecture Behavioral of param_lpf_25 is
component ram_controller_36k_25 is
Port ( DO             : out STD_LOGIC_VECTOR (24 downto 0);
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
   
signal RAM_REGCE     : std_logic := '0';
signal RAM18_WE      : STD_LOGIC_VECTOR (3 downto 0) := (others => '1');   
signal RAM_RDEN      : std_logic := '0'; 
  
attribute mark_debug : string;
signal ZN1_LASTPARAM : std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z03_LPF_IN    : std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');

signal Z00_LASTPARAM : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z01_LASTPARAM : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z02_LASTPARAM : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z02_POSTALPHA : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z02_ALPHA_IN  : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z03_LPF_WREN  : std_logic := '0';
signal Z01_PARAM_IN  : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
signal Z02_PARAM_IN  : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');

signal Z01_DIFF  : signed(STD_FLOWWIDTH -1 downto 0) := (others=>'0');
    
type PROPTYPE_OSCDET is array (ZN1 to Z21) of signed(STD_FLOWWIDTH-1 downto 0);
signal OSCDET_LPF_PROP  : PROPTYPE_OSCDET  := (others=>(others=>'0'));

signal Z03_ADDR     : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0'); 

begin 

i_lpf_ram: ram_controller_36k_25 port map (
    DO         => ZN1_LASTPARAM,
    DI         => std_logic_vector(Z03_LPF_IN),
    RDADDR     => std_logic_vector(ZN2_ADDR_IN),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE, 
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(Z03_ADDR),
    WRCLK      => clk100,
    WREN       => Z03_LPF_WREN);
    
Z00_PARAM_OUT <= Z00_LASTPARAM;

phase_proc: process(clk100)
begin
if rising_edge(clk100) then
if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
        
    Z03_ADDR <= ZN2_ADDR_IN - 4;
    
    -- y(i) = x(i) + a*(x(i) - y(i-1))
    Z00_LASTPARAM <= signed(ZN1_LASTPARAM);
    
    Z01_DIFF      <= Z00_PARAM_IN - Z00_LASTPARAM; 
    Z02_POSTALPHA <= MULT(Z01_DIFF, Z01_ALPHA_IN, STD_FLOWWIDTH, 1);
    
    Z02_ALPHA_IN  <= Z01_ALPHA_IN;
    
    Z01_LASTPARAM <= Z00_LASTPARAM;
    Z02_LASTPARAM <= Z01_LASTPARAM;
    
    Z01_PARAM_IN <= Z00_PARAM_IN;
    Z02_PARAM_IN <= Z01_PARAM_IN;
        
    Z03_LPF_WREN <= '0';
    -- if speed is full, don't delay before increasing increment to full
    -- furthermore, set full if difference is 0
    if Z02_ALPHA_IN = to_signed(2**23, STD_FLOWWIDTH) or Z02_POSTALPHA = 0 then
        Z03_LPF_IN  <= std_logic_vector(Z02_PARAM_IN);
        Z03_LPF_WREN <= '1';
    -- otherwise, only increase inccurr every 64th sample
    else
        Z03_LPF_IN <= std_logic_vector(Z02_LASTPARAM + Z02_POSTALPHA);
        Z03_LPF_WREN <= '1';
    end if;
    
end if;
end if;
end process;
    
RAM_RDEN   <= not OUTSAMPLEF_ALMOSTFULL;

end Behavioral;