library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

-- effect1d simply transforms a control on range [0, 1) to a bezier curve

entity effect1d is
generic (
    NOTE_COUNT : integer := 128;
    CTRL_COUNT : integer := 4;
    PROCESS_BW : integer := 18
);
port (
    clk                  : in STD_LOGIC;
    rst                  : in STD_LOGIC;
    Z00_addr             : in std_logic_vector(integer(round(log2(real(NOTE_COUNT)))) - 1 downto 0);
    Z11_addr             : in std_logic_vector(integer(round(log2(real(NOTE_COUNT)))) - 1 downto 0);
    
    noteage_speed_wr     : in STD_LOGIC;   
    patchage_speed_wr    : in STD_LOGIC;   
    noteage_env_reset_wr  : in STD_LOGIC;   
    patchage_env_reset_wr : in STD_LOGIC;   
    ctrl_scale_wr        : in std_logic_vector(CTRL_COUNT-1 downto 0);
    ctrl_bezier_triple_wr: in std_logic_vector(2 downto 0);
    
    patchage_needsupdate_ready  : in  STD_LOGIC;   
    patchage_needsupdate_valid  : out STD_LOGIC;   
    patchage_needsupdate_addr   : out std_logic_vector(integer(round(log2(real(NOTE_COUNT)))) - 1 downto 0);
    
    noteage_needsupdate_ready   : in  STD_LOGIC;   
    noteage_needsupdate_valid   : out STD_LOGIC;   
    noteage_needsupdate_addr    : out std_logic_vector(integer(round(log2(real(NOTE_COUNT)))) - 1 downto 0);
    
    Z03_SineIndex        : in  sfixed;
    Z11_Control          : out sfixed;
    
    mm_wraddr: in std_logic_vector(integer(round(log2(real(NOTE_COUNT)))) - 1 downto 0);
    mm_wrdata: in std_logic_vector(PROCESS_BW - 1 downto 0);
    
    run           : std_logic_vector
    );
end effect1d;

architecture arch_imp of effect1d is
Constant ADDR_WIDTH : integer := integer(round(log2(real(NOTE_COUNT))));
signal Z03_PatchAge_Env : sfixed(1 downto -PROCESS_BW + 2);
signal Z03_NoteAge_Env  : sfixed(1 downto -PROCESS_BW + 2);

signal Z06_ctrl_sum     : sfixed(1 downto -PROCESS_BW + 2);
signal Z06_run          : std_logic_vector(4 downto 0);
signal Z01_addr         : std_logic_vector(integer(round(log2(real(NOTE_COUNT)))) - 1 downto 0);

begin


patchage_envelope: entity work.envelope
generic map(
    NOTE_COUNT => NOTE_COUNT,
    PROCESS_BW => PROCESS_BW
    )
Port Map ( 
    clk           => clk       ,
    rst           => rst       ,
    run           => run       ,
    
    speed_wr        => patchage_speed_wr     ,   
    speed_wrdata    => mm_wrdata ,
    speed_wraddr    => mm_wraddr ,     
    
    -- output fifo to indicate when phase is at end
    env_finished_ready     => patchage_needsupdate_ready    ,            
    env_finished_valid     => patchage_needsupdate_valid,
    env_finished_addr      => patchage_needsupdate_addr  ,
    
    -- input fifo to reset phase
    env_reset_addr  => mm_wraddr    ,      
    env_reset_wr    => noteage_env_reset_wr ,
    
    Z00_ADDR     => Z00_ADDR     ,
    Z03_ENV_OUT  => Z03_PatchAge_Env  
    
    );

noteage_envelope: entity work.envelope
generic map(
    NOTE_COUNT => NOTE_COUNT,
    PROCESS_BW => PROCESS_BW
)
Port Map ( 
    clk           => clk      ,
    rst           => rst      ,
    run           => run      ,
    
    speed_wr        => noteage_speed_wr,
    speed_wraddr    => mm_wraddr ,        
    speed_wrdata    => mm_wrdata ,
    
    -- output fifo to indicate when phase is at end
    env_finished_ready   => noteage_needsupdate_ready    ,            
    env_finished_valid   => noteage_needsupdate_valid,
    env_finished_addr    => noteage_needsupdate_addr  ,
    
    -- input fifo to reset phase
    env_reset_addr => mm_wraddr    ,      
    env_reset_wr      => noteage_env_reset_wr ,
     
    Z00_ADDR     => Z00_ADDR     ,
    Z03_ENV_OUT  => Z03_NoteAge_Env  
    
    );
    
addr_process:
process (clk)
begin
  if rising_edge(clk) then 
    if rst = '0' then
       if run(Z00) = '1' then
        Z01_addr <= Z00_addr;
       end if;
    end if;
  end if;
end process;
    
control_mixer_i: entity work.control_mixer
generic map(
    NOTE_COUNT => NOTE_COUNT
)
port map(
    clk                  => clk             ,
    rst                  => rst             ,
    Z02_PatchAge         => Z03_PatchAge_Env,
    Z02_NoteAge          => Z03_NoteAge_Env ,
    Z02_Index            => Z03_SineIndex   ,
    Z00_addr             => Z01_addr        ,
    
    ctrl_scale_wr        => ctrl_scale_wr  ,
    ctrl_scale_wraddr    => mm_wraddr      ,
    ctrl_scale_wrdata    => mm_wrdata    ,
        
    Z05_sum              => Z06_ctrl_sum  ,
    
    run                  => run                  
);

Z06_run <= run(Z09 downto Z05);
control_bez: entity work.bezier_mm 
generic map(
    NOTE_COUNT => NOTE_COUNT
)
port map(
    clk                  => clk                  ,
    rst                  => rst                  ,
    
    Z00_ctrl_in          => Z06_ctrl_sum         ,
    bezier_triple_wr     => ctrl_bezier_triple_wr,
    bezier_triple_wraddr => mm_wraddr ,
    bezier_triple_wrdata => mm_wrdata ,
    
    Z05_Bez_Out          => Z11_Control          ,
    run                  => Z06_run                  
    );

end arch_imp;
