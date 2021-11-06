library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

-- effect2d_tb is intended to be used to create bezier shapes in the spectral domain
-- it can be used for ex. harmonic width, global filter, or note filter
-- the path looks like the following

-- control [0, 1) -> 3 bezier curves -> 2d bezier -> out

entity effect2d_tb is
end effect2d_tb;

architecture arch_imp of effect2d_tb is

Constant PROCESS_BW: integer := 18;
Constant NOTECOUNT: integer := 1024;

signal clk                  : STD_LOGIC := '0';
signal rst                  : STD_LOGIC := '1';
signal Z00_control          : sfixed(1 downto -PROCESS_BW + 2) := to_sfixed(-1.0, 1, -PROCESS_BW + 2);
signal Z00_addr             : std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0) := (others => '0');

signal env_bezier_BEGnMIDnENDpoint_wr     : bezier2dWriteType := (others=>(others=>'0'));
signal env_bezier_BEGnMIDnENDpoint_wraddr : std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0) := (others => '0');
signal Z03_Spectral_X       : sfixed(1 downto -PROCESS_BW + 2) := to_sfixed(-0.98, 1, -PROCESS_BW + 2);
signal Z08_effect_out_normalized : sfixed(1 downto -PROCESS_BW + 2);
signal env_bezier_BEGnMIDnENDpoint_wrdata : std_logic_vector(PROCESS_BW - 1 downto 0);

signal run           : std_logic_vector(7 downto 0);

begin

clk <= not clk after 10ns;

dut: entity work.effect2d
port map (
    clk                       => clk                       ,
    rst                       => rst                       ,
    Z00_control               => Z00_control               ,
    Z00_addr                  => Z00_addr                  ,
    
    env_bezier_BEGnMIDnENDpoint_wr          => env_bezier_BEGnMIDnENDpoint_wr          ,
    env_bezier_BEGnMIDnENDpoint_wraddr      => env_bezier_BEGnMIDnENDpoint_wraddr      ,
    env_bezier_BEGnMIDnENDpoint_wrdata      => env_bezier_BEGnMIDnENDpoint_wrdata      ,
    Z03_Spectral_X            => Z03_Spectral_X            ,
    Z08_effect_out_normalized => Z08_effect_out_normalized ,
    
    run  => run
    );
           
flow_i: entity work.flow
Port map( 
    clk        => clk ,
    rst        => rst ,
    
    in_ready   => open,
    in_valid   => '1' ,
    out_ready  => '1' ,
    out_valid  => open,
    
    run        => run      
);

process (clk)
begin
  if rising_edge(clk) then
    if run(0) = '1' then
        --Z00_control <= resize(Z00_control + 0.01, Z00_control);
        --if Z00_control >= 1.0 then
        --    Z00_control <= to_sfixed(-0.99, Z00_control);
        --end if;
    end if;
    if run(2) = '1' then
        Z03_Spectral_X <= resize(Z03_Spectral_X + 0.01, Z03_Spectral_X);
        if Z03_Spectral_X >= 1.0 then
            Z03_Spectral_X <= to_sfixed(-1.0, Z03_Spectral_X);
            Z00_control <= resize(Z00_control + 0.1, Z00_control);
        end if;
    end if;
  end if;
end process;

-- cpu replacement process
process
begin
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr(0,0)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(1.0, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(0,1)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(1.0, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(0,2)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(1.0, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(1,0)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(0.1, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(1,1)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(0.1, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(1,2)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(0.1, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(2,0)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(0.0, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(2,1)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(0.5, Z00_control));
wait until rising_edge(clk);
    env_bezier_BEGnMIDnENDpoint_wr <= (others=>(others=>'0'));
    env_bezier_BEGnMIDnENDpoint_wr(2,2)  <= '1';
    env_bezier_BEGnMIDnENDpoint_wrdata   <= std_logic_vector(to_sfixed(1.0, Z00_control));

wait until rising_edge(clk);
wait until rising_edge(clk);
rst <= '0';
wait;
end process;

end arch_imp;