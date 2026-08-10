library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.TEXTIO.ALL;

entity tb_median_filter_file is
end tb_median_filter_file;

architecture Behavioral of tb_median_filter_file is

    constant C_CLK_PERIOD : time := 10 ns;

    constant C_IMAGE_WIDTH       : integer := 130;
    constant C_IMAGE_HEIGHT      : integer := 130;
    constant C_INPUT_PIXEL_COUNT : integer := C_IMAGE_WIDTH * C_IMAGE_HEIGHT;

    constant C_OUTPUT_WIDTH       : integer := C_IMAGE_WIDTH - 2;
    constant C_OUTPUT_HEIGHT      : integer := C_IMAGE_HEIGHT - 2;
    constant C_OUTPUT_PIXEL_COUNT : integer := C_OUTPUT_WIDTH * C_OUTPUT_HEIGHT;

    -- Files are relative to the simulator working directory. Run the MATLAB
    -- preparation script first and copy/use the generated files there.
    constant C_INPUT_FILE     : string := "noisy_pixels_padded_130.txt";
    constant C_REFERENCE_FILE : string := "reference_pixels_128.txt";
    constant C_OUTPUT_FILE    : string := "vhdl_output_128.txt";

    file F_INPUT     : text open read_mode  is C_INPUT_FILE;
    file F_REFERENCE : text open read_mode  is C_REFERENCE_FILE;
    file F_OUTPUT    : text open write_mode is C_OUTPUT_FILE;

    signal clk          : STD_LOGIC := '0';
    signal rst          : STD_LOGIC := '1';
    signal pixel_in     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal pixel_valid  : STD_LOGIC := '0';
    signal pixel_ready  : STD_LOGIC;
    signal median_out   : STD_LOGIC_VECTOR(7 downto 0);
    signal median_valid : STD_LOGIC;

    signal input_count_s  : integer range 0 to C_INPUT_PIXEL_COUNT  := 0;
    signal output_count_s : integer range 0 to C_OUTPUT_PIXEL_COUNT := 0;

    signal input_done      : STD_LOGIC := '0';
    signal output_done     : STD_LOGIC := '0';
    signal simulation_done : STD_LOGIC := '0';

begin

    DUT : entity work.median_filter_top
        generic map (
            G_IMAGE_WIDTH  => C_IMAGE_WIDTH,
            G_IMAGE_HEIGHT => C_IMAGE_HEIGHT,
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
        while simulation_done = '0' loop
            clk <= '0';
            wait for C_CLK_PERIOD / 2;
            clk <= '1';
            wait for C_CLK_PERIOD / 2;
        end loop;

        clk <= '0';
        wait;
    end process P_CLKGEN;

    P_INPUT : process
        variable input_line  : line;
        variable pixel_value : integer;
        variable input_count : integer := 0;
        variable read_good   : boolean;
    begin
        rst           <= '1';
        pixel_in      <= (others => '0');
        pixel_valid   <= '0';
        input_count_s <= 0;
        input_done    <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        while not endfile(F_INPUT) loop
            readline(F_INPUT, input_line);
            read(input_line, pixel_value, read_good);

            assert read_good
                report
                    "Input file contains an unreadable line. Line: " &
                    integer'image(input_count + 1)
                severity failure;

            assert pixel_value >= 0 and pixel_value <= 255
                report
                    "Invalid pixel value at input line " &
                    integer'image(input_count + 1)
                severity failure;

            assert input_count < C_INPUT_PIXEL_COUNT
                report "Input file contains more than 16900 pixels."
                severity failure;

            wait until falling_edge(clk);

            pixel_in <= STD_LOGIC_VECTOR(
                to_unsigned(pixel_value, pixel_in'length)
            );
            pixel_valid <= '1';

            -- Hold data and valid stable until a rising edge on which the
            -- DUT asserts pixel_ready.
            loop
                wait until rising_edge(clk);
                exit when pixel_ready = '1';
            end loop;

            input_count := input_count + 1;
            input_count_s <= input_count;
        end loop;

        wait until falling_edge(clk);
        pixel_valid <= '0';
        pixel_in    <= (others => '0');

        assert input_count = C_INPUT_PIXEL_COUNT
            report
                "Input pixel count mismatch. Expected 16900, received " &
                integer'image(input_count)
            severity failure;

        input_done <= '1';
        wait;
    end process P_INPUT;

    P_OUTPUT : process
        variable output_line    : line;
        variable reference_line : line;
        variable output_value   : integer;
        variable reference_value: integer;
        variable output_count   : integer := 0;
        variable reference_good : boolean;
    begin
        output_count_s <= 0;
        output_done    <= '0';

        wait until rst = '0';

        while output_count < C_OUTPUT_PIXEL_COUNT loop
            wait until rising_edge(clk);

            if median_valid = '1' then
                output_value := to_integer(unsigned(median_out));

                -- Every VHDL output is checked against the MATLAB reference
                -- produced from the same padded input image.
                assert not endfile(F_REFERENCE)
                    report "Reference file ended before all VHDL outputs were checked."
                    severity failure;

                readline(F_REFERENCE, reference_line);
                read(reference_line, reference_value, reference_good);

                assert reference_good
                    report
                        "Reference file contains an unreadable line. Line: " &
                        integer'image(output_count + 1)
                    severity failure;

                assert reference_value >= 0 and reference_value <= 255
                    report
                        "Invalid reference pixel at line " &
                        integer'image(output_count + 1)
                    severity failure;

                assert output_value = reference_value
                    report
                        "Median mismatch at output pixel " &
                        integer'image(output_count) &
                        ". Expected " & integer'image(reference_value) &
                        ", received " & integer'image(output_value)
                    severity failure;

                write(output_line, output_value);
                writeline(F_OUTPUT, output_line);

                output_count := output_count + 1;
                output_count_s <= output_count;
            end if;
        end loop;

        assert endfile(F_REFERENCE)
            report "Reference file contains more than 16384 pixels."
            severity failure;

        output_done <= '1';
        wait;
    end process P_OUTPUT;

    P_FINISH : process
    begin
        wait until input_done = '1' and output_done = '1';

        assert input_count_s = C_INPUT_PIXEL_COUNT
            report "Final input count check failed."
            severity failure;

        assert output_count_s = C_OUTPUT_PIXEL_COUNT
            report "Final output count check failed."
            severity failure;

        report
            "SELF-CHECK PASSED: 16900 input pixels processed and all " &
            "16384 VHDL outputs matched the MATLAB reference."
            severity note;

        wait for C_CLK_PERIOD * 2;
        simulation_done <= '1';
        wait;
    end process P_FINISH;

end Behavioral;
