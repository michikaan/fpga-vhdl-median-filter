library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_median_filter_top is
end tb_median_filter_top;

architecture Behavioral of tb_median_filter_top is

    constant C_CLK_PERIOD : time := 10 ns;

    type integer_array_25_t is array (0 to 24) of integer;
    type integer_array_9_t  is array (0 to 8) of integer;

    constant C_INPUT_PIXELS : integer_array_25_t := (
         1,  2,  3,  4,  5,
         6,  7,  8,  9, 10,
        11, 12, 13, 14, 15,
        16, 17, 18, 19, 20,
        21, 22, 23, 24, 25
    );

    constant C_EXPECTED_MEDIANS : integer_array_9_t := (
         7,  8,  9,
        12, 13, 14,
        17, 18, 19
    );

    signal clk          : STD_LOGIC := '0';
    signal rst          : STD_LOGIC := '1';
    signal pixel_in     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal pixel_valid  : STD_LOGIC := '0';
    signal pixel_ready  : STD_LOGIC;
    signal median_out   : STD_LOGIC_VECTOR(7 downto 0);
    signal median_valid : STD_LOGIC;

    signal median_count : integer range 0 to 9 := 0;

begin

    DUT : entity work.median_filter_top
        generic map (
            G_IMAGE_WIDTH  => 5,
            G_IMAGE_HEIGHT => 5,
            G_PIXEL_WIDTH  => 8
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
        while true loop
            clk <= '0';
            wait for C_CLK_PERIOD / 2;
            clk <= '1';
            wait for C_CLK_PERIOD / 2;
        end loop;
    end process P_CLKGEN;

    P_STIMULUS : process

        procedure send_pixel (
            constant value         : in integer;
            signal clk_s           : in STD_LOGIC;
            signal pixel_in_s      : out STD_LOGIC_VECTOR(7 downto 0);
            signal pixel_valid_s   : out STD_LOGIC;
            signal pixel_ready_s   : in STD_LOGIC
        ) is
        begin
            wait until falling_edge(clk_s);
            pixel_in_s    <= STD_LOGIC_VECTOR(to_unsigned(value, 8));
            pixel_valid_s <= '1';

            loop
                wait until rising_edge(clk_s);
                exit when pixel_ready_s = '1';
            end loop;
        end procedure send_pixel;

    begin
        rst         <= '1';
        pixel_valid <= '0';
        pixel_in    <= (others => '0');

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        for k in C_INPUT_PIXELS'range loop
            send_pixel(
                value         => C_INPUT_PIXELS(k),
                clk_s         => clk,
                pixel_in_s    => pixel_in,
                pixel_valid_s => pixel_valid,
                pixel_ready_s => pixel_ready
            );
        end loop;

        wait until falling_edge(clk);
        pixel_valid <= '0';
        pixel_in    <= (others => '0');

        wait until median_count = 9;
        wait for C_CLK_PERIOD * 2;

        report "ALL 5x5 TOP-LEVEL TESTS SUCCESSFUL" severity note;
        wait;
    end process P_STIMULUS;

    P_CHECKER : process(clk)
        variable received_median : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                median_count <= 0;

            elsif median_valid = '1' then
                received_median := to_integer(unsigned(median_out));

                if median_count < 9 then
                    if received_median = C_EXPECTED_MEDIANS(median_count) then
                        report
                            "Median " & integer'image(median_count) &
                            " correct: " & integer'image(received_median)
                            severity note;
                    else
                        report
                            "Median " & integer'image(median_count) &
                            " ERROR. Expected " & integer'image(C_EXPECTED_MEDIANS(median_count)) &
                            ", received " & integer'image(received_median)
                            severity error;
                    end if;

                    median_count <= median_count + 1;
                else
                    assert false
                        report "Unexpected extra median output."
                        severity error;
                end if;
            end if;
        end if;
    end process P_CHECKER;

end Behavioral;
