library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_nine_input_median is
end tb_nine_input_median;

architecture Behavioral of tb_nine_input_median is

    constant C_CLK_PERIOD : time := 10 ns;

    type integer_array_9 is array (0 to 8) of integer;

    signal rst : STD_LOGIC := '1';
    signal clk : STD_LOGIC := '0';

    signal pixel_in : STD_LOGIC_VECTOR(7 downto 0)
        := (others => '0');

    signal pixel_valid : STD_LOGIC := '0';
    signal pixel_ready : STD_LOGIC;

    signal median_out   : STD_LOGIC_VECTOR(7 downto 0);
    signal median_valid : STD_LOGIC;

    signal simulation_done : STD_LOGIC := '0';

begin

    DUT : entity work.nine_input_median
        generic map (
            G_PIXEL_WIDTH => 8
        )
        port map (
            clk          => clk,
            rst          => rst,
            pixel_in     => pixel_in,
            pixel_valid  => pixel_valid,
            pixel_ready  => pixel_ready,
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
    end process P_CLKGEN;

    P_STIMULUS : process

        procedure send_pixels (
            constant pixels      : in integer_array_9;
            signal clk_s         : in STD_LOGIC;
            signal pixel_ready_s : in STD_LOGIC;
            signal pixel_in_s    : out STD_LOGIC_VECTOR(7 downto 0);
            signal pixel_valid_s : out STD_LOGIC
        ) is
        begin
            wait until pixel_ready_s = '1';

            for k in 0 to 8 loop
                wait until falling_edge(clk_s);

                pixel_in_s <= STD_LOGIC_VECTOR(
                    to_unsigned(pixels(k), 8)
                );

                pixel_valid_s <= '1';

                wait until rising_edge(clk_s);
                wait for 1 ns;
            end loop;

            wait until falling_edge(clk_s);
            pixel_valid_s <= '0';
        end procedure send_pixels;

        procedure apply_reset (
            signal clk_s         : in STD_LOGIC;
            signal rst_s         : out STD_LOGIC;
            signal pixel_valid_s : out STD_LOGIC;
            signal pixel_in_s    : out STD_LOGIC_VECTOR(7 downto 0)
        ) is
        begin
            rst_s         <= '1';
            pixel_valid_s <= '0';
            pixel_in_s    <= (others => '0');

            wait until rising_edge(clk_s);
            wait until rising_edge(clk_s);

            wait until falling_edge(clk_s);
            rst_s <= '0';
        end procedure apply_reset;

    begin

        apply_reset(
            clk_s         => clk,
            rst_s         => rst,
            pixel_valid_s => pixel_valid,
            pixel_in_s    => pixel_in
        );

        send_pixels(
            pixels        => (12, 90, 3, 45, 20, 17, 200, 8, 30),
            clk_s         => clk,
            pixel_ready_s => pixel_ready,
            pixel_in_s    => pixel_in,
            pixel_valid_s => pixel_valid
        );

        wait until median_valid = '1';
        wait for 1 ns;

        assert median_out = STD_LOGIC_VECTOR(to_unsigned(20, 8))
            report "TEST 1 ERROR: expected median 20."
            severity failure;

        report "TEST 1 PASSED" severity note;

        apply_reset(clk, rst, pixel_valid, pixel_in);

        send_pixels(
            pixels        => (9, 8, 7, 6, 5, 4, 3, 2, 1),
            clk_s         => clk,
            pixel_ready_s => pixel_ready,
            pixel_in_s    => pixel_in,
            pixel_valid_s => pixel_valid
        );

        wait until median_valid = '1';
        wait for 1 ns;

        assert median_out = STD_LOGIC_VECTOR(to_unsigned(5, 8))
            report "TEST 2 ERROR: expected median 5."
            severity failure;

        report "TEST 2 PASSED" severity note;

        apply_reset(clk, rst, pixel_valid, pixel_in);

        send_pixels(
            pixels        => (77, 77, 77, 77, 77, 77, 77, 77, 77),
            clk_s         => clk,
            pixel_ready_s => pixel_ready,
            pixel_in_s    => pixel_in,
            pixel_valid_s => pixel_valid
        );

        wait until median_valid = '1';
        wait for 1 ns;

        assert median_out = STD_LOGIC_VECTOR(to_unsigned(77, 8))
            report "TEST 3 ERROR: expected median 77."
            severity failure;

        report "TEST 3 PASSED" severity note;

        apply_reset(clk, rst, pixel_valid, pixel_in);

        send_pixels(
            pixels        => (20, 21, 19, 22, 255, 18, 20, 21, 19),
            clk_s         => clk,
            pixel_ready_s => pixel_ready,
            pixel_in_s    => pixel_in,
            pixel_valid_s => pixel_valid
        );

        wait until median_valid = '1';
        wait for 1 ns;

        assert median_out = STD_LOGIC_VECTOR(to_unsigned(20, 8))
            report "TEST 4 ERROR: expected median 20."
            severity failure;

        report "TEST 4 PASSED" severity note;

        apply_reset(clk, rst, pixel_valid, pixel_in);

        send_pixels(
            pixels        => (101, 102, 99, 100, 0, 103, 98, 101, 100),
            clk_s         => clk,
            pixel_ready_s => pixel_ready,
            pixel_in_s    => pixel_in,
            pixel_valid_s => pixel_valid
        );

        wait until median_valid = '1';
        wait for 1 ns;

        assert median_out = STD_LOGIC_VECTOR(to_unsigned(100, 8))
            report "TEST 5 ERROR: expected median 100."
            severity failure;

        report "TEST 5 PASSED" severity note;
        report "ALL MEDIAN CORE TESTS PASSED" severity note;

        wait for C_CLK_PERIOD * 2;
        simulation_done <= '1';
        wait;

    end process P_STIMULUS;

end Behavioral;
