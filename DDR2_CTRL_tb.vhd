library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY DDR2_CTRL_tb IS 
END DDR2_CTRL_tb;

ARCHITECTURE behavior OF DDR2_CTRL_tb IS

component DDR2_CTRL is
Port (
        -- clocks 
       clk100        : in  STD_LOGIC;
       clk200        : in  STD_LOGIC;
       reset         : in  STD_LOGIC;
       
       -- SDRAM signals
       FROM_RAMF_ALMOSTEMPTY : out std_logic;
       SDRAM_CKE     : out   STD_LOGIC := '0';
       SDRAM_CLK_P   : out   STD_LOGIC;
       SDRAM_CLK_N   : out   STD_LOGIC;
       SDRAM_CS      : out   STD_LOGIC := '0';
       SDRAM_RAS     : out   STD_LOGIC := '0';
       SDRAM_CAS     : out   STD_LOGIC := '0';
       SDRAM_WE      : out   STD_LOGIC := '0';
       SDRAM_DQS_P   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_DQS_N   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_DQM     : out   STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_ADDR    : out   STD_LOGIC_VECTOR(sdram_rowcount-1 downto 0) := (others=>'0');
       SDRAM_BA      : out   STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_DATA    : inout STD_LOGIC_VECTOR(sdramWidth-1 downto 0) := (others=>'0');
       
       -- external fifo access
       FROM_RAMF_DO   : out std_logic_vector (sdramWidth-1 downto 0);
       FROM_RAMF_RDEN : in std_logic;
       TO_RAMF_DI     : in std_logic_vector (sdramWidth-1 downto 0);
       TO_RAMF_WRandTOG   : in STD_LOGIC := '0';
       PARAMF_WREN    : in STD_LOGIC := '0';
       PARAMF_DI      : in std_logic_vector (RAM_WIDTH18-1 downto 0) := (others=>'0');
       
       initRam100      : in std_logic;
       ram_rst100   : in std_logic);
end component;

component ram_active_rst is
Port ( 
    clksRdy           : in STD_LOGIC;
    clk100            : in STD_LOGIC;
    ram_rst100        : out STD_LOGIC := '0';
    initializeRam_out : out std_logic := '1'
    );
end component;

COMPONENT sdram_model is
    Generic(
      BANKCOUNT           : natural;
      sdram_rowcount      : natural;
      sdram_rows_to_sim   : natural;
      sdram_colcount      : natural;
      dataWidth           : natural);
    PORT(
        CLK   : IN std_logic;
        CKE   : IN std_logic;
        CS_N  : IN std_logic;
        RAS_N : IN std_logic;
        CAS_N : IN std_logic;
        WE_N  : IN std_logic;
        DQS_P : INout std_logic_vector(1 downto 0);
        DQS_N : INout std_logic_vector(1 downto 0);
        DQM   : IN std_logic_vector(1 downto 0);
        BA    : in  STD_LOGIC_VECTOR (1 downto 0);
        ADDR  : IN std_logic_vector(12 downto 0);       
        DQ    : INOUT std_logic_vector(15 downto 0)
    );
END COMPONENT;

component clocks is
port (
    clksRdy : out std_logic;
    clk100  : in std_logic;
    clk200  : out std_logic;
    GPIF_CLK : out std_logic);
end component;

signal clksRdy       : std_logic;
signal clk100        : STD_LOGIC;
signal clk200        : STD_LOGIC;
signal GPIF_clk      : STD_LOGIC;
signal reset         : STD_LOGIC := '0';

-- the sole input param: delay tap position relative to current address
signal TAP_LOCATION  : instcount_times_channelcount_times_delaytaps;

-- SDRAM signals
signal SDRAM_CLK_P   : STD_LOGIC;
signal SDRAM_CLK_N   : STD_LOGIC;
signal SDRAM_CKE     : STD_LOGIC;
signal SDRAM_CS      : STD_LOGIC;
signal SDRAM_RAS     : STD_LOGIC;
signal SDRAM_CAS     : STD_LOGIC;
signal SDRAM_WE      : STD_LOGIC;
signal SDRAM_DQS_P   : STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
signal SDRAM_DQS_N   : STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
signal SDRAM_DQM     : STD_LOGIC_VECTOR( 1 downto 0);
signal SDRAM_ADDR    : STD_LOGIC_VECTOR(12 downto 0);
signal SDRAM_BA      : STD_LOGIC_VECTOR( 1 downto 0);
signal SDRAM_DATA    : STD_LOGIC_VECTOR(15 downto 0);

-- external fifo access
signal FROM_RAMF_EMPTY: std_logic := '0';
signal FROM_RAMF_DO   : std_logic_vector (sdramWidth-1 downto 0);
signal FROM_RAMF_RDEN : std_logic := '0';
signal TO_RAMF_DI     : std_logic_vector (sdramWidth-1 downto 0);
signal TO_RAMF_WRandTOG   : STD_LOGIC := '0';
signal PARAMF_WREN    : STD_LOGIC := '0';
signal PARAMF_DI      : std_logic_vector (RAM_WIDTH18-1 downto 0) := (others=>'0');
        
signal sendctr    : unsigned(3 downto 0) := (others=>'0');
signal sendval    : signed (sdramWidth - 1 downto 0) := (others=>'0');

signal loadingCtr : unsigned(12 downto 0) := (others=>'1');

signal initRam100    : std_logic;
signal ram_rst100 : std_logic;

signal initSDRAM : std_logic := '1';
signal FROM_RAMF_ALMOSTEMPTY : std_logic;
signal currInstChanTapWrite: unsigned(instcountlog2 + channelscountlog2 + tapsperinstlog2 -1 downto 0) := (others=>'0');

-- Clock period definitions
constant clk100_period : time := 10 ns;

BEGIN

i_ram_active_rst: ram_active_rst port map(
    clksRdy            => clksRdy,
    clk100             => clk100,
    ram_rst100         => ram_rst100,
    initializeRam_out  => initRam100
    );


i_sdram_model: sdram_model 
Generic Map(
      BANKCOUNT         => 4,
      sdram_rowcount    => 13,
      sdram_rows_to_sim => 2, -- only simulate 1 rows
      sdram_colcount    => 10,
      dataWidth         => 16)
PORT MAP(
    CLK   => clk200,
    CKE   => SDRAM_CKE,
    CS_N  => SDRAM_CS,
    RAS_N => SDRAM_RAS,
    CAS_N => SDRAM_CAS,
    WE_N  => SDRAM_WE,
    DQS_P => SDRAM_DQS_P,
    DQS_N => SDRAM_DQS_N,
    DQM   => SDRAM_DQM,
    ADDR  => SDRAM_ADDR,
    BA    => SDRAM_BA,
    DQ    => SDRAM_DATA
);

i_clocks: clocks port map(
    clksRdy   => clksRdy,
    clk100    => clk100,
    clk200    => clk200,
    GPIF_CLK  => GPIF_CLK
    );
    
i_ddr2_ctrl: DDR2_CTRL
    Port map(
        -- clocks 
       clk100        => clk100,
       clk200        => clk200,
       reset         => reset,
       
       -- SDRAM signals
       SDRAM_CLK_P   => SDRAM_CLK_P,
       SDRAM_CLK_N   => SDRAM_CLK_N,
       SDRAM_CKE     => SDRAM_CKE,
       SDRAM_CS      => SDRAM_CS,
       SDRAM_RAS     => SDRAM_RAS,
       SDRAM_CAS     => SDRAM_CAS,
       SDRAM_WE      => SDRAM_WE,
       SDRAM_DQS_P   => SDRAM_DQS_P,
       SDRAM_DQS_N   => SDRAM_DQS_N,
       SDRAM_DQM     => SDRAM_DQM,
       SDRAM_ADDR    => SDRAM_ADDR,
       SDRAM_BA      => SDRAM_BA,
       SDRAM_DATA    => SDRAM_DATA,
       
       -- external fifo access
       FROM_RAMF_DO   => FROM_RAMF_DO,
       FROM_RAMF_RDEN => FROM_RAMF_RDEN,
       TO_RAMF_DI     => TO_RAMF_DI,
       TO_RAMF_WRandTOG   => TO_RAMF_WRandTOG,
       PARAMF_WREN    => PARAMF_WREN,
       PARAMF_DI      => PARAMF_DI,
       
       FROM_RAMF_ALMOSTEMPTY => FROM_RAMF_ALMOSTEMPTY,
               
       initRam100       => initRam100,
       ram_rst100  => ram_rst100
   );
       
-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

fmtestproc: process(clk100)
begin
if rising_edge(clk100) then
if initRam100 = '0' then
    TO_RAMF_WRandTOG <= '0';
    FROM_RAMF_RDEN <= '0';
    PARAMF_WREN <= '0';
    sendctr <= sendctr + 1;
    
    if sendctr = 1 then
        PARAMF_DI                            <= (others=>'0');
        PARAMF_DI(instcountlog2 + channelscountlog2 + tapsperinstlog2 -1 downto 0) <= STD_LOGIC_VECTOR(currInstChanTapWrite);
        PARAMF_DI(PARAMF_DI'high)            <= '1';
        PARAMF_WREN <= '1';
    elsif sendctr = 2 then
        PARAMF_DI <= (others=>'0');
        PARAMF_DI <= "000000001100000000";
        PARAMF_WREN <= '1';
        currInstChanTapWrite <= currInstChanTapWrite + 1;
    end if;
    
    if FROM_RAMF_ALMOSTEMPTY = '0' then
        initSDRAM <= false;
    end if;
        
    if not initSDRAM and sendctr = 0 then
        -- send this value
        -- if even, load value into FIFO 0
        TO_RAMF_DI <= std_logic_vector(sendval);
        TO_RAMF_WRandTOG <= '1';
        sendval <= sendval + 1;
        
        -- read this tap
        FROM_RAMF_RDEN <= '1';
    end if;
end if;
end if;
end process;

END;