library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_paralel_to_series_converter is
end tb_paralel_to_series_converter;

architecture Behavioral of tb_paralel_to_series_converter is

    constant C_CLK_PERIOD : time := 10 ns;

    type integer_array_9_t is array (0 to 8) of integer;
    constant C_EXPECTED : integer_array_9_t := (
        10, 20, 30, 40, 50, 60, 70, 80, 90
    );

    signal clk                : STD_LOGIC := '0';
    signal rst                : STD_LOGIC := '1';

    signal window_0           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_1           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_2           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_3           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_4           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_5           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_6           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_7           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_8           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal window_valid       : STD_LOGIC := '0';
    signal window_ready       : STD_LOGIC;

    signal median_pixel_in    : STD_LOGIC_VECTOR(7 downto 0);
    signal median_pixel_valid : STD_LOGIC;
    signal median_pixel_ready : STD_LOGIC := '0';
    signal median_valid       : STD_LOGIC := '0';

    signal accepted_count     : integer range 0 to 9 := 0;
    signal simulation_done    : STD_LOGIC := '0';

begin

    DUT : entity work.paralel_to_series_converter
        generic map (
            G_PIXEL_WIDTH => 8
        )
        port map (
            clk                => clk,
            rst                => rst,
            window_0           => window_0,
            window_1           => window_1,
            window_2           => window_2,
            window_3           => window_3,
            window_4           => window_4,
            window_5           => window_5,
            window_6           => window_6,
            window_7           => window_7,
            window_8           => window_8,
            window_valid       => window_valid,
            window_ready       => window_ready,
            median_pixel_in    => median_pixel_in,
            median_pixel_valid => median_pixel_valid,
            median_valid       => median_valid,
            median_pixel_ready => median_pixel_ready
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
    end process P_CLKGEN;

    P_STIMULUS : process
    begin
        rst                <= '1';
        window_valid       <= '0';
        median_pixel_ready <= '0';
        median_valid       <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        wait until window_ready = '1';
        wait until falling_edge(clk);

        window_0 <= STD_LOGIC_VECTOR(to_unsigned(10, 8));
        window_1 <= STD_LOGIC_VECTOR(to_unsigned(20, 8));
        window_2 <= STD_LOGIC_VECTOR(to_unsigned(30, 8));
        window_3 <= STD_LOGIC_VECTOR(to_unsigned(40, 8));
        window_4 <= STD_LOGIC_VECTOR(to_unsigned(50, 8));
        window_5 <= STD_LOGIC_VECTOR(to_unsigned(60, 8));
        window_6 <= STD_LOGIC_VECTOR(to_unsigned(70, 8));
        window_7 <= STD_LOGIC_VECTOR(to_unsigned(80, 8));
        window_8 <= STD_LOGIC_VECTOR(to_unsigned(90, 8));
        window_valid <= '1';

        wait until rising_edge(clk);
        wait until falling_edge(clk);
        window_valid <= '0';

        -- Accept the first three pixels.
        median_pixel_ready <= '1';
        wait until accepted_count = 3;
        wait until falling_edge(clk);

        -- Apply backpressure. The converter must hold pixel 3 (value 40)
        -- stable and must not advance send_index while ready is low.
        median_pixel_ready <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        assert median_pixel_valid = '1'
            report "Converter dropped valid while downstream ready was low."
            severity failure;

        assert median_pixel_in = STD_LOGIC_VECTOR(to_unsigned(40, 8))
            report "Converter did not hold the blocked pixel stable."
            severity failure;

        wait until falling_edge(clk);
        median_pixel_ready <= '1';

        wait until accepted_count = 9;

        -- Emulate completion of the downstream median calculation.
        wait until falling_edge(clk);
        median_valid <= '1';
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        median_valid <= '0';

        wait until window_ready = '1';

        report "PARALLEL-TO-SERIAL BACKPRESSURE TEST PASSED" severity note;
        wait for C_CLK_PERIOD * 2;
        simulation_done <= '1';
        wait;
    end process P_STIMULUS;

    P_CHECKER : process(clk)
        variable received_value : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                accepted_count <= 0;

            elsif median_pixel_valid = '1' and median_pixel_ready = '1' then
                if accepted_count < 9 then
                    received_value := to_integer(unsigned(median_pixel_in));

                    assert received_value = C_EXPECTED(accepted_count)
                        report
                            "Serial pixel order mismatch at index " &
                            integer'image(accepted_count) &
                            ". Expected " &
                            integer'image(C_EXPECTED(accepted_count)) &
                            ", received " & integer'image(received_value)
                        severity failure;

                    accepted_count <= accepted_count + 1;
                else
                    assert false
                        report "Unexpected extra serialized pixel."
                        severity failure;
                end if;
            end if;
        end if;
    end process P_CHECKER;

end Behavioral;
