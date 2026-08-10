library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_windowmedian_unit is
end tb_windowmedian_unit;

architecture Behavioral of tb_windowmedian_unit is

    constant C_CLK_PERIOD : time := 10 ns;

    signal clk          : STD_LOGIC := '0';
    signal rst          : STD_LOGIC := '1';
    signal window_0     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_1     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_2     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_3     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_4     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_5     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_6     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_7     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_8     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_valid : STD_LOGIC := '0';
    signal window_ready : STD_LOGIC;
    signal median_out   : STD_LOGIC_VECTOR(7 downto 0);
    signal median_valid : STD_LOGIC;

    signal simulation_done : STD_LOGIC := '0';

begin

    DUT : entity work.windowmedian_unit
        generic map (
            G_PIXEL_WIDTH => 8
        )
        port map (
            clk          => clk,
            rst          => rst,
            window_0     => window_0,
            window_1     => window_1,
            window_2     => window_2,
            window_3     => window_3,
            window_4     => window_4,
            window_5     => window_5,
            window_6     => window_6,
            window_7     => window_7,
            window_8     => window_8,
            window_valid => window_valid,
            window_ready => window_ready,
            median_out   => median_out,
            median_valid => median_valid
        );

    P_CLKGEN : process
    begin
        while simulation_done = '0' loop
            clk <= '0';
            wait for C_CLK_PERIOD / 2;
            clk <= '1';
            wait for C_CLK_PERIOD / 2;
        end loop;

        clk <= '0';
        wait;
    end process;

    P_STIMULUS : process
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        wait until window_ready = '1';
        wait until falling_edge(clk);

        window_0 <= STD_LOGIC_VECTOR(to_unsigned(9, 8));
        window_1 <= STD_LOGIC_VECTOR(to_unsigned(1, 8));
        window_2 <= STD_LOGIC_VECTOR(to_unsigned(7, 8));
        window_3 <= STD_LOGIC_VECTOR(to_unsigned(3, 8));
        window_4 <= STD_LOGIC_VECTOR(to_unsigned(5, 8));
        window_5 <= STD_LOGIC_VECTOR(to_unsigned(2, 8));
        window_6 <= STD_LOGIC_VECTOR(to_unsigned(8, 8));
        window_7 <= STD_LOGIC_VECTOR(to_unsigned(4, 8));
        window_8 <= STD_LOGIC_VECTOR(to_unsigned(6, 8));
        window_valid <= '1';

        wait until rising_edge(clk);
        wait until falling_edge(clk);
        window_valid <= '0';

        wait until median_valid = '1';
        wait for 1 ns;

        assert median_out = STD_LOGIC_VECTOR(to_unsigned(5, 8))
            report "windowmedian_unit ERROR: expected median 5"
            severity failure;

        report "WINDOWMEDIAN UNIT TEST PASSED" severity note;

        wait for C_CLK_PERIOD * 2;
        simulation_done <= '1';
        wait;
    end process;

end Behavioral;
