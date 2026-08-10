clear;
clc;
close all;

%% ============================================================
%  PROJECT SETTINGS
%  ============================================================

input_image_filename = "input.jpg";

image_height = 128;
image_width  = 128;
padding_size = 1;
noise_density = 0.05;

vhdl_input_filename     = "noisy_pixels_padded_130.txt";
vhdl_reference_filename = "reference_pixels_128.txt";
vhdl_output_filename    = "vhdl_output_128.txt";

%% ============================================================
%  1. FIX RANDOM NOISE FOR REPEATABLE TESTS
%  ============================================================
rng(1, "twister");

%% ============================================================
%  2. LOAD AN IMAGE OR CREATE A DETERMINISTIC TEST PATTERN
%  ============================================================
if isfile(input_image_filename)
    image_original = imread(input_image_filename);
    fprintf("Using input image: %s\n", input_image_filename);
else
    fprintf("%s was not found. Using a generated 128x128 test pattern.\n", ...
        input_image_filename);

    [x_grid, y_grid] = meshgrid(0:image_width-1, 0:image_height-1);
    image_original = uint8(mod(2*x_grid + 3*y_grid, 256));

    % Add high-contrast regions so that edges and impulse-noise removal are
    % easy to inspect visually.
    image_original(25:55, 25:55)   = 40;
    image_original(70:105, 65:110) = 220;
end

fprintf("Original image size:\n");
disp(size(image_original));
fprintf("Original image type: %s\n\n", class(image_original));

%% ============================================================
%  3. CONVERT TO 8-BIT GRAYSCALE
%  ============================================================
image_gray = im2gray(image_original);
image_gray = im2uint8(image_gray);

%% ============================================================
%  4. RESIZE TO 128x128
%  ============================================================
image_gray = imresize(image_gray, [image_height image_width]);
assert(isequal(size(image_gray), [128 128]), ...
    "Grayscale image must be 128x128.");
assert(isa(image_gray, "uint8"), ...
    "Grayscale image must use uint8 pixels.");

%% ============================================================
%  5. ADD SALT-AND-PEPPER NOISE
%  ============================================================
image_noisy = imnoise(image_gray, "salt & pepper", noise_density);
assert(isequal(size(image_noisy), [128 128]), ...
    "Noisy image must be 128x128.");

%% ============================================================
%  6. APPLY ONE-PIXEL REPLICATE PADDING
%  ============================================================
image_padded = padarray(
    image_noisy,
    [padding_size padding_size],
    "replicate",
    "both"
);

assert(isequal(size(image_padded), [130 130]), ...
    "Padded image must be 130x130.");

%% ============================================================
%  7. VERIFY PADDING
%  ============================================================
assert(isequal(image_padded(2:end-1, 2:end-1), image_noisy), ...
    "Padded image interior is incorrect.");
assert(isequal(image_padded(1, 2:end-1), image_noisy(1, :)), ...
    "Top padding row is incorrect.");
assert(isequal(image_padded(end, 2:end-1), image_noisy(end, :)), ...
    "Bottom padding row is incorrect.");
assert(isequal(image_padded(2:end-1, 1), image_noisy(:, 1)), ...
    "Left padding column is incorrect.");
assert(isequal(image_padded(2:end-1, end), image_noisy(:, end)), ...
    "Right padding column is incorrect.");

%% ============================================================
%  8. COMPUTE MATLAB 3x3 MEDIAN REFERENCE
%  ============================================================
image_reference = zeros(image_height, image_width, "uint8");

for output_row = 1:image_height
    for output_column = 1:image_width
        window_3x3 = image_padded(
            output_row : output_row + 2,
            output_column : output_column + 2
        );

        window_pixels = double(window_3x3(:));
        median_value = median(window_pixels);
        image_reference(output_row, output_column) = uint8(median_value);
    end
end

assert(isequal(size(image_reference), [128 128]), ...
    "Reference image must be 128x128.");
assert(isa(image_reference, "uint8"), ...
    "Reference image must use uint8 pixels.");

%% ============================================================
%  9. DISPLAY AND SAVE PREPARATION RESULTS
%  ============================================================
figure;
tiledlayout(1, 4);
nexttile; imshow(image_gray);      title("Grayscale 128x128");
nexttile; imshow(image_noisy);     title("Noisy 128x128");
nexttile; imshow(image_padded);    title("Padded 130x130");
nexttile; imshow(image_reference); title("MATLAB Median 128x128");

imwrite(image_gray,      "image_gray_128.png");
imwrite(image_noisy,     "image_noisy_128.png");
imwrite(image_padded,    "image_noisy_padded_130.png");
imwrite(image_reference, "image_reference_128.png");

%% ============================================================
%  10. VERIFY ONE 3x3 WINDOW EXPLICITLY
%  ============================================================
center_row = 64;
center_column = 64;

window_test = image_padded(
    center_row : center_row + 2,
    center_column : center_column + 2
);

window_test_row_major = reshape(window_test.', 1, 9);
calculated_test_median = uint8(median(double(window_test_row_major)));
reference_test_median = image_reference(center_row, center_column);

fprintf("\nSelected 3x3 window:\n");
disp(window_test);
fprintf("Row-major VHDL tuple:\n");
disp(window_test_row_major);
fprintf("Calculated median: %d\n", calculated_test_median);
fprintf("Reference median : %d\n\n", reference_test_median);

assert(calculated_test_median == reference_test_median, ...
    "Single-window median test failed.");

%% ============================================================
%  11. FLATTEN PADDED INPUT IN ROW-MAJOR ORDER
%  ============================================================
input_pixels_row_major = reshape(image_padded.', [], 1);
assert(numel(input_pixels_row_major) == 130 * 130, ...
    "VHDL input must contain 16900 pixels.");

%% ============================================================
%  12. FLATTEN REFERENCE OUTPUT IN ROW-MAJOR ORDER
%  ============================================================
reference_pixels_row_major = reshape(image_reference.', [], 1);
assert(numel(reference_pixels_row_major) == 128 * 128, ...
    "Reference output must contain 16384 pixels.");

%% ============================================================
%  13. WRITE VHDL INPUT FILE
%  ============================================================
input_file = fopen(vhdl_input_filename, "w");
assert(input_file ~= -1, "Could not create VHDL input file.");
fprintf(input_file, "%d\n", double(input_pixels_row_major));
fclose(input_file);

%% ============================================================
%  14. WRITE MATLAB REFERENCE FILE
%  ============================================================
reference_file = fopen(vhdl_reference_filename, "w");
assert(reference_file ~= -1, "Could not create reference file.");
fprintf(reference_file, "%d\n", double(reference_pixels_row_major));
fclose(reference_file);

%% ============================================================
%  15. READ FILES BACK AND VERIFY SERIALIZATION
%  ============================================================
input_file_check = readmatrix(vhdl_input_filename);
reference_file_check = readmatrix(vhdl_reference_filename);

assert(numel(input_file_check) == 16900, ...
    "Input file does not contain 16900 pixels.");
assert(numel(reference_file_check) == 16384, ...
    "Reference file does not contain 16384 pixels.");
assert(isequal(uint8(input_file_check), input_pixels_row_major), ...
    "Serialized input data is incorrect.");
assert(isequal(uint8(reference_file_check), reference_pixels_row_major), ...
    "Serialized reference data is incorrect.");

%% ============================================================
%  16. OPTIONAL POST-SIMULATION VHDL OUTPUT CHECK
%  ============================================================
if isfile(vhdl_output_filename)
    vhdl_output_pixels = readmatrix(vhdl_output_filename);

    assert(numel(vhdl_output_pixels) == 16384, ...
        "VHDL output file must contain 16384 pixels.");

    image_vhdl = uint8(reshape(vhdl_output_pixels, [image_width image_height]).');
    imwrite(image_vhdl, "vhdl_output_128.png");

    figure;
    tiledlayout(1, 2);
    nexttile; imshow(image_reference); title("MATLAB Reference");
    nexttile; imshow(image_vhdl);      title("VHDL Output");

    assert(isequal(image_vhdl, image_reference), ...
        "VHDL output does not match the MATLAB reference pixel-by-pixel.");

    fprintf("VHDL output matches the MATLAB reference pixel-by-pixel.\n");
else
    fprintf("%s not found yet. Run the VHDL file testbench next.\n", ...
        vhdl_output_filename);
end

%% ============================================================
%  17. SUMMARY
%  ============================================================
fprintf("\n============================================\n");
fprintf("MATLAB PREPARATION COMPLETED\n");
fprintf("============================================\n");
fprintf("Grayscale image          : %d x %d\n", size(image_gray, 1), size(image_gray, 2));
fprintf("Noisy image              : %d x %d\n", size(image_noisy, 1), size(image_noisy, 2));
fprintf("Padded VHDL input        : %d x %d\n", size(image_padded, 1), size(image_padded, 2));
fprintf("Reference output         : %d x %d\n", size(image_reference, 1), size(image_reference, 2));
fprintf("VHDL input file          : %s\n", vhdl_input_filename);
fprintf("VHDL input pixel count   : %d\n", numel(input_pixels_row_major));
fprintf("Reference file           : %s\n", vhdl_reference_filename);
fprintf("Reference pixel count    : %d\n", numel(reference_pixels_row_major));
fprintf("============================================\n");
fprintf("ALL MATLAB PREPARATION CHECKS PASSED\n");
