library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity window_3x3 is
    generic (
        G_IMAGE_WIDTH  : positive := 130;
        G_IMAGE_HEIGHT : positive := 130;
        G_PIXEL_WIDTH  : positive := 8
    );
    Port (
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;
        pixel_in     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        pixel_valid  : in  STD_LOGIC;
        pixel_ready  : out STD_LOGIC;

        window_ready : in  STD_LOGIC;
        window_0     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_1     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_2     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_3     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_4     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_5     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_6     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_7     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_8     : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_valid : out STD_LOGIC
    );
end window_3x3;

architecture Behavioral of window_3x3 is

    type line_buffer_t is array (0 to G_IMAGE_WIDTH-1)
        of STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);

    -- These memories intentionally have no full-array reset. Before the
    -- first valid 3x3 window can be asserted, two complete rows have already
    -- overwritten every location that will be read. Avoiding a memory reset
    -- also makes RAM inference more synthesis-friendly on FPGA devices.
    signal line_buffer1 : line_buffer_t;
    signal line_buffer2 : line_buffer_t;

    signal row_count    : integer range 0 to G_IMAGE_HEIGHT-1 := 0;
    signal column_count : integer range 0 to G_IMAGE_WIDTH-1  := 0;

    signal w00_reg, w01_reg, w02_reg : STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0) := (others => '0');
    signal w10_reg, w11_reg, w12_reg : STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0) := (others => '0');
    signal w20_reg, w21_reg, w22_reg : STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0) := (others => '0');

    signal window_valid_reg : STD_LOGIC := '0';
    signal pixel_ready_int  : STD_LOGIC;

begin

    assert G_IMAGE_WIDTH >= 3
        report "G_IMAGE_WIDTH must be at least 3."
        severity failure;

    assert G_IMAGE_HEIGHT >= 3
        report "G_IMAGE_HEIGHT must be at least 3."
        severity failure;

    -- This simple implementation allows only one pending window at a time.
    -- When the downstream median unit is busy, input backpressure propagates
    -- all the way to the source.
    pixel_ready_int <= '1'
        when window_valid_reg = '0' and rst = '0'
        else '0';

    pixel_ready  <= pixel_ready_int;
    window_valid <= window_valid_reg;

    window_0 <= w00_reg;
    window_1 <= w01_reg;
    window_2 <= w02_reg;
    window_3 <= w10_reg;
    window_4 <= w11_reg;
    window_5 <= w12_reg;
    window_6 <= w20_reg;
    window_7 <= w21_reg;
    window_8 <= w22_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                row_count        <= 0;
                column_count     <= 0;
                window_valid_reg <= '0';

                w00_reg <= (others => '0');
                w01_reg <= (others => '0');
                w02_reg <= (others => '0');
                w10_reg <= (others => '0');
                w11_reg <= (others => '0');
                w12_reg <= (others => '0');
                w20_reg <= (others => '0');
                w21_reg <= (others => '0');
                w22_reg <= (others => '0');

            else
                -- Consume the currently presented window. Because
                -- pixel_ready is low while a window is pending, this design
                -- intentionally introduces a bubble between valid windows.
                if window_valid_reg = '1' and window_ready = '1' then
                    window_valid_reg <= '0';
                end if;

                -- Accept a new input pixel only when there is no pending
                -- output window.
                if pixel_valid = '1' and pixel_ready_int = '1' then

                    -- Top row: row i-2 from line_buffer2.
                    w00_reg <= w01_reg;
                    w01_reg <= w02_reg;
                    w02_reg <= line_buffer2(column_count);

                    -- Middle row: row i-1 from line_buffer1.
                    w10_reg <= w11_reg;
                    w11_reg <= w12_reg;
                    w12_reg <= line_buffer1(column_count);

                    -- Bottom row: current incoming row.
                    w20_reg <= w21_reg;
                    w21_reg <= w22_reg;
                    w22_reg <= pixel_in;

                    -- Read-before-write behavior provides the previous rows.
                    line_buffer2(column_count) <= line_buffer1(column_count);
                    line_buffer1(column_count) <= pixel_in;

                    -- Counters are zero-based. The third row and third column
                    -- correspond to index 2, which is the first complete 3x3
                    -- neighborhood.
                    if row_count >= 2 and column_count >= 2 then
                        window_valid_reg <= '1';
                    else
                        window_valid_reg <= '0';
                    end if;

                    -- Advance row-major coordinates only for accepted pixels.
                    if column_count = G_IMAGE_WIDTH - 1 then
                        column_count <= 0;

                        if row_count = G_IMAGE_HEIGHT - 1 then
                            row_count <= 0;
                        else
                            row_count <= row_count + 1;
                        end if;
                    else
                        column_count <= column_count + 1;
                    end if;

                end if;
            end if;
        end if;
    end process;

end Behavioral;
