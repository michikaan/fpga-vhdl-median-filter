library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_window_3x3 is
end tb_window_3x3;

architecture Behavioral of tb_window_3x3 is

    constant C_CLK_PERIOD : time := 10 ns;

    type integer_array_25_t is array (0 to 24) of integer;
    type integer_array_81_t is array (0 to 80) of integer;
    type integer_array_9_t  is array (0 to 8) of integer;

    constant C_INPUT_PIXELS : integer_array_25_t := (
         1,  2,  3,  4,  5,
         6,  7,  8,  9, 10,
        11, 12, 13, 14, 15,
        16, 17, 18, 19, 20,
        21, 22, 23, 24, 25
    );

    -- Nine 3x3 windows, flattened in row-major order.
    constant C_EXPECTED_WINDOWS : integer_array_81_t := (
         1,  2,  3,  6,  7,  8, 11, 12, 13,
         2,  3,  4,  7,  8,  9, 12, 13, 14,
         3,  4,  5,  8,  9, 10, 13, 14, 15,
         6,  7,  8, 11, 12, 13, 16, 17, 18,
         7,  8,  9, 12, 13, 14, 17, 18, 19,
         8,  9, 10, 13, 14, 15, 18, 19, 20,
        11, 12, 13, 16, 17, 18, 21, 22, 23,
        12, 13, 14, 17, 18, 19, 22, 23, 24,
        13, 14, 15, 18, 19, 20, 23, 24, 25
    );

    signal clk          : STD_LOGIC := '0';
    signal rst          : STD_LOGIC := '1';
    signal pixel_in     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal pixel_valid  : STD_LOGIC := '0';
    signal pixel_ready  : STD_LOGIC;
    signal window_ready : STD_LOGIC := '1';

    signal window_0 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_1 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_2 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_3 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_4 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_5 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_6 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_7 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_8 : STD_LOGIC_VECTOR(7 downto 0);
    signal window_valid : STD_LOGIC;

    signal window_count : integer range 0 to 9 := 0;

begin

    DUT : entity work.window_3x3
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
            window_ready => window_ready,
            window_0     => window_0,
            window_1     => window_1,
            window_2     => window_2,
            window_3     => window_3,
            window_4     => window_4,
            window_5     => window_5,
            window_6     => window_6,
            window_7     => window_7,
            window_8     => window_8,
            window_valid => window_valid
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
            constant value       : in integer;
            signal clk_s         : in STD_LOGIC;
            signal pixel_in_s    : out STD_LOGIC_VECTOR(7 downto 0);
            signal pixel_valid_s : out STD_LOGIC;
            signal pixel_ready_s : in STD_LOGIC
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

        wait until window_count = 9;
        wait for C_CLK_PERIOD * 2;
        report "ALL WINDOW_3X3 TESTS SUCCESSFUL" severity note;
        wait;
    end process P_STIMULUS;

    P_CHECKER : process(clk)
        variable received : integer_array_9_t;
        variable base_idx : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                window_count <= 0;

            elsif window_valid = '1' and window_ready = '1' then
                received(0) := to_integer(unsigned(window_0));
                received(1) := to_integer(unsigned(window_1));
                received(2) := to_integer(unsigned(window_2));
                received(3) := to_integer(unsigned(window_3));
                received(4) := to_integer(unsigned(window_4));
                received(5) := to_integer(unsigned(window_5));
                received(6) := to_integer(unsigned(window_6));
                received(7) := to_integer(unsigned(window_7));
                received(8) := to_integer(unsigned(window_8));

                assert window_count < 9
                    report "Unexpected extra 3x3 window."
                    severity failure;

                base_idx := window_count * 9;

                for i in 0 to 8 loop
                    assert received(i) = C_EXPECTED_WINDOWS(base_idx + i)
                        report
                            "Window " & integer'image(window_count) &
                            ", element " & integer'image(i) &
                            " mismatch. Expected " &
                            integer'image(C_EXPECTED_WINDOWS(base_idx + i)) &
                            ", received " & integer'image(received(i))
                        severity failure;
                end loop;

                window_count <= window_count + 1;
            end if;
        end if;
    end process P_CHECKER;

end Behavioral;
