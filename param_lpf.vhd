----------------------------------------------------------------------------------
-- Julian Loiacono 01/2018
--
-- 18 bits
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

entity param_lpf is
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
end param_lpf;

architecture Behavioral of param_lpf is
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

component multLPFmath is
Port ( 
    clk100       : in STD_LOGIC;
    
    Z00_PARAM_THIS   : in signed(ram_width18 -1 downto 0);
    Z00_PARAM_LAST   : in signed(ram_width18 -1 downto 0);
    Z01_ALPHA_IN     : in signed(ram_width18 -1 downto 0);
    Z03_PARAM_OUT    : out signed(ram_width18 -1 downto 0);
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;
   
signal RAM_REGCE     : std_logic := '0';
signal RAM18_WE      : STD_LOGIC_VECTOR (1 downto 0) := (others => '1');   
signal RAM_RDEN      : std_logic := '0'; 
  
attribute mark_debug : string;
signal ZN1_LASTPARAM : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');
signal Z03_LPF_IN    : signed(ram_width18-1 downto 0) := (others=>'0');
signal Z00_LASTPARAM : signed(ram_width18 -1 downto 0) := (others=>'0');
signal Z03_LPF_WREN  : std_logic := '0';
signal Z03_ADDR     : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0');

begin 

i_lpf_ram: ram_controller_18k_18 port map (
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
    
multLPFmath_i: multLPFmath port map(
    clk100       => clk100,
    
    Z00_PARAM_THIS  => Z00_PARAM_IN,
    Z00_PARAM_LAST  => Z00_LASTPARAM,
    Z01_ALPHA_IN    => Z01_ALPHA_IN,
    Z03_PARAM_OUT   => Z03_LPF_IN,
    
    initRam100      => initRam100,
    ram_rst100      => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
    
Z00_PARAM_OUT <= Z00_LASTPARAM;

phase_proc: process(clk100)
begin
if rising_edge(clk100) then
Z03_LPF_WREN <= '0';
if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
    -- calculate write address from read address
    Z03_ADDR <= ZN2_ADDR_IN - 4;
    -- pass along ram read
    Z00_LASTPARAM <= signed(ZN1_LASTPARAM);
    -- always write
    Z03_LPF_WREN <= '1';
end if;
end if;
end process;
    
RAM_RDEN   <= not OUTSAMPLEF_ALMOSTFULL;

end Behavioral;