# FPGA VHDL 3×3 Median Filter

A streaming grayscale image-processing project implemented in **VHDL** and verified with **MATLAB** and **Xilinx Vivado**.

The design applies a 3×3 median filter to a noisy 128×128 grayscale image. MATLAB prepares deterministic test data, adds salt-and-pepper noise, applies one-pixel replicate padding, and writes the padded image as row-major pixel values. The VHDL design then processes the resulting 130×130 stream and produces 128×128 filtered output pixels.

## Highlights

- VHDL RTL design and behavioral verification
- Streaming pixel interface with `valid/ready` handshaking and backpressure
- Two-line-buffer architecture for 3×3 sliding-window generation
- Parallel-to-serial conversion of nine window pixels
- FSM-controlled 9-input median computation
- MATLAB test-vector generation and image preprocessing
- VHDL `TEXTIO` based end-to-end file simulation
- 16,900 input pixels → 16,384 filtered output pixels
- Self-checking median-core testbench

## Processing Flow

```text
128×128 source image
        │
        ▼
MATLAB grayscale conversion
        │
        ▼
5% salt-and-pepper noise
        │
        ▼
1-pixel replicate padding
128×128 → 130×130
        │
        ▼
row-major text file (16,900 pixels)
        │
        ▼
median_filter_top
        │
        ├── window_3x3
        │     └── two line buffers + 3×3 sliding window
        │
        └── windowmedian_unit
              ├── paralel_to_series_converter
              └── nine_input_median
        │
        ▼
128×128 filtered output (16,384 pixels)
```

## RTL Hierarchy

```text
median_filter_top
├── window_3x3
└── windowmedian_unit
    ├── paralel_to_series_converter
    └── nine_input_median
```

### `window_3x3`
Receives one 8-bit pixel at a time. Two line buffers retain pixels from previous rows, while nine window registers maintain the active 3×3 neighborhood. A valid window is generated once both the row and column counters reach index 2.

### `paralel_to_series_converter`
Captures the nine parallel pixels of one valid window and sends them sequentially to the median core. A finite-state machine controls window capture, pixel transmission, and waiting for the median result.

### `nine_input_median`
Collects nine 8-bit pixels, sorts them over multiple clock cycles, and outputs the middle element as the median. `pixel_ready` controls input acceptance and `median_valid` marks a valid result.

## Streaming Handshake

The project uses an AXI4-Stream-like `valid/ready` convention without implementing the complete AXI4-Stream protocol.

A transfer occurs on a rising clock edge only when both signals are asserted:

```text
transfer = valid AND ready
```

This is used between the input source and `window_3x3`, between the window generator and median unit, and between the serial converter and median core. If the downstream module is busy, `ready` is deasserted and upstream data is held stable.

## MATLAB / VHDL Verification Flow

The MATLAB script:

1. Loads an image and converts it to 128×128 grayscale.
2. Adds deterministic 5% salt-and-pepper noise using a fixed RNG seed.
3. Applies one-pixel replicate padding to create a 130×130 image.
4. Calculates a MATLAB reference 3×3 median-filter result.
5. Writes the 130×130 padded image to a row-major text file.

The file-based VHDL testbench reads all 16,900 input pixels using `TEXTIO`, sends them through the DUT using the `valid/ready` handshake, and writes 16,384 output pixels to a second text file.

## Repository Structure

```text
rtl/       synthesizable VHDL modules
tb/        VHDL testbenches
matlab/    MATLAB preprocessing and reference generation
data/      notes for generated test vectors
docs/      design notes and architecture description
```

## Tools

- VHDL
- Xilinx Vivado
- MATLAB / Image Processing Toolbox

## Scope

This repository contains the independently developed educational median-filter project and related verification material. It does not contain proprietary company source code or confidential material.
