----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/18/2017 03:40:54 PM
-- Design Name: 
-- Module Name: clocks - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity clocks is
port (
    clksRdy : out std_logic;
    clk100  : in std_logic;
    clk200  : out std_logic;
    GPIF_CLK : out std_logic;
    FASTERSLOWER: in std_logic;
    USB_CLK_SYNC : in std_logic);
end clocks;

architecture Behavioral of clocks is

signal DADDR : std_logic_vector(6 downto 0) := (others=>'0');-- 7-bit input: DRP address
signal DEN   : std_logic := '0';       -- 1-bit input: DRP enable
signal DI    : std_logic_vector(15 downto 0);  -- 16-bit input: DRP data
signal DWE   : std_logic := '0';    -- 1-bit input: DRP write enable

signal noclk : std_logic := '0';
signal clkfb : std_logic := '0';
signal PSEN  : std_logic := '0';
signal PSENcount: unsigned(3 downto 0) := (others=>'0');
signal SLOW_PSINCDEC: std_logic := '0';
signal MS0_PSINCDEC : std_logic := '0';
signal MS1_PSINCDEC : std_logic := '0';
signal PSINCDEC : std_logic := '0';         -- 1-bit input: Phase shift increment/decrement
signal PSDONE: std_logic;             -- 1-bit output: Phase shift done
signal clk400      : std_logic;

signal FAST_USB_CLK_SYNC : std_logic;
signal MS0_USB_CLK_SYNC  : std_logic;

signal GPIF_CLK_int : std_logic;

-- need 48MHz clock from 100MHz clock
-- fractionally: 100MHz * (12/25) = 48MHz
-- impossible because MMCM does not support 120MHz internal clock
-- but if we take advantage of 1/8 accuracy of CLK0,
-- ((12/4)/(25/4)) =
-- 3/6.25 

begin
GPIF_CLK <= GPIF_CLK_int;

-- MMCME2_ADV: Advanced Mixed Mode Clock Manager
--             Artix-7
-- Xilinx HDL Language Template, version 2017.2

MMCME2_ADV_inst : MMCME2_ADV
generic map (
    BANDWIDTH => "OPTIMIZED",      -- Jitter programming (OPTIMIZED, HIGH, LOW
    CLKFBOUT_MULT_F => 12.0,    -- Multiply value for all CLKOUT (2.000-64.000).
    CLKFBOUT_PHASE => 0.0,     -- Phase offset in degrees of CLKFB (-360.000-360.000).
    
    -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
    CLKOUT0_DIVIDE_F => 25.0,   -- Divide amount for CLKOUT0 (1.000-128.000).
    CLKOUT1_DIVIDE => 6,
    CLKOUT2_DIVIDE => 3,
    CLKOUT3_DIVIDE => 1,
    CLKOUT4_DIVIDE => 1,
    CLKOUT5_DIVIDE => 1,
    CLKOUT6_DIVIDE => 1,
    -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
    CLKOUT0_DUTY_CYCLE => 0.5,
    CLKOUT1_DUTY_CYCLE => 0.5,
    CLKOUT2_DUTY_CYCLE => 0.5,
    CLKOUT3_DUTY_CYCLE => 0.5,
    CLKOUT4_DUTY_CYCLE => 0.5,
    CLKOUT5_DUTY_CYCLE => 0.5,
    CLKOUT6_DUTY_CYCLE => 0.5,
    -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
    CLKOUT0_PHASE => 0.0,
    CLKOUT1_PHASE => 0.0,
    CLKOUT2_PHASE => 0.0,
    CLKOUT3_PHASE => 0.0,
    CLKOUT4_PHASE => 0.0,
    CLKOUT5_PHASE => 0.0,
    CLKOUT6_PHASE => 0.0,
    CLKOUT4_CASCADE => FALSE,      -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
    COMPENSATION => "ZHOLD",       -- ZHOLD, BUF_IN, EXTERNAL, INTERNAL
    DIVCLK_DIVIDE => 1,            -- Master division value (1-106)
    -- REF_JITTER: Reference input jitter in UI (0.000-0.999).
    REF_JITTER1 => 0.0,
    REF_JITTER2 => 0.0,
    STARTUP_WAIT => FALSE,         -- Delays DONE until MMCM is locked (FALSE, TRUE)
    -- Spread Spectrum: Spread Spectrum Attributes
    SS_EN => "FALSE",              -- Enables spread spectrum (FALSE, TRUE)
    SS_MODE => "CENTER_HIGH",      -- CENTER_HIGH, CENTER_LOW, DOWN_HIGH, DOWN_LOW
    SS_MOD_PERIOD => 10000,        -- Spread spectrum modulation period (ns) (VALUES)
    -- USE_FINE_PS: Fine phase shift enable (TRUE/FALSE)
    CLKFBOUT_USE_FINE_PS => FALSE,
    CLKOUT0_USE_FINE_PS => TRUE,
    CLKOUT1_USE_FINE_PS => FALSE,
    CLKOUT2_USE_FINE_PS => FALSE,
    CLKOUT3_USE_FINE_PS => FALSE,
    CLKOUT4_USE_FINE_PS => FALSE,
    CLKOUT5_USE_FINE_PS => FALSE,
    CLKOUT6_USE_FINE_PS => FALSE
)
port map (
    -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
    CLKOUT0   => GPIF_CLK_int, -- 1-bit output: CLKOUT0
    CLKOUT0B  => open,     -- 1-bit output: Inverted CLKOUT0
    CLKOUT1   => clk200,   -- 1-bit output: CLKOUT1
    CLKOUT1B  => open,     -- 1-bit output: Inverted CLKOUT1
    CLKOUT2   => clk400,   -- 1-bit output: CLKOUT2
    CLKOUT2B  => open,     -- 1-bit output: Inverted CLKOUT2
    CLKOUT3   => open,     -- 1-bit output: CLKOUT3
    CLKOUT3B  => open,     -- 1-bit output: Inverted CLKOUT3
    CLKOUT4   => open,     -- 1-bit output: CLKOUT4
    CLKOUT5   => open,     -- 1-bit output: CLKOUT5
    CLKOUT6   => open,     -- 1-bit output: CLKOUT6
    -- DRP Ports: 16-bit (each) output: Dynamic reconfiguration ports
    DO => open,                     -- 16-bit output: DRP data
    DRDY => open,                 -- 1-bit output: DRP ready
    -- Dynamic Phase Shift Ports: 1-bit (each) output: Ports used for dynamic phase shifting of the outputs
    PSDONE => PSDONE,             -- 1-bit output: Phase shift done
    -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
    CLKFBOUT => clkfb,         -- 1-bit output: Feedback clock
    CLKFBOUTB => open,       -- 1-bit output: Inverted CLKFBOUT
    -- Status Ports: 1-bit (each) output: MMCM status ports
    CLKFBSTOPPED => open, -- 1-bit output: Feedback clock stopped
    CLKINSTOPPED => open, -- 1-bit output: Input clock stopped
    LOCKED => clksrdy,             -- 1-bit output: LOCK
    -- Clock Inputs: 1-bit (each) input: Clock inputs
    CLKIN1 => clk100,             -- 1-bit input: Primary clock
    CLKIN2 => clk100,             -- 1-bit input: Secondary clock
    -- Control Ports: 1-bit (each) input: MMCM control ports
    CLKINSEL => '1',           -- 1-bit input: Clock select, High=CLKIN1 Low=CLKIN2
    PWRDWN => '0',             -- 1-bit input: Power-down
    RST => '0',                   -- 1-bit input: Reset
    -- DRP Ports: 7-bit (each) input: Dynamic reconfiguration ports
    DADDR => DADDR,              -- 7-bit input: DRP address
    DCLK  => noclk,             -- 1-bit input: DRP clock
    DEN   => DEN,                -- 1-bit input: DRP enable
    DI    => DI,                 -- 16-bit input: DRP data
    DWE   => DWE,                -- 1-bit input: DRP write enable
    -- Dynamic Phase Shift Ports: 1-bit (each) input: Ports used for dynamic phase shifting of the outputs
    PSCLK => clk400,               -- 1-bit input: Phase shift clock
    PSEN => PSEN,                 -- 1-bit input: Phase shift enable
    PSINCDEC => PSINCDEC,         -- 1-bit input: Phase shift increment/decrement
    -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
    CLKFBIN => clkfb            -- 1-bit input: Feedback clock
);

  
metastableproc: process(GPIF_CLK_int)
begin
if rising_edge(GPIF_CLK_int) then
    -- increment phase (therefore frequency) when INFIFO not almostempty
    --SLOW_PSINCDEC <= not INSAMPLEF_ALMOSTEMPTY;
    SLOW_PSINCDEC <= FASTERSLOWER;
end if;
end process;

-- PSEN can only be asserted every 13th clk400
phaseshiftproc: process(clk400)
begin
if rising_edge(clk400) then
    -- cross clock domain here
    MS0_PSINCDEC <= SLOW_PSINCDEC;
    -- metastable version 1
    MS1_PSINCDEC <= MS0_PSINCDEC;
    -- stable version
    PSINCDEC <= MS1_PSINCDEC;

    --MS0
    MS0_USB_CLK_SYNC <= USB_CLK_SYNC;
    -- Stable
    FAST_USB_CLK_SYNC <= MS0_USB_CLK_SYNC;
    
    PSENcount <= PSENcount + 1;
    -- only modify phase if clock is slaved to USB host audio clock
    if PSENcount = 0 then
        PSEN <= '1' and FAST_USB_CLK_SYNC;
    else
        PSEN <= '0';
    end if;
    
--    if PSENcount = 12 then
--        PSENcount <= (others=>'0');
--    end if;
end if;
end process;
   -- End of MMCME2_ADV_inst instantiation

--The operations that must be implemented to reconfigure one value in the MMCM are:
--• Assert RST to the MMCM (do not deassert)
--• Set DADDR on the MMCM and assert DEN for one clock cycle
--• Wait for the DRDY signal to assert from the MMCM
--• Perform a bitwise AND between the DO port and the MASK (DI = DO and MASK)
--• Perform a bitwise OR between the DI signal and the BITSET (DI = DI | BITSET)
--• Assert DEN and DWE on the MMCM for one clock cycle
--• Wait for the DRDY signal to assert from the MMCM
--• Deassert RST to the MMCM
--• Wait for MMCM to lock
end Behavioral;