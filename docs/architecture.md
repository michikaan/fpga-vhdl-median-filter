# Architecture

The design implements a grayscale 3x3 median filter as a streaming VHDL pipeline.

## Data flow

1. MATLAB creates a 128x128 grayscale noisy image.
2. One-pixel replicate padding expands the input to 130x130.
3. `window_3x3` accepts pixels in row-major order and uses two line buffers plus the live row to build each 3x3 neighborhood.
4. `paralel_to_series_converter` captures the nine window pixels and sends them sequentially.
5. `nine_input_median` collects nine values, sorts them over multiple clock cycles, and outputs element 4 of the sorted array.
6. The file-based testbench writes the 16384 output pixels back to a text file.

## Handshake

The project uses a valid/ready streaming convention. A transfer occurs on a rising clock edge when both `valid` and `ready` are high. If the receiver is not ready, the sender keeps data and valid stable.

## Window generation

For a 3x3 kernel, only the previous two image rows must be stored. The current row arrives through `pixel_in`.

- `line_buffer2` represents row i-2.
- `line_buffer1` represents row i-1.
- the incoming stream represents row i.

A valid 3x3 window first exists when both the zero-based row and column counters reach 2.

For a 130x130 padded image, valid center positions span rows 2 through 129 and columns 2 through 129, producing 128x128 = 16384 windows.

## Median core

The median core uses three main activities:

- collect nine pixels,
- perform adjacent bubble-sort comparisons,
- assert `median_valid` for the resulting middle value.

The implementation favors clarity and verification over throughput optimization.
