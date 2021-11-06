----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/03/2017 03:31:52 PM
-- Design Name: 
-- Module Name: gpif_ii_top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

Library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

library work;
use work.memory_word_type.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity gpif_ii_top is
generic(
    EXCLUDE_SIG_CHAIN : integer := 0
);
Port ( 
    I2S_BCLK   : out std_logic;
    I2S_LRCLK  : out std_logic;
    I2S_DACSD  : out std_logic;
    I2S_ADCSD  : in std_logic;
    clk100     : in STD_LOGIC;
    
    -- GPIF Signals
    GPIF_CLK   : out std_logic;               ---output clk 100 Mhz and 180 phase shift 
    GPIF_SLCS  : out std_logic := '1';        ---output chip select
    GPIF_DATA  : inout std_logic_vector(gpif_width -1 downto 0) := (others=>'Z');         
    GPIF_ADDR  : out std_logic_vector(1 downto 0) := (others=>'0');  ---output fifo address
    GPIF_SLRD  : out std_logic := '1';        ---output read select
    GPIF_SLOE  : out std_logic := '1';        ---output output enable select
    GPIF_SLWR  : out std_logic := '1';        ---output write select
    GPIF_FLAGA : in std_logic := '1';                              
    GPIF_FLAGB : in std_logic := '1';  
    GPIF_PKTEND: out std_logic := '1';        ---output pkt end
        
    -- Tempo signals
    TEMPO_SW   : in std_logic;                                
    TEMPO_LED  : out std_logic := '0';
    
    -- LCD signals
    LCD_RST : out std_logic := '1';
    LCD_CSX : out std_logic := '1';
    LCD_WRX : out std_logic := '1';
    LCD_RDX : out std_logic := '1';
    LCD_DCX : out std_logic := '1';
    LCD_D   : inout std_logic_vector(17 downto 0);
    LCD_IM  : out std_logic_vector(3 downto 0) := "0011"; -- 8080-I 18-bit
    
    LCD_SDA    : out std_logic := '0';
    LCD_SDO    : in  std_logic;
    LCD_TE     : in  std_logic; 
    LCD_DOTCLK : out std_logic := '0';
    LCD_HSYNC  : out std_logic := '0';
    LCD_VSYNC  : out std_logic := '0';
    LCD_DE     : out std_logic := '0';
    
    LED_G : out std_logic := '1';
    LED_R : out std_logic := '0';
    LED_B : out std_logic := '0'
    
    -- SDRAM signals
--    sys_clk_i     : in STD_LOGIC;
--    ddr2_dq       : inout std_logic_vector(15 downto 0);
--    ddr2_dqs_p    : inout std_logic_vector(1 downto 0);
--    ddr2_dqs_n    : inout std_logic_vector(1 downto 0);
--    ddr2_addr     : out   std_logic_vector(12 downto 0);
--    ddr2_ba       : out   std_logic_vector(1 downto 0);
--    ddr2_ras_n    : out   std_logic;
--    ddr2_cas_n    : out   std_logic;
--    ddr2_we_n     : out   std_logic;
--    ddr2_ck_p     : out   std_logic_vector(0 downto 0);
--    ddr2_ck_n     : out   std_logic_vector(0 downto 0);
--    ddr2_cke      : out   std_logic_vector(0 downto 0);
--    ddr2_odt      : out   std_logic_vector(0 downto 0)
);
end gpif_ii_top;


architecture Behavioral of gpif_ii_top is

signal clk200: std_logic := '0';

signal Z00_GPIF_DATA_IN  : std_logic_vector(gpif_width -1 downto 0) := (others=>'Z');       
signal GPIF_DATA_OUT : std_logic_vector(gpif_width -1 downto 0) := (others=>'Z');       
signal GPIF_DATA_TRISTATE : std_logic := '1';     
    
signal MEM_IN25 : std_logic_vector(std_flowwidth -1 downto 0);
           
signal TEMPOPULSE_DATA : std_logic_vector(gpif_width -1 downto 0) := (others=>'Z');   
signal i2s_cycle_begin   : STD_LOGIC;  

signal TEMPO_PULSE   : STD_LOGIC := '0';
signal BEAT_BTN_HELD : STD_LOGIC := '0';

signal clksrdy: STD_LOGIC;

signal Z01_GPIF_FLAGA : std_logic := '1';       
signal Z01_GPIF_FLAGB : std_logic := '1';                            
attribute mark_debug : string;
attribute mark_debug of Z01_GPIF_FLAGA: signal is "true";
attribute mark_debug of Z01_GPIF_FLAGB: signal is "true";
                               
-- output fifo signals
signal OUTSAMPLEF_ALMOSTFULL  : STD_LOGIC;  
signal OUTSAMPLEF_WREN        : STD_LOGIC := '0';
signal OUTSAMPLEF_DI          : signed (i2s_width-1 downto 0) := (others=>'0');
signal OUTSAMPLEF_DO          : std_logic_vector (i2s_width-1 downto 0);
signal OUTSAMPLEF_ALMOSTEMPTY : std_logic;
signal OUTSAMPLEF_EMPTY       : std_logic;
signal OUTSAMPLEF_FULL        : std_logic;
signal OUTSAMPLEF_RDCOUNT     : std_logic_vector (9 downto 0);
signal OUTSAMPLEF_RDERR       : std_logic;
signal OUTSAMPLEF_WRCOUNT     : std_logic_vector (9 downto 0);
signal OUTSAMPLEF_WRERR       : std_logic;
signal OUTSAMPLEF_RDEN        : std_logic := '0';

-- input fifo signals
signal INSAMPLEF_ALMOSTFULL  : STD_LOGIC;  
signal Z01_INSAMPLEF_WREN    : STD_LOGIC := '0';
signal INSAMPLEF_WREN        : STD_LOGIC := '0';
signal INSAMPLEF_DO          : std_logic_vector (i2s_width-1 downto 0);
signal INSAMPLEF_ALMOSTEMPTY : std_logic;
signal INSAMPLEF_EMPTY       : std_logic;
signal INSAMPLEF_FULL        : std_logic;
signal INSAMPLEF_RDCOUNT     : std_logic_vector (9 downto 0);
signal INSAMPLEF_RDERR       : std_logic;
signal INSAMPLEF_WRCOUNT     : std_logic_vector (9 downto 0);
signal INSAMPLEF_WRERR       : std_logic;
signal INSAMPLEF_RDEN        : std_logic := '0';

-- input fifo signals
signal INPARAMF_ALMOSTFULL  : STD_LOGIC;  
signal INPARAMF_WREN        : STD_LOGIC := '0';
attribute mark_debug of INPARAMF_WREN: signal is "true";
signal Z01_GPIF_DATA      : std_logic_vector (gpif_width -1 downto 0) := (others=>'0');
signal Z02_GPIF_DATA      : std_logic_vector (gpif_width -1 downto 0) := (others=>'0');
signal Z01_GPIF_DATA_rev  : std_logic_vector (gpif_width -1 downto 0) := (others=>'0');
attribute mark_debug of Z02_GPIF_DATA: signal is "true";

signal INPARAMF_DO          : std_logic_vector (gpif_width -1 downto 0);
--attribute mark_debug of INPARAMF_DO: signal is "true";
signal INPARAMF_ALMOSTEMPTY : std_logic;
signal INPARAMF_EMPTY       : std_logic;
signal INPARAMF_FULL        : std_logic;
signal INPARAMF_RDCOUNT     : std_logic_vector (9 downto 0);
signal INPARAMF_RDERR       : std_logic;
signal INPARAMF_WRCOUNT     : std_logic_vector (9 downto 0);
signal INPARAMF_WRERR       : std_logic;
signal INPARAMF_RDEN        : std_logic := '0';
--attribute mark_debug of INPARAMF_RDEN: signal is "true";

signal SPD_ALMOSTFULL  : std_logic;
signal SPD_ALMOSTEMPTY : std_logic;
signal SPD_EMPTY       : std_logic;
signal SPD_FULL        : std_logic;
signal SPD_RDCOUNT     : std_logic_vector (8 downto 0);
signal SPD_RDERR       : std_logic;
signal SPD_WRCOUNT     : std_logic_vector (8 downto 0);
signal SPD_WRERR       : std_logic;
signal SPD_RDEN        : std_logic := '0';
signal SPD_WREN        : std_logic := '0';

signal ram_rst100    : std_logic;
signal initRam100_0  : std_logic;
signal initRam100_1  : std_logic;
signal ram_rstGPIF   : std_logic;
signal initRamGPIF_0   : std_logic;
signal initRamGPIF_1   : std_logic;

signal RW_STATE      : unsigned(7 downto 0) := (others=>'0');
signal GPIF_CLK_intern : std_logic;
signal sample_rx    : std_logic_vector (i2s_width-1 downto 0);

signal GPIF_ADDR_int  : std_logic_vector(1 downto 0) := (others=>'0');
signal GPIF_ADDR_reversed: std_logic_vector(1 downto 0);
signal USB_CLK_SYNC  : std_logic := '0';
--attribute mark_debug of USB_CLK_SYNC: signal is "true";

signal paramno       : unsigned(gpif_width -1 downto 0);

signal BeatPulse: std_logic := '1';
signal BeatLengthWREN: std_logic := '1';
signal TEMPOPULSE: std_logic := '0';
signal TEMPOPULSE_rdy: std_logic := '0';

constant GPIF_II_READWAIT : integer := 2;
constant RW_PARAMCOUNT    : integer := 8;

signal Z01_GPIF_SLWR_int : std_logic := '1';
signal GPIF_SLWR_int     : std_logic := '1';
attribute mark_debug of Z01_GPIF_SLWR_int: signal is "true";
attribute mark_debug of GPIF_SLRD: signal is "true";
attribute mark_debug of GPIF_ADDR_reversed: signal is "true";
attribute mark_debug of RW_STATE: signal is "true";

signal FROM_RAMF_ALMOSTEMPTY : std_logic;

signal TESTSAW: unsigned(i2s_width -1 downto 0) := (others=>'0');
signal SAMPLES_SINCE_SEND: natural := 0;
signal TIMESINCESOF   : natural := 0;
signal FASTERSLOWER : std_logic:='0';
signal SAMPLEPACKET_RDY : std_logic := '0';

signal SYSPARAM :  integer;

signal m_axis_dout_tvalid : STD_LOGIC := '0';
signal m_axis_dout_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0) := (others=>'0');

signal beatCount     : unsigned(BEATMAXLOG2-1 downto 0) := to_unsigned(3, BEATMAXLOG2);
    
signal DivLengthInSamples : unsigned(std_flowwidth-1 downto 0) := (others=>'0');
signal SAMPLES_PER_DIV_DO : STD_LOGIC_VECTOR(std_flowwidth downto 0) := (others=>'0');
signal SPD_DI : STD_LOGIC_VECTOR(std_flowwidth downto 0) := (others=>'0');

signal init_calib_complete : std_logic := '0';
signal app_addr       : std_logic_vector(25 downto 0) := (others=>'0');
signal app_cmd        : std_logic_vector(2 downto 0) := (others=>'0');
signal app_en         : std_logic := '0';
signal app_wdf_data   : std_logic_vector(127 downto 0) := (others=>'0');
signal app_wdf_end    : std_logic := '0';
signal app_wdf_wren   : std_logic := '0';
signal app_rd_data       : std_logic_vector(127 downto 0) := (others=>'0');
signal app_rd_data_end   : std_logic := '0';
signal app_rd_data_valid : std_logic := '0';
signal app_rdy        : std_logic := '0';
signal app_wdf_rdy    : std_logic := '0';
signal app_sr_req     : std_logic := '0';
signal app_ref_req    : std_logic := '0';
signal app_zq_req     : std_logic := '0';
signal app_sr_active  : std_logic := '0';
signal app_ref_ack    : std_logic := '0';
signal app_zq_ack     : std_logic := '0';
signal ui_clk_sync_rst : std_logic := '0';
signal sys_rst : std_logic := '0';
--signal clk100  : std_logic := '0';

signal LCDFIFO_DI    : std_logic_vector (std_flowwidth-1 downto 0) := (others=>'0');
signal LCDFIFO_WREN  : STD_LOGIC := '0';
signal LCDFIFO_ALMOSTFULL : std_logic;

component clocks is
port (
    clksRdy : out std_logic;
    clk100  : in std_logic;
    clk200  : out std_logic;
    GPIF_CLK : out std_logic;
    FASTERSLOWER: in std_logic;
    USB_CLK_SYNC : in std_logic);
end component;

component lcd is
Generic(
    WAITCLOCKS : integer;
    PRESCALE   : integer
);
Port ( 
        clkin   : in STD_LOGIC;  
        LCDFIFO_ALMOSTFULL : out std_logic;
        LCD_RST : out std_logic := '0';
        LCD_CSX : out std_logic := '1';
        LCD_WRX : out std_logic := '1';
        LCD_RDX : out std_logic := '1';
        LCD_DCX : out std_logic := '1';
        LCD_D   : inout std_logic_vector(17 downto 0) := (others=>'0');
        LCD_IM  : out std_logic_vector(3 downto 0) := "0011";
        LCDFIFO_DI    : in std_logic_vector (std_flowwidth-1 downto 0);
        LCDFIFO_WREN  : in STD_LOGIC;
        ram_rst : in std_logic;
        InitRam : in std_logic);
end component;

component ram_active_rst is
Port ( clkin      : in STD_LOGIC;
       clksRdy    : in STD_LOGIC;
       ram_rst    : out STD_LOGIC := '0';
       initializeRam_out0 : out std_logic := '1';
       initializeRam_out1 : out std_logic := '1'
       );
end component;

component tempo is
Port ( 
    -- GPIF Signals
    GPIF_CLK      : in std_logic;               ---output clk 100 Mhz and 180 phase shift                       
    TEMPO_PULSE  : out std_logic := '0';
    i2s_cycle_begin : in STD_LOGIC;  
    
    TEMPOPULSE    : out std_logic := '0';     
    TEMPOPULSE_DATA : out std_logic_vector(gpif_width -1 downto 0) := (others=>'0');    
    BeatPulse     : in std_logic := '0';
    beatCount     : in unsigned(BEATMAXLOG2-1 downto 0);
    beatLengthWREN   : in std_logic := '0';
    MEM_IN25  : in std_logic_vector (std_flowwidth-1 downto 0);
    
    DivLengthInSamplesAverage : out unsigned(std_flowwidth-1 downto 0);
        
    initRamGPIF   : in std_logic
    );
        
end component;

component fm_engine_top is
Port ( 
    -- clk signals
    clk100     : in STD_LOGIC;
    
    -- division length in samples
    SAMPLES_PER_DIV_DO : in STD_LOGIC_VECTOR(std_flowwidth downto 0);
    
    -- out fifo signals
    OUTSAMPLEF_ALMOSTFULL: in std_logic;
    OUTSAMPLEF_DI      : out signed (i2s_width -1 downto 0) := (others=>'0');
    OUTSAMPLEF_WREN    : out std_logic := '0';
    
    -- in fifo signals
    INPARAMF_EMPTY    : in std_logic;
    INPARAMF_DO       : in std_logic_vector (gpif_width -1 downto 0);
    INPARAMF_RDEN     : out std_logic := '0';
        
    -- in sample signals
    INSAMPLEF_ALMOSTEMPTY: in std_logic;
    INSAMPLEF_DO       : in std_logic_vector (gpif_width -1 downto 0);
    INSAMPLEF_RDEN     : out std_logic := '0';
      
    -- ram control signals
    FROM_RAMF_ALMOSTEMPTY   : in std_logic;
    ram_rst100 : in std_logic;
    initRam100      : in std_logic
    );
end component;

component i2s_transmitter is
Port ( 
   clk100       : in  STD_LOGIC;
   gpif_clk     : in STD_LOGIC;
   i2s_bclk     : out STD_LOGIC;
   i2s_lrclk    : out STD_LOGIC;
   sample_rx    : out STD_LOGIC_VECTOR (i2s_width-1 downto 0) := (others => '0');
   I2S_DACSD    : out STD_LOGIC := '0';
   I2S_ADCSD    : in  STD_LOGIC;
   OUTSAMPLEF_DI: in  signed (i2s_width-1 downto 0) := (others=>'0');
   OUTSAMPLEF_WREN : in  STD_LOGIC := '0';
   i2s_cycle_begin : out STD_LOGIC := '0';
   
   ram_rstGPIF  : in std_logic;
   initRam100      : in std_logic
   );
end component;

--component mig_7series_0
--  port (
--  ddr2_dq       : inout std_logic_vector(15 downto 0);
--  ddr2_dqs_p    : inout std_logic_vector(1 downto 0);
--  ddr2_dqs_n    : inout std_logic_vector(1 downto 0);
--  ddr2_addr     : out   std_logic_vector(12 downto 0);
--  ddr2_ba       : out   std_logic_vector(1 downto 0);
--  ddr2_ras_n    : out   std_logic;
--  ddr2_cas_n    : out   std_logic;
--  ddr2_we_n     : out   std_logic;
--  ddr2_ck_p     : out   std_logic_vector(0 downto 0);
--  ddr2_ck_n     : out   std_logic_vector(0 downto 0);
--  ddr2_cke      : out   std_logic_vector(0 downto 0);
--  ddr2_odt      : out   std_logic_vector(0 downto 0);
--  app_addr                  : in    std_logic_vector(25 downto 0);
--  app_cmd                   : in    std_logic_vector(2 downto 0);
--  app_en                    : in    std_logic;
--  app_wdf_data              : in    std_logic_vector(127 downto 0);
--  app_wdf_end               : in    std_logic;
--  app_wdf_wren              : in    std_logic;
--  app_rd_data               : out   std_logic_vector(127 downto 0);
--  app_rd_data_end           : out   std_logic;
--  app_rd_data_valid         : out   std_logic;
--  app_rdy                   : out   std_logic;
--  app_wdf_rdy               : out   std_logic;
--  app_sr_req                : in    std_logic;
--  app_ref_req               : in    std_logic;
--  app_zq_req                : in    std_logic;
--  app_sr_active             : out   std_logic;
--  app_ref_ack               : out   std_logic;
--  app_zq_ack                : out   std_logic;
--  ui_clk                    : out   std_logic;
--  ui_clk_sync_rst           : out   std_logic;
--  init_calib_complete       : out   std_logic;
--  -- System Clock Ports
--  sys_clk_i                      : in    std_logic;
--  -- Reference Clock Ports
--  clk_ref_i                                : in    std_logic;
--  sys_rst                     : in    std_logic
--);
--end component mig_7series_0;

begin
TEMPO_LED <= TEMPO_PULSE or BEAT_BTN_HELD;
LED_G <= TEMPO_PULSE or BEAT_BTN_HELD;
GPIF_SLWR <= GPIF_SLWR_int;
GPIF_ADDR <= GPIF_ADDR_int;
GPIF_CLK  <= GPIF_CLK_intern;

i_lcd: lcd 
generic map(
    --WAITCLOCKS => 70000,
    WAITCLOCKS => 10,
    PRESCALE   => 1
)
port map (
        clkin   => GPIF_CLK_intern,  
        LCDFIFO_ALMOSTFULL => LCDFIFO_ALMOSTFULL,
        LCD_RST => LCD_RST,
        LCD_CSX => LCD_CSX,
        LCD_WRX => LCD_WRX,
        LCD_RDX => LCD_RDX,
        LCD_DCX => LCD_DCX,
        LCD_D   => LCD_D,
        LCD_IM  => LCD_IM,
        LCDFIFO_DI    => LCDFIFO_DI, 
        LCDFIFO_WREN  => LCDFIFO_WREN,
        ram_rst => ram_rstgpif,
        initRam => initRamGPIF_1
); 

i_clocks: clocks port map(
    clk100    => clk100,
    clk200    => clk200,
    clksrdy   => clksrdy,
    GPIF_CLK  => GPIF_CLK_intern,
    FASTERSLOWER => FASTERSLOWER,
    USB_CLK_SYNC => USB_CLK_SYNC
    );

i_ram_active_rst_100: ram_active_rst port map(
    clkin              => clk100,
    clksrdy            => clksrdy,
    ram_rst            => ram_rst100,
    initializeRam_out0  => initRam100_0,
    initializeRam_out1  => initRam100_1
    );

i_ram_active_rst_gpif: ram_active_rst port map(
    clkin              => GPIF_CLK_intern,
    clksrdy            => clksrdy,
    ram_rst            => ram_rstGPIF,
    initializeRam_out0  => initRamGPIF_0,
    initializeRam_out1  => initRamGPIF_1
    );
i_tempo: tempo Port Map( 
    -- GPIF Signals
    GPIF_CLK    =>  GPIF_CLK_intern,
    TEMPO_PULSE   => TEMPO_PULSE,
    i2s_cycle_begin => i2s_cycle_begin,
    
    DivLengthInSamplesAverage => DivLengthInSamples,
    
    TEMPOPULSE    => TEMPOPULSE,
    TEMPOPULSE_DATA => TEMPOPULSE_DATA,
    BeatPulse     => BeatPulse,
    beatCount     => beatCount,
    BeatLengthWREN => BeatLengthWREN,
    MEM_IN25  => MEM_IN25,
    initRamGPIF   => initRamGPIF_0
);


SC: if EXCLUDE_SIG_CHAIN = 0 generate
-- the following is replaceable by, for example, a spectral engine
i_fm_engine_top: fm_engine_top port map(
    -- clk signals
    clk100     => clk100,
    
    -- div length in samples
    SAMPLES_PER_DIV_DO => SAMPLES_PER_DIV_DO,
    
    -- out fifo signals
    OUTSAMPLEF_ALMOSTFULL=> OUTSAMPLEF_ALMOSTFULL,
    OUTSAMPLEF_DI      => OUTSAMPLEF_DI,
    OUTSAMPLEF_WREN    => OUTSAMPLEF_WREN,
    
    -- in fifo signals
    INPARAMF_EMPTY    => INPARAMF_EMPTY,
    INPARAMF_DO       => INPARAMF_DO,
    INPARAMF_RDEN     => INPARAMF_RDEN,
    
    -- in sample signals
    INSAMPLEF_ALMOSTEMPTY   => INSAMPLEF_ALMOSTEMPTY,
    INSAMPLEF_DO      => INSAMPLEF_DO,
    INSAMPLEF_RDEN    => INSAMPLEF_RDEN,
        
    -- ram control signals
    FROM_RAMF_ALMOSTEMPTY => FROM_RAMF_ALMOSTEMPTY,
    ram_rst100 => ram_rst100,
    initRam100    => initRam100_0
    );
end generate;

SC1: if EXCLUDE_SIG_CHAIN /= 0 generate
    INPARAMF_RDEN <= not INPARAMF_EMPTY;
    INSAMPLEF_RDEN <= not INSAMPLEF_ALMOSTEMPTY;
end generate;

------------------------------------------
-- Convert the samples into an I2S bitstream
------------------------------------------
i_i2s_transmitter: i2s_transmitter port map (
    clk100       => clk100,
    gpif_clk     => GPIF_CLK_intern,
    i2s_bclk     => i2s_bclk,
    i2s_lrclk    => i2s_lrclk,
    sample_rx    => sample_rx,
    I2S_DACSD    => I2S_DACSD,
    I2S_ADCSD    => I2S_ADCSD,
    OUTSAMPLEF_DI   => OUTSAMPLEF_DI,
    OUTSAMPLEF_WREN => OUTSAMPLEF_WREN, 
    i2s_cycle_begin=> i2s_cycle_begin,
    
    ram_rstGPIF => ram_rstGPIF,
    initRam100 => initramGPIF_1
); 

--u_mig_7series_0 : mig_7series_0
--port map (
--  -- Memory interface ports
--    ddr2_addr                      => ddr2_addr,
--    ddr2_ba                        => ddr2_ba,
--    ddr2_cas_n                     => ddr2_cas_n,
--    ddr2_ck_n                      => ddr2_ck_n,
--    ddr2_ck_p                      => ddr2_ck_p,
--    ddr2_cke                       => ddr2_cke,
--    ddr2_ras_n                     => ddr2_ras_n,
--    ddr2_we_n                      => ddr2_we_n,
--    ddr2_dq                        => ddr2_dq,
--    ddr2_dqs_n                     => ddr2_dqs_n,
--    ddr2_dqs_p                     => ddr2_dqs_p,
--    init_calib_complete            => init_calib_complete,
--    ddr2_odt                       => ddr2_odt,
--    -- Application interface ports
--    app_addr                       => app_addr,
--    app_cmd                        => app_cmd,
--    app_en                         => app_en,
--    app_wdf_data                   => app_wdf_data,
--    app_wdf_end                    => app_wdf_end,
--    app_wdf_wren                   => app_wdf_wren,
--    app_rd_data                    => app_rd_data,
--    app_rd_data_end                => app_rd_data_end,
--    app_rd_data_valid              => app_rd_data_valid,
--    app_rdy                        => app_rdy,
--    app_wdf_rdy                    => app_wdf_rdy,
--    app_sr_req                     => app_sr_req,
--    app_ref_req                    => app_ref_req,
--    app_zq_req                     => app_zq_req,
--    app_sr_active                  => app_sr_active,
--    app_ref_ack                    => app_ref_ack,
--    app_zq_ack                     => app_zq_ack,
--    ui_clk                         => clk100,
--    ui_clk_sync_rst                => ui_clk_sync_rst,
--    -- System Clock Ports
--    sys_clk_i                      => sys_clk_i,
--    -- Reference Clock Ports
--    clk_ref_i                      => clk200,
--    sys_rst                        => sys_rst
--);


------------------------------------------
-- Initialize a FIFO for the audio samples
------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                   
-- FIFO_DUALCLOCK_MACRO: Dual-Clock First-In, First-Out (FIFO) RAM Buffer
--                       Artix-7
-- Xilinx HDL Language Template, version 2015.2

-- Note -  This Unimacro model assumes the port directions to be "downto". 
--         Simulation of this model with "to" in the port directions could lead to erroneous results.

-----------------------------------------------------------------
-- DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width --
-- ===========|===========|============|=======================--
--   37-72    |  "36Kb"   |     512    |         9-bit         --
--   19-36    |  "36Kb"   |    1024    |        10-bit         --
--   19-36    |  "18Kb"   |     512    |         9-bit         -- USING THIS ONE  
--   10-18    |  "36Kb"   |    2048    |        11-bit         --
--   10-18    |  "18Kb"   |    1024    |        10-bit         --                                                                                                 
--    5-9     |  "36Kb"   |    4096    |        12-bit         --                                                                                                                                                        
--    5-9     |  "18Kb"   |    2048    |        11-bit         --
--    1-4     |  "36Kb"   |    8192    |        13-bit         --
--    1-4     |  "18Kb"   |    4096    |        12-bit         --
-----------------------------------------------------------------

OUTSAMPLEFIFO: FIFO_DUALCLOCK_MACRO
generic map (
  DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
  ALMOST_FULL_OFFSET => X"0300",  -- Sets almost full threshold
  ALMOST_EMPTY_OFFSET => X"0040", -- Sets the almost empty threshold
  DATA_WIDTH => i2s_width,        -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
  FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
port map (
  ALMOSTEMPTY => OUTSAMPLEF_ALMOSTEMPTY,   -- 1-bit output almost empty
  ALMOSTFULL  => OUTSAMPLEF_ALMOSTFULL,    -- 1-bit output almost full
  DO          => OUTSAMPLEF_DO,            -- Output data, width defined by DATA_WIDTH parameter
  EMPTY       => OUTSAMPLEF_EMPTY,         -- 1-bit output empty
  FULL        => OUTSAMPLEF_FULL,          -- 1-bit output full
  RDCOUNT     => OUTSAMPLEF_RDCOUNT,       -- Output read count, width determined by FIFO depth
  RDERR       => OUTSAMPLEF_RDERR,         -- 1-bit output read error
  WRCOUNT     => OUTSAMPLEF_WRCOUNT,       -- Output write count, width determined by FIFO depth
  WRERR       => OUTSAMPLEF_WRERR,         -- 1-bit output write error
  DI          => std_logic_vector(OUTSAMPLEF_DI),-- Input data, width defined by DATA_WIDTH parameter
  RDCLK       => GPIF_CLK_intern,        -- 1-bit input read clock
  RDEN        => OUTSAMPLEF_RDEN,       -- 1-bit input read 
  RST         => ram_rstGPIF,     -- 1-bit input reset
  WRCLK       => clk100,          -- 1-bit input write clock
  WREN        => OUTSAMPLEF_WREN        -- 1-bit input write enable
);

INSAMPLEFIFO: FIFO_DUALCLOCK_MACRO
generic map (
  DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
  ALMOST_FULL_OFFSET => X"0300",  -- Sets almost full threshold
  ALMOST_EMPTY_OFFSET => X"0040", -- Sets the almost empty threshold
  DATA_WIDTH => i2s_width,        -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
  FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
            -- Target BRAM, "18Kb" or "36Kb" 
port map (
  ALMOSTEMPTY => INSAMPLEF_ALMOSTEMPTY,   -- 1-bit output almost empty
  ALMOSTFULL  => INSAMPLEF_ALMOSTFULL,    -- 1-bit output almost full
  DO          => INSAMPLEF_DO,            -- Output data, width defined by DATA_WIDTH parameter
  EMPTY       => INSAMPLEF_EMPTY,         -- 1-bit output empty
  FULL        => INSAMPLEF_FULL,          -- 1-bit output full
  RDCOUNT     => INSAMPLEF_RDCOUNT,       -- Output read count, width determined by FIFO depth
  RDERR       => INSAMPLEF_RDERR,         -- 1-bit output read error
  WRCOUNT     => INSAMPLEF_WRCOUNT,       -- Output write count, width determined by FIFO depth
  WRERR       => INSAMPLEF_WRERR,         -- 1-bit output write error
  DI          => Z01_GPIF_DATA_rev, -- Input data, width defined by DATA_WIDTH parameter
  -- in loopback, both clocks are GPIF
  RDCLK       => clk100,          -- 1-bit input read clock
  RDEN        => INSAMPLEF_RDEN,  -- 1-bit input read 
  RST         => ram_rstGPIF,     -- 1-bit input reset
  WRCLK       => GPIF_CLK_intern,    -- 1-bit input write clock
  WREN        => Z01_INSAMPLEF_WREN  -- 1-bit input write enable
);

INPARAMFIFO: FIFO_DUALCLOCK_MACRO
generic map (
  DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
  ALMOST_FULL_OFFSET => X"0020",  -- Sets almost full threshold
  ALMOST_EMPTY_OFFSET => X"0020", -- Sets the almost empty threshold
  DATA_WIDTH => gpif_width,       -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
  FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
port map (
  ALMOSTEMPTY => INPARAMF_ALMOSTEMPTY,-- 1-bit output almost empty
  ALMOSTFULL  => INPARAMF_ALMOSTFULL, -- 1-bit output almost full
  DO          => INPARAMF_DO,         -- Output data, width defined by DATA_WIDTH parameter
  EMPTY       => INPARAMF_EMPTY,      -- 1-bit output empty
  FULL        => INPARAMF_FULL,       -- 1-bit output full
  RDCOUNT     => INPARAMF_RDCOUNT,    -- Output read count, width determined by FIFO depth
  RDERR       => INPARAMF_RDERR,      -- 1-bit output read error
  WRCOUNT     => INPARAMF_WRCOUNT,    -- Output write count, width determined by FIFO depth
  WRERR       => INPARAMF_WRERR,      -- 1-bit output write error
  DI          => Z02_GPIF_DATA,      -- Input data, width defined by DATA_WIDTH parameter
  RDCLK       => clk100,         -- 1-bit input read clock
  RDEN        => INPARAMF_RDEN,       -- 1-bit input read 
  RST         => ram_rstGPIF,    -- 1-bit input reset
  WRCLK       => GPIF_CLK_intern,   -- 1-bit input write clock
  WREN        => INPARAMF_WREN        -- 1-bit input write enable
);

SAMPLESPERDIVFIFO: FIFO_DUALCLOCK_MACRO
generic map (
  DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
  ALMOST_FULL_OFFSET => X"0020",  -- Sets almost full threshold
  ALMOST_EMPTY_OFFSET => X"0020", -- Sets the almost empty threshold
  DATA_WIDTH => std_flowwidth+1,       -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
  FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
port map (
  ALMOSTEMPTY => SPD_ALMOSTEMPTY,-- 1-bit output almost empty
  ALMOSTFULL  => SPD_ALMOSTFULL, -- 1-bit output almost full
  DO          => SAMPLES_PER_DIV_DO,         -- Output data, width defined by DATA_WIDTH parameter
  EMPTY       => SPD_EMPTY,      -- 1-bit output empty
  FULL        => SPD_FULL,       -- 1-bit output full
  RDCOUNT     => SPD_RDCOUNT,    -- Output read count, width determined by FIFO depth
  RDERR       => SPD_RDERR,      -- 1-bit output read error
  WRCOUNT     => SPD_WRCOUNT,    -- Output write count, width determined by FIFO depth
  WRERR       => SPD_WRERR,      -- 1-bit output write error
  DI          => SPD_DI,      -- Input data, width defined by DATA_WIDTH parameter
  RDCLK       => clk100,         -- 1-bit input read clock
  RDEN        => SPD_RDEN,       -- 1-bit input read 
  RST         => ram_rstGPIF,    -- 1-bit input reset
  WRCLK       => GPIF_CLK_intern,   -- 1-bit input write clock
  WREN        => SPD_WREN        -- 1-bit input write enable
);



DATABUF_LOOP:
for index in 0 to i2s_width -1 generate
   IOBUF_inst : IOBUF
    generic map (
       DRIVE => 12,
       IOSTANDARD => "DEFAULT",
       SLEW => "SLOW")
    port map (
       O  => Z00_GPIF_DATA_IN(index),     -- Buffer output
       IO => GPIF_DATA(index),   -- Buffer inout port (connect directly to top-level port)
       I  => GPIF_DATA_OUT(index),     -- Buffer input
       T  => GPIF_DATA_TRISTATE      -- 3-state enable input, high=input, low=output 
   );
end generate;

GPIF_ADDR_reversed <= GPIF_ADDR_int(0) & GPIF_ADDR_int(1); 

gpifproc: process(GPIF_CLK_intern) begin
if falling_edge(GPIF_CLK_intern) then
    BeatLengthWREN <= '0';
    LCDFIFO_WREN <= '0';
    Z01_INSAMPLEF_WREN <= INSAMPLEF_WREN;
    Z01_GPIF_DATA_rev <= Z00_GPIF_DATA_IN(7 downto 0) & Z00_GPIF_DATA_IN(15 downto 8);
    Z01_GPIF_SLWR_int <= GPIF_SLWR_int;
    Z01_GPIF_FLAGA <= GPIF_FLAGA;
    Z01_GPIF_FLAGB <= GPIF_FLAGB;
    BeatPulse <= '0';
if initRamGPIF_1 = '0' then
    if TempoPulse = '1' and unsigned(TEMPOPULSE_DATA) = 0 then
        SPD_DI <= (others=>'0');
        SPD_DI(std_flowwidth) <= '1';
        SPD_WREN <= '1';
    else
        SPD_DI <= '0' & std_logic_vector(DivLengthInSamples);
        SPD_WREN <= not SPD_ALMOSTFULL;
    end if;

    if TEMPOPULSE = '1' then
        TEMPOPULSE_rdy <= '1';
    end if;
    
    Z01_GPIF_DATA <= Z00_GPIF_DATA_IN;
    Z02_GPIF_DATA <= Z01_GPIF_DATA;    
    
       
    -- if this time is greater than a quarter second, leave USB sync mode
    if TIMESINCESOF > 48000000/4 then
        USB_CLK_SYNC <= '0';
    -- otherwise increment time since SOF
    else
        TIMESINCESOF <= TIMESINCESOF + 1;
    end if;
        
    -- increment the SAMPLES_SINCE_SEND every sample cycle begin
    if i2s_cycle_begin = '1' then
        SAMPLES_SINCE_SEND <= SAMPLES_SINCE_SEND + 1;
        -- every SAMPLESPERSENDth cycle, indicate that a write is required
        if SAMPLES_SINCE_SEND = SAMPLESPERSEND -1 then
            SAMPLES_SINCE_SEND <= 0;
            SAMPLEPACKET_RDY <= '1';
        end if;
    end if;
    
    -- if no operation in progress
    if RW_STATE = 0 then
        
        -- usually dont select chip, or write to fifos
        GPIF_SLCS <= '1';    
        INPARAMF_WREN  <= '0';
        INSAMPLEF_WREN <= '0';
        
        -- if sample is ready to send and OUTFIFO not ALMOSTEMPTY, prepare a send cycle. take precedence 
        -- for testing, ignore almostempty tag
        if SAMPLEPACKET_RDY = '1' and (OUTSAMPLEF_ALMOSTEMPTY = '0' or EXCLUDE_SIG_CHAIN = 1 ) then
            SAMPLEPACKET_RDY <= '0';
            GPIF_SLCS  <= '0';
            GPIF_ADDR_int <= GPIFADDR_WRITESAMPLE;
            OUTSAMPLEF_RDEN <= '1';
            RW_STATE <= to_unsigned(1, RW_STATE'length);

        elsif Z01_GPIF_FLAGA = '1' then
            -- set address to READSAMPLE and assert GPIF_SLCS (slave chip select, active low)
            GPIF_SLCS  <= '0';
            GPIF_ADDR_int <= GPIFADDR_READSAMPLE;
            RW_STATE <= to_unsigned(1, RW_STATE'length);
            -- set GPIF_DATA to high impedance 
            GPIF_DATA_TRISTATE <= '1';
            
        -- write timepulse given priority only because it would otherwise be ignored in testing
        -- (GPIF_FLAGB always '1')
        elsif TEMPOPULSE_rdy = '1' then
            -- set address to 01 and assert GPIF_SLCS (slave chip select, active low)
            GPIF_SLCS  <= '0';
            GPIF_ADDR_int <= GPIFADDR_WRITEPULSE;
            RW_STATE <= to_unsigned(1, RW_STATE'length);
                        
        -- if A(in) fifo is nonfull and in buffer is nonempty, prepare a parameter read cycle
        elsif INPARAMF_ALMOSTFULL = '0' and Z01_GPIF_FLAGB = '1' then 
            -- set address to 00 and assert GPIF_SLCS (slave chip select)
            GPIF_SLCS  <= '0';
            GPIF_ADDR_int <= GPIFADDR_READPARAM;
            RW_STATE <= to_unsigned(1, RW_STATE'length);
            -- set GPIF_DATA to high impedance 
            GPIF_DATA_TRISTATE <= '1';
        end if;
        
    -- if operation in progress
    else
        -- always increment RW_STATE
        RW_STATE <= RW_STATE + 1;
        
        -- address marks the direction and nature of the transfer
        case(GPIF_ADDR_int) is 
        -- if read param op
        when GPIFADDR_READPARAM =>                        
            -- enable outputs and wait for read
            if RW_STATE < 2 + GPIF_II_READWAIT then
                -- enable FX3 output
                GPIF_SLRD <= '0';
                GPIF_SLOE <= '0';
                
            -- write RW_PARAMCOUNT - first word to fifo
            elsif RW_STATE = 2 + GPIF_II_READWAIT then
                --send next Z01_GPIF_DATA to engine if param is not SOF
                if to_integer(unsigned(Z01_GPIF_DATA(GPIF_WIDTH-2 downto 0))) /= P_SOF then
                    INPARAMF_WREN <= '1';
                end if;
                
                -- capture sysparam in case this is a system read (this Z00 is good :)
                SYSPARAM <= to_integer(unsigned(Z01_GPIF_DATA(GPIF_WIDTH-2 downto 0)));
                
            -- full payload read for system params is available 5 cycles later 
            elsif RW_STATE = GPIF_II_READWAIT + RW_PARAMCOUNT - 1 then
                --stop reading here
                GPIF_SLRD <= '1';
                
            -- write up to the PARAMCOUNTth read to fifo
            elsif RW_STATE = GPIF_II_READWAIT + RW_PARAMCOUNT then
            elsif RW_STATE = GPIF_II_READWAIT + RW_PARAMCOUNT + 1 then
                MEM_IN25 <= Z02_GPIF_DATA(9 downto 0) & Z01_GPIF_DATA(14 downto 0);
            
                -- apply sysparam if applicable
                case SYSPARAM is
                when P_TEMPO       =>
                    beatLengthWREN <= '1';
                when P_BEATCOUNT   =>
                    beatCount    <= unsigned(Z01_GPIF_DATA(BEATMAXLOG2   -1 downto 0));
                when P_SOF         =>
                    -- reset time since SOF
                    TIMESINCESOF <= 0;
                    
                    --if we've already sent a sample more than 2 cycles ago, slow down the clock
                    if SAMPLES_SINCE_SEND < SAMPLESPERSEND and SAMPLES_SINCE_SEND > 2  then
                        USB_CLK_SYNC <= '1';
                        -- yes, setting 1 to slow down clock is backasswards to the data sheet
                        -- take it up with Xilinx
                        FASTERSLOWER <= '1';
                    -- otherwise if we have more than 2 samples to go, speed it up
                    elsif SAMPLES_SINCE_SEND < SAMPLESPERSEND-2 then
                        USB_CLK_SYNC <= '1';
                        FASTERSLOWER <= '0';
                    -- otherwise, maintain our clock
                    else
                        USB_CLK_SYNC <= '0';
                    end if;
                -- when beatpulse is provided
                when P_BEATPULSE  =>
                    
                    if unsigned(Z01_GPIF_DATA) = 0 then
                        BEAT_BTN_HELD <= '0';
                    else
                        BEAT_BTN_HELD <= '1';
                        BeatPulse <= '1';
                    end if;
                
                -- 4 bits: 3 program, 1 DorC
                when P_LCD_COMMAND  =>
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_COMMAND;
                    LCDFIFO_WREN <= '1';
                when P_LCD_DATA  =>             
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_DATA;
                    LCDFIFO_WREN <= '1';
                when P_LCD_RESET  =>
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_RESET;
                    LCDFIFO_WREN <= '1';
                when P_LCD_FILLRECT  =>
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_FILLRECT;
                    LCDFIFO_WREN <= '1';
                when P_LCD_SETCOLOR  =>
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_SETCOLOR;
                    LCDFIFO_WREN <= '1';
                when P_LCD_SETCOLUMN  =>
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_SETCOLUMN;
                    LCDFIFO_WREN <= '1';
                when P_LCD_SETROW  =>
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_SETROW;
                    LCDFIFO_WREN <= '1';
                when P_LCD_DRAWSQUARES  =>
                    LCDFIFO_DI(std_flowwidth-1 downto std_flowwidth-3) <= LCD_DRAWSQUARES;
                    LCDFIFO_WREN <= '1';
                                        
                --otherwise, explicitly do nothing
                when others=>
                end case;
                LCDFIFO_DI(std_flowwidth-4 downto 0) <= Z02_GPIF_DATA(6 downto 0) & Z01_GPIF_DATA(14 downto 0);
            -- end read cycle and write final word to fifo
            elsif RW_STATE = GPIF_II_READWAIT + RW_PARAMCOUNT + 2 then
                INPARAMF_WREN <= '0';
                GPIF_SLOE  <= '1';
                GPIF_SLCS  <= '1';
                RW_STATE <= to_unsigned(0, RW_STATE'length);
            end if;
            
        -- readsample is very similar to readparam
        -- (consider combining?)
        when GPIFADDR_READSAMPLE => 
            -- enable output, mark read, and wait 2 clocks for data
            if RW_STATE < 1 + GPIF_II_READWAIT then
                GPIF_SLRD <= '0';
                GPIF_SLOE <= '0';
            -- get 4 samples
            elsif RW_STATE < GPIF_II_READWAIT + HALFSAMPLESPERSEND - 1 then
                INSAMPLEF_WREN <= '1';
            -- get 1 sample, and stop read
            elsif RW_STATE < GPIF_II_READWAIT + HALFSAMPLESPERSEND + 1 then
                GPIF_SLRD <= '1';
            -- get final sample, end read cycle, and deselect chip, wait 4 cycles for flag to fall
            elsif RW_STATE < GPIF_II_READWAIT + HALFSAMPLESPERSEND + 5 then
                GPIF_SLCS  <= '1';
                GPIF_SLOE  <= '1';
                INSAMPLEF_WREN <= '0';
            -- otherwise return to idle sate
            else
                RW_STATE <= to_unsigned(0, RW_STATE'length);
            end if;
                      
        --if write op
        when GPIFADDR_WRITESAMPLE =>
            -- FOR TESTING PURPOSES!
            --GPIF_DATA_OUT <= std_logic_vector(TESTSAW(7 downto 0)) & std_logic_vector(TESTSAW(15 downto 8));
            GPIF_DATA_OUT <= OUTSAMPLEF_DO(7 downto 0) & OUTSAMPLEF_DO(15 downto 8);
           
            if RW_STATE <= HALFSAMPLESPERSEND then
                GPIF_DATA_TRISTATE <= '0';
                TESTSAW <= TESTSAW + 1;
            end if;
            
            -- write SAMPLES_SINCE_SEND - 2 samples
            if RW_STATE < HALFSAMPLESPERSEND then
                GPIF_SLWR_int <= '0';
            -- write SAMPLES_SINCE_SEND - 1th sample and end read
            elsif RW_STATE = HALFSAMPLESPERSEND then
                OUTSAMPLEF_RDEN <= '0';
            -- write final sample and end write cycle
            -- wait 3 clocks for FLAGA update
            elsif RW_STATE < HALFSAMPLESPERSEND + 4 then
                GPIF_DATA_TRISTATE <= '1';
                GPIF_SLWR_int  <= '1';
                GPIF_SLCS  <= '1';
            else
                RW_STATE <= to_unsigned(0, RW_STATE'length);
            end if;
            
        -- IE. When WRITEPULSE
        when others =>
            -- send the same thing 8 times to force a uC callback
            if RW_STATE < 9 then
                GPIF_SLWR_int <= '0';
                TEMPOPULSE_rdy <= '0';
                GPIF_DATA_OUT <= TEMPOPULSE_DATA;
                GPIF_DATA_TRISTATE <= '0';
            else
                    
                -- reset to idle state
                GPIF_DATA_TRISTATE <= '1';
                GPIF_SLWR_int <= '1';
                RW_STATE <= to_unsigned(0, RW_STATE'length);
            end if;
        end case;
    end if;
end if;
end if;
end process;

fiforden_proc: process(clk100)
begin
if rising_edge(clk100) then
if initRam100_1 = '0' then
    SPD_RDEN <= not SPD_ALMOSTEMPTY ;
end if;
end if;
end process;

mem_proc: process(clk100)
begin
if rising_edge(clk100) then

    app_addr <= std_logic_vector(unsigned(app_addr) + 1);
    app_cmd  <= "000";
    app_en   <= '0';
    if app_rdy = '1' then
        app_en   <= '1';
    end if;
    app_wdf_wren  <= '1';
end if;
end process;

end Behavioral;
