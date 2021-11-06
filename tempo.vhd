----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/03/2017 03:31:52 PM
-- Design Name: 
-- Module Name: tempo - Behavioral
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
use work.fixed_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity tempo is
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
    
    DivLengthInSamplesAverage : out unsigned(std_flowwidth-1 downto 0) := (others=>'0');
    
    initRamGPIF   : in std_logic
    );
        
end tempo;


architecture Behavioral of tempo is

signal DEBOUNCE_MS : integer := 1;
signal BeatPulseRcvd : std_logic := '0';

constant c24LOG2     : integer := 5;
signal CURRDIV24: unsigned (c24LOG2-1 downto 0) := (others=>'0');
signal CURRBEAT : unsigned(BEATMAXLOG2-1 downto 0) := (others=>'0');
signal CURRSAMPLE_IN_DIV   : ufixed (std_flowwidth-1 downto 0) := (others=>'0');

signal SAMPLES_SINCE_BEATPULSE : ufixed (std_flowwidth-1 downto 0) := (others=>'0');
signal SAMPLES_SINCE_BEAT      : ufixed (std_flowwidth-1 downto 0) := (others=>'0');
signal beatWriteIndex : unsigned(1 downto 0) := (others=>'0');
signal beatReadIndex  : unsigned(1 downto 0) := (others=>'0');
signal beatLengthSum : ufixed(std_flowwidth-1 downto -2) := (others=>'0');
type BTType is array (0 to 3) of ufixed (std_flowwidth-1 downto 0);
signal BEAT_LENGTH_IN_SAMPLES : BTType := (others=>(others=>'0'));

signal BeatLengthInSamplesAverage : ufixed(std_flowwidth-1 downto 0) := (others=>'0');
signal DivLengthInSamplesAverage_int : ufixed(std_flowwidth-1 downto 0) := (others=>'0');

constant ONE_OVER_24 : ufixed(1 downto -RAM_WIDTH18 + 2) := to_ufixed(1.0/24.0, 1, -RAM_WIDTH18 + 2);

begin
DivLengthInSamplesAverage <= unsigned(DivLengthInSamplesAverage_int);
gpifproc: process(GPIF_CLK) begin
if falling_edge(GPIF_CLK) then

if initRamGPIF = '0' then

    TEMPOPULSE <= '0';
    DivLengthInSamplesAverage_int <= resize(BeatLengthInSamplesAverage*ONE_OVER_24, DivLengthInSamplesAverage_int, fixed_wrap, fixed_truncate);

    -- increment the read index
    beatReadIndex <= beatReadIndex + 1;
    -- increase running sum, reset when appropriate
    if beatReadIndex = 0 then
        beatLengthSum <= resize(BEAT_LENGTH_IN_SAMPLES(0), beatLengthSum, fixed_wrap, fixed_truncate);
        BeatLengthInSamplesAverage <= resize(scalb(beatLengthSum,-2), BeatLengthInSamplesAverage, fixed_wrap, fixed_truncate);
    else
        beatLengthSum <= resize(beatLengthSum + BEAT_LENGTH_IN_SAMPLES(to_integer(beatReadIndex)), beatLengthSum, fixed_wrap, fixed_truncate);
    end if;
       
    -- indicate beatpulse received
    if BeatPulse = '1' then
        BeatPulseRcvd <= '1';
    end if;
    
    -- blink for longer at beginning of measure (beat = 0)
    -- centered on the beat
    -- the following code makes each pulse 800 samples long
    if (CURRDIV24 < 12  and SAMPLES_SINCE_BEAT < 400)
    or (CURRDIV24 > 11  and BeatLengthInSamplesAverage - SAMPLES_SINCE_BEAT < 400)
    then
        TEMPO_PULSE <= '1';
    else
        TEMPO_PULSE <= '0';
    end if;
    
    if i2s_cycle_begin = '1' then
        
        -- use this same logic to increase SAMPLES_SINCE_BEATPULSE
        -- limit time to 5 seconds
        if SAMPLES_SINCE_BEATPULSE < (5*FS_HZ) then
            SAMPLES_SINCE_BEATPULSE <= resize(SAMPLES_SINCE_BEATPULSE + 1, SAMPLES_SINCE_BEATPULSE, fixed_wrap, fixed_truncate);
        end if;
        
        SAMPLES_SINCE_BEAT      <= resize(SAMPLES_SINCE_BEAT      + 1, SAMPLES_SINCE_BEAT,      fixed_wrap, fixed_truncate);
                    
        -- timing stuff
        CURRSAMPLE_IN_DIV <= resize(CURRSAMPLE_IN_DIV + 1, CURRSAMPLE_IN_DIV, fixed_wrap, fixed_truncate);
        --- if beatpulse
        if BeatPulseRcvd = '1' then
            BeatPulseRcvd <= '0';
            -- reset counter
            SAMPLES_SINCE_BEATPULSE <= (others=>'0');
            -- debounce to 2ms = .002*48000, but natural
            -- and never save a value longer than 5 seconds
            if SAMPLES_SINCE_BEATPULSE >  DEBOUNCE_MS*4 and SAMPLES_SINCE_BEATPULSE < (5*FS_HZ) then
                -- increase store location for 4-point average
                beatWriteIndex <= beatWriteIndex+1;
                -- write this value to current slot
                BEAT_LENGTH_IN_SAMPLES(to_integer(beatWriteIndex)) <= SAMPLES_SINCE_BEATPULSE;
                -- and next one for recent bias 4 part average
                -- BEAT_LENGTH_IN_SAMPLES(to_integer(beatWriteIndex+1)) <= SAMPLES_SINCE_BEATPULSE;
                
                -- reset division and counter
                CURRDIV24 <= (others=>'0');
                CURRSAMPLE_IN_DIV <= (others=>'0');
                
                -- reset to final beat
                CURRBEAT <= BEATCOUNT -1;
            end if;
            
        -- otherwise, move to next division when appropriate
        elsif CURRSAMPLE_IN_DIV >= DivLengthInSamplesAverage_int then 
            CURRSAMPLE_IN_DIV <= (others=>'0');
            TEMPOPULSE <= '1';
            TEMPOPULSE_DATA <= STD_LOGIC_VECTOR(CURRBEAT) & STD_LOGIC_VECTOR(CURRDIV24);
            -- update values
            CURRDIV24   <= CURRDIV24  + 1;
            -- reset when necessary
            if CURRDIV24 = 23 then
                CURRDIV24 <= (others=>'0');
                SAMPLES_SINCE_BEAT <= (others=>'0');
                CURRBEAT    <= CURRBEAT   + 1;
                if CURRBEAT = BEATCOUNT -1 then
                    CURRBEAT <= (others=>'0');
                end if;
            end if;
        end if;
    end if;
    
    if beatLengthWREN = '1' then
        BEAT_LENGTH_IN_SAMPLES <= (others=>ufixed(MEM_IN25));
    end if;
end if;
end if;
end process;

end Behavioral;
