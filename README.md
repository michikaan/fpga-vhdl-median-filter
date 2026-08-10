# FPGA VHDL 3×3 Median Filter

A streaming grayscale image-processing design implemented in **VHDL** and verified with **MATLAB** and **Xilinx Vivado** testbenches.

The project applies a 3×3 median filter to an 8-bit grayscale image. MATLAB generates deterministic test vectors and a software reference, while the VHDL design processes pixels as a backpressured stream using two line buffers, a sliding-window generator, a parallel-to-serial controller, and a sequential median core.

## What this project demonstrates

- RTL design in VHDL
- finite-state-machine design
- streaming `valid/ready` handshaking and backpressure
- two-line-buffer image processing
- 3×3 sliding-window generation
- parameterized pixel width and image dimensions
- sequential median calculation using bubble-sort comparisons
- self-checking VHDL testbenches
- VHDL `TEXTIO` file I/O
- MATLAB/VHDL co-verification
- row-major image serialization and reconstruction

## System overview

```text
Optional input.jpg
      │
      ▼
MATLAB preprocessing
  • grayscale / uint8
  • resize to 128×128
  • deterministic 5% salt-and-pepper noise
  • 1-pixel replicate padding
      │
      ├── noisy_pixels_padded_130.txt  (130×130 = 16,900 pixels)
      └── reference_pixels_128.txt     (128×128 = 16,384 pixels)
      │
      ▼
median_filter_top
      │
      ├── window_3x3
      │     ├── line_buffer1  : previous row
      │     ├── line_buffer2  : row before previous
      │     └── 3×3 window registers
      │
      └── windowmedian_unit
            ├── paralel_to_series_converter
            └── nine_input_median
      │
      ▼
vhdl_output_128.txt
      │
      ▼
pixel-by-pixel comparison with MATLAB reference
```

## RTL hierarchy

```text
median_filter_top
├── window_3x3
└── windowmedian_unit
    ├── paralel_to_series_converter
    └── nine_input_median
```

### `window_3x3`

Receives pixels in row-major order and builds each 3×3 neighborhood from:

- `line_buffer2` → row `i-2`
- `line_buffer1` → row `i-1`
- `pixel_in` / lower shift registers → current row `i`

Only two previous rows need to be stored because the third row is the live input stream. The first valid window is generated when the zero-based row and column counters both reach 2.

For a 130×130 padded input:

```text
valid rows    = 2 ... 129  → 128 positions
valid columns = 2 ... 129  → 128 positions
outputs       = 128 × 128   → 16,384 medians
```

The line-buffer arrays are deliberately not given a full memory reset. Before any window can become valid, the required locations have already been overwritten by the first two image rows. This also avoids a reset structure that can prevent efficient FPGA RAM inference.

### `paralel_to_series_converter`

Captures one complete 3×3 window and sends its nine pixels serially to the median core.

FSM:

```text
S_WAIT_WINDOW
      │ window_valid
      ▼
S_SEND_PIXELS
      │ 9 successful valid/ready transfers
      ▼
S_WAIT_MEDIAN
      │ median_valid
      ▼
S_WAIT_WINDOW
```

`median_pixel_in` is selected combinationally from `window_arr(send_index)`. Therefore the selected pixel is already stable before the rising edge on which the downstream `valid/ready` handshake occurs. If `median_pixel_ready` is low, `send_index` does not advance and the same data remains on the interface.

### `nine_input_median`

The median core collects nine unsigned pixels and performs one adjacent bubble-sort comparison per clock cycle. Eight passes over eight adjacent pairs fully sort the nine-element array; element 4 is then emitted as the median.

The implementation intentionally prioritizes **clarity and control-path understanding over throughput**. A sorting network or pipelined comparator tree would be a natural future optimization.

## Streaming handshake

The project uses the core principle of an AXI4-Stream-style interface without claiming to implement the complete AXI4-Stream specification.

A transfer occurs only on a rising clock edge when:

```text
valid = 1 AND ready = 1
```

If the receiver is busy:

```text
ready = 0
→ sender keeps valid asserted
→ sender keeps data stable
→ no data is lost
```

This handshake is used at three boundaries:

1. testbench/source → `window_3x3`
2. `window_3x3` → `windowmedian_unit`
3. `paralel_to_series_converter` → `nine_input_median`

## Verification

The repository contains verification at several abstraction levels.

| Testbench | Purpose |
|---|---|
| `tb_nine_input_median.vhd` | Checks the median core with unordered, descending, repeated, salt-noise and pepper-noise patterns |
| `tb_window_3x3.vhd` | Checks all nine 3×3 windows generated from a known 5×5 image |
| `tb_windowmedian_unit.vhd` | Checks converter + median-core integration |
| `tb_median_filter_top.vhd` | Checks the complete pipeline on a 5×5 image; expected medians are `7,8,9,12,13,14,17,18,19` |
| `tb_median_filter_file.vhd` | Reads 16,900 MATLAB pixels with `TEXTIO`, processes the full image, and checks all 16,384 outputs against the MATLAB reference |

The file-based testbench uses:

```text
readline / read   → input and reference files
write / writeline → VHDL output file
```

A mismatch between any VHDL result and the MATLAB reference is reported as a simulation failure.

## MATLAB verification flow

`matlab/median_filter_reference.m` is self-contained:

- If `input.jpg` exists, that image is used.
- Otherwise, the script creates a deterministic synthetic 128×128 test pattern.
- Salt-and-pepper noise uses `rng(1, "twister")` for repeatability.
- The padded input and MATLAB reference are serialized in row-major order.
- If `vhdl_output_128.txt` already exists, MATLAB reconstructs the image and performs a pixel-by-pixel equality check.

Generated files:

```text
noisy_pixels_padded_130.txt
reference_pixels_128.txt
vhdl_output_128.txt
```

These generated artifacts are excluded by `.gitignore`.

## Running the project in Vivado

1. Create a Vivado RTL project and add every file under `rtl/` as design sources.
2. Add the desired file under `tb/` as a simulation source.
3. For the full image test, run `matlab/median_filter_reference.m` first.
4. Make `noisy_pixels_padded_130.txt` and `reference_pixels_128.txt` visible from the simulator working directory, or edit the relative file constants in `tb_median_filter_file.vhd`.
5. Set `tb_median_filter_file` as the simulation top and run behavioral simulation.
6. The expected final message is:

```text
SELF-CHECK PASSED: 16900 input pixels processed and all 16384 VHDL outputs matched the MATLAB reference.
```

7. Run the MATLAB script again if you want to reconstruct and display `vhdl_output_128.txt` beside the software reference.

## Design trade-offs

This version is intentionally educational rather than throughput-optimized.

- The median core performs one comparison per clock instead of using a fully parallel sorting network.
- The window generator can hold one pending window and propagates backpressure to the pixel source.
- A bubble can occur between consecutive windows.
- The architecture is therefore easy to inspect in a waveform, but it is not designed for one-pixel-per-clock video throughput.

A higher-performance version could use a pipelined compare-exchange network, FIFO buffering between stages, and a formal AXI4-Stream wrapper.

## Repository structure

```text
.
├── rtl/
│   ├── median_filter_top.vhd
│   ├── window_3x3.vhd
│   ├── windowmedian_unit.vhd
│   ├── paralel_to_series_converter.vhd
│   └── nine_input_median.vhd
│
├── tb/
│   ├── tb_nine_input_median.vhd
│   ├── tb_window_3x3.vhd
│   ├── tb_windowmedian_unit.vhd
│   ├── tb_median_filter_top.vhd
│   └── tb_median_filter_file.vhd
│
├── matlab/
│   └── median_filter_reference.m
│
├── docs/
│   └── architecture.md
│
├── data/
│   └── README.md
│
└── .gitignore
```

## Tools

- VHDL
- Xilinx Vivado / XSim
- MATLAB
- Image Processing Toolbox

## Project scope

This repository contains an independently developed educational FPGA image-processing project and its verification material. No proprietary company source code, internal IP, or confidential documentation is included.
