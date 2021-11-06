----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/21/2016 01:13:49 PM
-- Design Name: 
-- Module Name: fm_engine_top_tb - Behavioral
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
use ieee.numeric_std.all;

library work;
use work.memory_word_type.all;

Library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fm_engine_top_tb is
--  Port ( );
end fm_engine_top_tb;

architecture Behavioral of fm_engine_top_tb is

component fm_engine_top is
Port ( 
    -- clk signals
    clk100     : in STD_LOGIC;
    
    -- out fifo signals
    OUTSAMPLEF_ALMOSTFULL: in std_logic;
    OUTSAMPLEF_DI      : out signed (i2s_width -1 downto 0);
    OUTSAMPLEF_WREN    : out std_logic;
    
    -- in fifo signals
    INPARAMF_EMPTY    : in std_logic;
    INPARAMF_DO       : in std_logic_vector (gpif_width -1 downto 0);
    INPARAMF_RDEN     : out std_logic;
        
    -- in sample signals
    INSAMPLEF_ALMOSTEMPTY: in std_logic;
    INSAMPLEF_DO       : in std_logic_vector (gpif_width -1 downto 0);
    INSAMPLEF_RDEN     : out std_logic := '0';
        
    -- external SDRAM fifo access
    FROM_RAMF_DO   : in std_logic_vector (sdramWidth-1 downto 0);
    FROM_RAMF_RDEN : out std_logic := '0';
    TO_RAMF_DI     : out std_logic_vector (sdramWidth-1 downto 0);
    TO_RAMF_WRandTOG   : out STD_LOGIC := '0';
    PARAMF_WREN    : out STD_LOGIC := '0';
    PARAMF_DI      : out std_logic_vector (RAM_WIDTH18-1 downto 0) := (others=>'0');
              
    -- ram control signals
    FROM_RAMF_ALMOSTEMPTY : in std_logic;
    ram_rst100 : in std_logic;
    initRam100      : in std_logic
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
    GPIF_CLK : out std_logic;
    FASTERSLOWER: in std_logic;
    USB_CLK_SYNC : in std_logic);
end component;

component DDR2_CTRL is
Port (
    -- clocks 
    clk100        : in  STD_LOGIC;
    clk200        : in  STD_LOGIC;
    reset         : in  STD_LOGIC;
            
    -- SDRAM signals
    FROM_RAMF_ALMOSTEMPTY : out std_logic;
    SDRAM_CKE     : out   STD_LOGIC;
    SDRAM_CLK_P   : out   STD_LOGIC;
    SDRAM_CLK_N   : out   STD_LOGIC;
    SDRAM_CS      : out   STD_LOGIC;
    SDRAM_RAS     : out   STD_LOGIC;
    SDRAM_CAS     : out   STD_LOGIC;
    SDRAM_WE      : out   STD_LOGIC;
    SDRAM_DQS_P   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
    SDRAM_DQS_N   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
    SDRAM_DQM     : out   STD_LOGIC_VECTOR( 1 downto 0);
    SDRAM_ADDR    : out   STD_LOGIC_VECTOR(12 downto 0);
    SDRAM_BA      : out   STD_LOGIC_VECTOR( 1 downto 0);
    SDRAM_DATA    : inout STD_LOGIC_VECTOR(15 downto 0);
    
    -- external fifo access
    FROM_RAMF_DO   : out std_logic_vector (sdramWidth-1 downto 0);
    FROM_RAMF_RDEN : in std_logic := '0';
    TO_RAMF_DI     : in std_logic_vector (sdramWidth-1 downto 0) := (others=>'0');
    TO_RAMF_WRandTOG: in STD_LOGIC := '0';
    PARAMF_WREN    : in STD_LOGIC := '0';
    PARAMF_DI      : in std_logic_vector (RAM_WIDTH18-1 downto 0) := (others=>'0');
           
    initRam100      : in std_logic;
    ram_rst100   : in std_logic);
end component;
  
component ram_active_rst is
Port ( clkin      : in STD_LOGIC;
       clksRdy    : in STD_LOGIC;
       ram_rst    : out STD_LOGIC := '0';
       initializeRam_out : out std_logic := '1'
       );
end component;

constant clk100_period : time := 10 ns;
signal clk100:  STD_LOGIC := '0';
signal gpif_clk:  STD_LOGIC := '0';

-- out fifo signals
signal OUTSAMPLEF_ALMOSTFULL: std_logic := '0';
signal OUTSAMPLEF_DI      : signed (i2s_width -1 downto 0);
signal OUTSAMPLEF_WREN    : std_logic := '0';

-- in fifo signals
signal INPARAMF_EMPTY    : std_logic;
signal INPARAMF_DO       : std_logic_vector (gpif_width -1 downto 0);
signal INPARAMF_RDEN     : std_logic;
    
-- in fifo signals
signal INSAMPLEF_ALMOSTEMPTY    : std_logic := '0';
signal INSAMPLEF_DO       : std_logic_vector (gpif_width -1 downto 0) := (others=>'0');
signal INSAMPLEF_RDEN     : std_logic;

-- ram control signals
signal ram_rst100 : std_logic;
signal clksRdy    : STD_LOGIC;
signal initRam100    : std_logic;

-- output fifo signals
signal OUTSAMPLEF_DO          : std_logic_vector (i2s_width-1 downto 0);
signal OUTSAMPLEF_EMPTY       : std_logic;
signal OUTSAMPLEF_FULL        : std_logic;
signal OUTSAMPLEF_RDCOUNT     : std_logic_vector (9 downto 0);
signal OUTSAMPLEF_RDERR       : std_logic;
signal OUTSAMPLEF_WRCOUNT     : std_logic_vector (9 downto 0);
signal OUTSAMPLEF_WRERR       : std_logic;
signal OUTSAMPLEF_RDEN        : std_logic := '0';

-- input fifo signals
signal INPARAMF_ALMOSTFULL  : STD_LOGIC;  
signal INPARAMF_WREN        : STD_LOGIC := '0';
signal GPIF_DATA_reversed   : std_logic_vector (gpif_width -1 downto 0) := (others=>'0');
signal INPARAMF_ALMOSTEMPTY : std_logic;
signal INPARAMF_FULL        : std_logic;
signal INPARAMF_RDCOUNT     : std_logic_vector (9 downto 0);
signal INPARAMF_RDERR       : std_logic;
signal INPARAMF_WRCOUNT     : std_logic_vector (9 downto 0);
signal INPARAMF_WRERR       : std_logic;

signal ram_rstGPIF   : std_logic;
signal initRamGPIF   : std_logic;

constant numparams: integer := 38;
type paramarray is array (0 to numparams-1) of unsigned(9 downto 0);
signal A3 : paramarray := (others=>(others=>'0'));
signal A2 : paramarray := (others=>(others=>'0'));
signal A1 : paramarray := (others=>(others=>'0'));
signal A0 : paramarray := (others=>(others=>'0'));
type payloadarray is array (0 to numparams-1) of unsigned(19 downto 0);
signal PL : payloadarray := (others=>(others=>'0'));

constant INSTNUM : INTEGER := 0;
constant NOTENUM : INTEGER := 5;
constant OSCNUM  : INTEGER := 0;
constant WRITELOC: STD_LOGIC_VECTOR(9 downto 0) := 
std_logic_vector(to_unsigned(INSTNUM, instcountlog2)) &
std_logic_vector(to_unsigned(NOTENUM, voicesperinstlog2)) &
"00";


-- sdram signals
signal clk200        : STD_LOGIC;
signal reset         : STD_LOGIC := '0';
            
    -- SDRAM signals
signal FROM_RAMF_ALMOSTEMPTY    : std_logic := '1';
signal SDRAM_CKE     : STD_LOGIC;
signal SDRAM_CLK_P   : STD_LOGIC;
signal SDRAM_CLK_N   : STD_LOGIC;
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
signal FROM_RAMF_DO   : std_logic_vector (sdramWidth-1 downto 0);
signal FROM_RAMF_RDEN : std_logic := '0';
signal TO_RAMF_DI     : std_logic_vector (sdramWidth-1 downto 0) := (others=>'0');
signal TO_RAMF_WRandTOG : STD_LOGIC := '0';
signal PARAMF_WREN    : STD_LOGIC := '0';
signal PARAMF_DI      : std_logic_vector (RAM_WIDTH18-1 downto 0) := (others=>'0');

constant twoZeros: std_logic_vector(1 downto 0) := "00";

signal FASTERSLOWER : std_logic := '0';
signal USB_CLK_SYNC : std_logic := '0';
begin
-- Instantiate the Unit Under Test (UUT)
i_fm_engine_top: fm_engine_top PORT MAP (
    -- clk signals
    clk100       => clk100,
    
    -- out fifo signals
    OUTSAMPLEF_ALMOSTFULL=> OUTSAMPLEF_ALMOSTFULL,
    OUTSAMPLEF_DI      => OUTSAMPLEF_DI,
    OUTSAMPLEF_WREN    => OUTSAMPLEF_WREN,
    
    -- in fifo signals
    INPARAMF_EMPTY    => INPARAMF_EMPTY,
    INPARAMF_DO       => INPARAMF_DO,
    INPARAMF_RDEN     => INPARAMF_RDEN,
      
    INSAMPLEF_ALMOSTEMPTY => INSAMPLEF_ALMOSTEMPTY,
    INSAMPLEF_DO        => INSAMPLEF_DO,
    INSAMPLEF_RDEN      => INSAMPLEF_RDEN,
    
    -- external SDRAM fifo access
    FROM_RAMF_DO    => FROM_RAMF_DO,
    FROM_RAMF_RDEN  => FROM_RAMF_RDEN,
    TO_RAMF_DI      => TO_RAMF_DI,
    TO_RAMF_WRandTOG=> TO_RAMF_WRandTOG, 
    PARAMF_WREN    => PARAMF_WREN, 
    PARAMF_DI      => PARAMF_DI, 
       
    -- ram control signals
    FROM_RAMF_ALMOSTEMPTY   => FROM_RAMF_ALMOSTEMPTY,
    ram_rst100   => ram_rst100,
    initRam100      => initRamGPIF
); 

i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    ram_rst            => ram_rst100,
    clksRdy            => clksRdy,
    initializeRam_out  => initRam100
    );
    
i_ram_active_rst_gpif: ram_active_rst port map(
    clkin              => GPIF_CLK,
    ram_rst            => ram_rstGPIF,
    clksRdy            => clksRdy,
    initializeRam_out  => initRamGPIF
    );
    
i_sdram_model: sdram_model 
Generic Map(
    BANKCOUNT         => 4,
    sdram_rowcount    => 13,
    sdram_rows_to_sim => 2, -- only simulate 2 rows
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


i_ddr2_ctrl: DDR2_CTRL
Port map(
    -- clocks 
   clk100        => clk100,
   clk200        => clk200,
   reset         => reset,
   
   -- SDRAM signals
   FROM_RAMF_ALMOSTEMPTY    => FROM_RAMF_ALMOSTEMPTY,
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
           
   initRam100       => initRam100,
   ram_rst100  => ram_rst100
);

i_clocks: clocks port map(
    clksRdy   => clksRdy,
    clk100    => clk100,
    clk200    => clk200,
    GPIF_CLK  => GPIF_CLK,
    FASTERSLOWER => FASTERSLOWER,
    USB_CLK_SYNC => USB_CLK_SYNC
);

------------------------------------------
-- Initialize a FIFO for the audio samples
------------------------------------------
OUTFIFO : FIFO_DUALCLOCK_MACRO
generic map (
  DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
  ALMOST_FULL_OFFSET => X"0020",  -- Sets almost full threshold
  ALMOST_EMPTY_OFFSET => X"0020", -- Sets the almost empty threshold
  DATA_WIDTH => i2s_width,        -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
  FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
port map (
  ALMOSTEMPTY => OUTSAMPLEF_ALMOSTFULL,   -- 1-bit output almost empty
  ALMOSTFULL  => OUTSAMPLEF_ALMOSTFULL,    -- 1-bit output almost full
  DO          => OUTSAMPLEF_DO,            -- Output data, width defined by DATA_WIDTH parameter
  EMPTY       => OUTSAMPLEF_EMPTY,         -- 1-bit output empty
  FULL        => OUTSAMPLEF_FULL,          -- 1-bit output full
  RDCOUNT     => OUTSAMPLEF_RDCOUNT,       -- Output read count, width determined by FIFO depth
  RDERR       => OUTSAMPLEF_RDERR,         -- 1-bit output read error
  WRCOUNT     => OUTSAMPLEF_WRCOUNT,       -- Output write count, width determined by FIFO depth
  WRERR       => OUTSAMPLEF_WRERR,         -- 1-bit output write error
  DI          => std_logic_vector(OUTSAMPLEF_DI),-- Input data, width defined by DATA_WIDTH parameter
  RDCLK       => gpif_clk,        -- 1-bit input read clock
  RDEN        => OUTSAMPLEF_RDEN, -- 1-bit input read 
  RST         => ram_rstGPIF,     -- 1-bit input reset
  WRCLK       => clk100,          -- 1-bit input write clock
  WREN        => OUTSAMPLEF_WREN  -- 1-bit input write enable
);

------------------------------------------
-- Initialize a FIFO for input data
------------------------------------------
INFIFO : FIFO_DUALCLOCK_MACRO
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
  DI          => GPIF_DATA_reversed,         -- Input data, width defined by DATA_WIDTH parameter
  RDCLK       => clk100,         -- 1-bit input read clock
  RDEN        => INPARAMF_RDEN,       -- 1-bit input read 
  RST         => ram_rstGPIF,    -- 1-bit input reset
  WRCLK       => gpif_clk,   -- 1-bit input write clock
  WREN        => INPARAMF_WREN        -- 1-bit input write enable
);
    
-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

fmtestproc: process
begin
wait until initRamGPIF = '0';
OUTSAMPLEF_RDEN <= '1';

-- set rate of increment change
A3(0) <= to_unsigned(P_VOICE_PORTRATE, 10); -- paramtype
A2(0) <= unsigned(WRITELOC); -- notenum
A1(0) <= to_unsigned(OSCNUM, 10); -- osc
A0(0) <= to_unsigned(0, 10); -- unused
--PL(0) <= to_unsigned(2**13, 20);
PL(0) <= to_unsigned(2**17-1, 20);

-- set increment of 1 oscillator
A3(1) <= to_unsigned(P_VOICE_INC, 10); -- paramtype
A2(1) <= unsigned(WRITELOC); -- notenum
A1(1) <= to_unsigned(OSCNUM, 10); -- osc
A0(1) <= to_unsigned(0, 10); -- unused
PL(1) <= to_unsigned(2**12, 20);

-- modamp: none
-- feedback: none
    
-- set oscvolume to full
A3(2) <= to_unsigned(P_OSC_VOLUME, 10); -- paramtype
A2(2) <= unsigned(WRITELOC); -- notenum
A1(2) <= to_unsigned(OSCNUM, 10); -- osc
A0(2) <= to_unsigned(0, 10); -- unused
PL(2) <= to_unsigned(2**17-1, 20);
    
-- osc waveform  : square
A3(3) <= to_unsigned(P_OSC_WAVEFORM, 10); -- paramtype
A2(3) <= to_unsigned(INSTNUM, 10); -- notenum
A1(3) <= to_unsigned(OSCNUM, 10); -- osc
A0(3) <= to_unsigned(0, 10); -- unused
PL(3) <= to_unsigned(WF_SQUARE_I, 20);
    
-- osc modaddress: default
    
--set first envelope to full amplitude, fixed
A3(4) <= to_unsigned(P_VOICE_ENV, 10); -- paramtype
A2(4) <= unsigned(WRITELOC); -- notenum
A1(4) <= to_unsigned(0, 10); -- envnum
A0(4) <= to_unsigned(0, 10); -- unused
PL(4) <= to_unsigned(2**17-1, 20);

--set second envelope to OS 0 
--A3(5) <= to_unsigned(P_VOICE_ENV, 10); -- paramtype
--A2(5) <= unsigned(WRITELOC); -- notenum
--A1(5) <= to_unsigned(1, 10); -- envnum
--A0(5) <= to_unsigned(0, 10); -- unused
--PL(5) <= to_unsigned(2**19, 20);
    
--set second envelope to full amplitude, fixed
A3(5) <= to_unsigned(P_VOICE_ENV, 10); -- paramtype
A2(5) <= unsigned(WRITELOC); -- notenum
A1(5) <= to_unsigned(1, 10); -- envnum
A0(5) <= to_unsigned(0, 10); -- unused
PL(5) <= to_unsigned(2**17-1, 20);

--set third envelope to full amplitude, fixed
A3(6) <= to_unsigned(P_VOICE_ENV, 10); -- paramtype
A2(6) <= unsigned(WRITELOC); -- notenum
A1(6) <= to_unsigned(2, 10); -- envnum
A0(6) <= to_unsigned(0, 10); -- unused
PL(6) <= to_unsigned(2**17-1, 20);

--set fourth envelope to full amplitude, fixed
A3(7) <= to_unsigned(P_VOICE_ENV, 10); -- paramtype
A2(7) <= unsigned(WRITELOC); -- notenum
A1(7) <= to_unsigned(3, 10); -- envnum
A0(7) <= to_unsigned(0, 10); -- unused
PL(7) <= to_unsigned(2**17-1, 20);

-- channel 0 (left) pan value: full
A3(8) <= to_unsigned(P_VOICE_PAN, 10); -- paramtype
A2(8) <= to_unsigned(INSTNUM, 10); -- inst
A1(8) <= to_unsigned(0, 10); -- channel
A0(8) <= to_unsigned(0, 10); -- panmod
PL(8) <= to_unsigned(2**17-1, 20); -- val: full

-- channel 0 (left) pan value: full
A3(9) <= to_unsigned(P_VOICE_PAN, 10); -- paramtype
A2(9) <= to_unsigned(INSTNUM, 10); -- inst
A1(9) <= to_unsigned(0, 10); -- channel
A0(9) <= to_unsigned(1, 10); -- panmod
PL(9) <= to_unsigned(2**17-1, 20); -- val: full

-- channel 1 (right) pan value: full
A3(10) <= to_unsigned(P_VOICE_PAN, 10); -- paramtype
A2(10) <= to_unsigned(INSTNUM, 10); -- inst
A1(10) <= to_unsigned(1, 10); -- channel
A0(10) <= to_unsigned(0, 10); -- panmod
PL(10) <= to_unsigned(2**17-1, 20); -- val: full

-- channel 1 (right) pan value: full
A3(11) <= to_unsigned(P_VOICE_PAN, 10); -- paramtype
A2(11) <= to_unsigned(INSTNUM, 10); -- inst
A1(11) <= to_unsigned(1, 10); -- channel
A0(11) <= to_unsigned(1, 10); -- panmod
PL(11) <= to_unsigned(2**17-1, 20); -- val: full

-- set instvol vals and draw
-- instval mod 0 is set fixed
A3(12) <= to_unsigned(P_INSTVOL, 10); -- paramtype
A2(12) <= to_unsigned(INSTNUM, 10); -- inst
A1(12) <= to_unsigned(0, 10); -- instmod
A0(12) <= to_unsigned(0, 10); -- unused
PL(12) <= to_unsigned(2**17-1, 20); -- val: full

A3(13) <= to_unsigned(P_INSTVOL, 10); -- paramtype
A2(13) <= to_unsigned(INSTNUM, 10); -- inst
A1(13) <= to_unsigned(1, 10); -- instmod
A0(13) <= to_unsigned(0, 10); -- unused
PL(13) <= to_unsigned(2**17-1, 20); -- val: full

-- filter params(0):
-- set F to roughly 1000Hz
A3(14) <= to_unsigned(P_VOICE_FILT_F, 10); -- paramtype
A2(14) <= unsigned(WRITELOC); -- note num
A1(14) <= to_unsigned(0, 10); -- pole
A0(14) <= to_unsigned(0, 10); -- unused
PL(14) <= to_unsigned(2048*8, 20); -- roughly 1000 Hz

-- set Q to butterworth Q
A3(15) <= to_unsigned(P_VOICE_FILT_Q, 10); -- paramtype
A2(15) <= unsigned(WRITELOC); -- note num
A1(15) <= to_unsigned(0, 10); -- pole
A0(15) <= to_unsigned(0, 10); -- unused
PL(15)(17 downto 0) <= unsigned(to_signed(-32768, 18)); -- sqrt(2) for butterworth

-- set the type to lowpass
A3(16) <= to_unsigned(P_VOICE_FILT_TYP, 10); -- paramtype
A2(16) <= to_unsigned(INSTNUM, 10); -- instnum
A1(16) <= to_unsigned(0, 10); -- pole
A0(16) <= to_unsigned(0, 10); -- unused
PL(16) <= to_unsigned(FTYPE_LP_I, 20);

-- filter params(1):
-- set F to roughly 1000Hz
A3(17) <= to_unsigned(P_VOICE_FILT_F, 10); -- paramtype
A2(17) <= unsigned(WRITELOC); -- note num
A1(17) <= to_unsigned(1, 10); -- pole
A0(17) <= to_unsigned(0, 10); -- unused
PL(17) <= to_unsigned(2048*8, 20); -- roughly 1000 Hz

-- set Q to butterworth Q
A3(18) <= to_unsigned(P_VOICE_FILT_Q, 10); -- paramtype
A2(18) <= unsigned(WRITELOC); -- note num
A1(18) <= to_unsigned(1, 10); -- pole
A0(18) <= to_unsigned(0, 10); -- unused
PL(18)(17 downto 0) <= unsigned(to_signed(-32768, 18)); -- sqrt(2) for butterworth

-- set the type to lowpass
A3(19) <= to_unsigned(P_VOICE_FILT_TYP, 10); -- paramtype
A2(19) <= to_unsigned(INSTNUM, 10); -- instnum
A1(19) <= to_unsigned(1, 10); -- pole
A0(19) <= to_unsigned(0, 10); -- unused
PL(19) <= to_unsigned(FTYPE_LP_I, 20);

-- oneSHOT rate
-- let the rate be, in all stages, 2**13
A3(20) <= to_unsigned(P_ONESHOT_RATE, 10); -- paramtype
A2(20) <= unsigned(WRITELOC); -- notenum
A1(20) <= to_unsigned(0, 10); -- oneSHOT
A0(20) <= to_unsigned(0, 10); -- stage
PL(20) <= to_unsigned(2**13, 20);

A3(21) <= to_unsigned(P_ONESHOT_RATE, 10); -- paramtype
A2(21) <= unsigned(WRITELOC); -- notenum
A1(21) <= to_unsigned(0, 10); -- oneSHOT
A0(21) <= to_unsigned(1, 10); -- stage
PL(21) <= to_unsigned(2**13, 20);

-- except the sustain stage, which shall be 0 until release
A3(22) <= to_unsigned(P_ONESHOT_RATE, 10); -- paramtype
A2(22) <= unsigned(WRITELOC); -- notenum
A1(22) <= to_unsigned(0, 10); -- oneSHOT
A0(22) <= to_unsigned(2, 10); -- stage
PL(22) <= to_unsigned(0, 20);

A3(23) <= to_unsigned(P_ONESHOT_RATE, 10); -- paramtype
A2(23) <= unsigned(WRITELOC); -- notenum
A1(23) <= to_unsigned(0, 10); -- oneSHOT
A0(23) <= to_unsigned(3, 10); -- stage
PL(23) <= to_unsigned(2**13, 20);

-- alternate envelope startpoints between 0 and max
A3(24) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 10); -- paramtype
A2(24) <= to_unsigned(INSTNUM, 10); -- inst
A1(24) <= to_unsigned(0, 10); -- oneSHOT
A0(24) <= to_unsigned(0, 10); -- stage
PL(24) <= to_unsigned(0, 20);

A3(25) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 10); -- paramtype
A2(25) <= to_unsigned(INSTNUM, 10); -- inst
A1(25) <= to_unsigned(0, 10); -- oneSHOT
A0(25) <= to_unsigned(1, 10); -- stage
PL(25) <= to_unsigned(2**17-1, 20);

A3(26) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 10); -- paramtype
A2(26) <= to_unsigned(INSTNUM, 10); -- inst
A1(26) <= to_unsigned(0, 10); -- oneSHOT
A0(26) <= to_unsigned(2, 10); -- stage
PL(26) <= to_unsigned(0, 20);

A3(27) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 10); -- paramtype
A2(27) <= to_unsigned(INSTNUM, 10); -- inst
A1(27) <= to_unsigned(0, 10); -- oneSHOT
A0(27) <= to_unsigned(3, 10); -- stage
PL(27) <= to_unsigned(2**17-1, 20);

-- midpoints always quarter full
A3(28) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 10); -- paramtype
A2(28) <= to_unsigned(INSTNUM, 10); -- inst
A1(28) <= to_unsigned(0, 10); -- oneSHOT
A0(28) <= to_unsigned(0, 10); -- stage
PL(28) <= to_unsigned(2**15, 20);

A3(29) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 10); -- paramtype
A2(29) <= to_unsigned(INSTNUM, 10); -- inst
A1(29) <= to_unsigned(0, 10); -- oneSHOT
A0(29) <= to_unsigned(1, 10); -- stage
PL(29) <= to_unsigned(2**15, 20);

A3(30) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 10); -- paramtype
A2(30) <= to_unsigned(INSTNUM, 10); -- inst
A1(30) <= to_unsigned(0, 10); -- oneSHOT
A0(30) <= to_unsigned(2, 10); -- stage
PL(30) <= to_unsigned(2**15, 20);

A3(31) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 10); -- paramtype
A2(31) <= to_unsigned(INSTNUM, 10); -- inst
A1(31) <= to_unsigned(0, 10); -- oneSHOT
A0(31) <= to_unsigned(3, 10); -- stage
PL(31) <= to_unsigned(2**15, 20);

-- establish one delay line (on two channels)
-- the remainder are passthrough by default
-- on channel 0:
-- length : 512 samples
A3(32) <= to_unsigned(P_DELAY_SAMPLES, 10); -- paramtype
A2(32) <= to_unsigned(INSTNUM, 10); -- inst
A1(32) <= to_unsigned(0, 10); -- channel
A0(32) <= to_unsigned(0, 10); -- tapno
-- set delay to 700 samples, or roughly 10 mS
PL(32) <= to_unsigned(700, 20);

A3(33) <= to_unsigned(P_SAP_FORWARD_GAIN, 10); -- paramtype
A2(33) <= to_unsigned(INSTNUM, 10); -- inst
A1(33) <= to_unsigned(0, 10); -- channel
A0(33) <= to_unsigned(0, 10); -- tapno
PL(33) <= "00101111111111111111"; -- -.5

A3(34) <= to_unsigned(P_SAP_COLOR_GAIN, 10); -- paramtype
A2(34) <= to_unsigned(INSTNUM, 10); -- inst
A1(34) <= to_unsigned(0, 10); -- channel
A0(34) <= to_unsigned(0, 10); -- tapno
PL(34) <= "00010111111111111111"; -- .75

-- on channel 1:
-- length : 512 samples
A3(35) <= to_unsigned(P_DELAY_SAMPLES, 10); -- paramtype
A2(35) <= to_unsigned(INSTNUM, 10); -- inst
A1(35) <= to_unsigned(1, 10); -- channel
A0(35) <= to_unsigned(0, 10); -- tapno
-- set delay to 512 samples, or roughly 10 mS
PL(35) <= to_unsigned(700, 20);

A3(36) <= to_unsigned(P_SAP_FORWARD_GAIN, 10); -- paramtype
A2(36) <= to_unsigned(INSTNUM, 10); -- inst
A1(36) <= to_unsigned(1, 10); -- channel
A0(36) <= to_unsigned(0, 10); -- tapno
PL(36) <= "00101111111111111111"; -- -.5

A3(37) <= to_unsigned(P_SAP_COLOR_GAIN, 10); -- paramtype
A2(37) <= to_unsigned(INSTNUM, 10); -- inst
A1(37) <= to_unsigned(1, 10); -- channel
A0(37) <= to_unsigned(0, 10); -- tapno
PL(37) <= "00010111111111111111"; -- .75

-- polylfos: unused
-- detune draw/val: default

INPARAMF_WREN <= '1';
for paramno in 0 to numparams-1 loop
GPIF_DATA_reversed <= "100000" & STD_LOGIC_VECTOR(A3(paramno));
wait until rising_edge(gpif_clk);
GPIF_DATA_reversed <= "000000" & STD_LOGIC_VECTOR(A2(paramno));
wait until rising_edge(gpif_clk);
GPIF_DATA_reversed <= "000000" & STD_LOGIC_VECTOR(A1(paramno));
wait until rising_edge(gpif_clk);
GPIF_DATA_reversed <= "000000" & STD_LOGIC_VECTOR(A0(paramno));
wait until rising_edge(gpif_clk);
GPIF_DATA_reversed <= "00000000000" & STD_LOGIC_VECTOR(PL(paramno)(19 downto 15));
wait until rising_edge(gpif_clk);
GPIF_DATA_reversed <= '0' & STD_LOGIC_VECTOR(PL(paramno)(14 downto 0));
wait until rising_edge(gpif_clk);
GPIF_DATA_reversed <= (others=>'0');
wait until rising_edge(gpif_clk);
GPIF_DATA_reversed <= (others=>'0');
wait until rising_edge(gpif_clk);
end loop;
INPARAMF_WREN <= '0';

wait;

end process;
end Behavioral;
