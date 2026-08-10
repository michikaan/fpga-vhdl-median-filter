clear;
clc;
close all;

%% ============================================================
%  PROJE AYARLARI
%  ============================================================

input_image_filename = "yulaf.jpg";

image_height = 128;
image_width  = 128;

padding_size = 1;

noise_density = 0.05;

vhdl_input_filename = "noisy_pixels_padded_130.txt";
vhdl_reference_filename = "reference_pixels_128.txt";

%% ============================================================
%  1. RASTGELE GURULTUYU SABITLE
%  ============================================================
rng(1, "twister");

%% ============================================================
%  2. GIRIS GORUNTUSUNU OKU
%  ============================================================
assert(isfile(input_image_filename), "Giris goruntusu bulunamadi: %s", input_image_filename);
image_original = imread(input_image_filename);

fprintf("Orijinal goruntu boyutu:\n");
disp(size(image_original));
fprintf("Orijinal goruntu veri tipi: %s\n\n", class(image_original));

%% ============================================================
%  3. GORUNTUYU GRAYSCALE YAP
%  ============================================================
image_gray = im2gray(image_original);
image_gray = im2uint8(image_gray);

%% ============================================================
%  4. GORUNTUYU 128x128 BOYUTUNA GETIR
%  ============================================================
image_gray = imresize(image_gray, [image_height image_width]);
assert(isequal(size(image_gray), [128 128]), "Grayscale goruntu 128x128 olmadi.");
assert(isa(image_gray, "uint8"), "Grayscale goruntunun veri tipi uint8 olmali.");

%% ============================================================
%  5. SALT-AND-PEPPER GURULTUSU EKLE
%  ============================================================
image_noisy = imnoise(image_gray, "salt & pepper", noise_density);
assert(isequal(size(image_noisy), [128 128]), "Gurultulu goruntu 128x128 olmali.");

%% ============================================================
%  6. GORUNTUYE REPLICATE PADDING EKLE
%  ============================================================
image_padded = padarray(image_noisy, [padding_size padding_size], "replicate", "both");
assert(isequal(size(image_padded), [130 130]), "Padded goruntu 130x130 olmali.");

%% ============================================================
%  7. PADDING ISLEMINI KONTROL ET
%  ============================================================
assert(isequal(image_padded(2:end-1, 2:end-1), image_noisy), "Padded goruntunun ic bolgesi hatali.");
assert(isequal(image_padded(1, 2:end-1), image_noisy(1, :)), "Ust padding satiri hatali.");
assert(isequal(image_padded(end, 2:end-1), image_noisy(end, :)), "Alt padding satiri hatali.");
assert(isequal(image_padded(2:end-1, 1), image_noisy(:, 1)), "Sol padding sutunu hatali.");
assert(isequal(image_padded(2:end-1, end), image_noisy(:, end)), "Sag padding sutunu hatali.");

%% ============================================================
%  8. MATLAB REFERANS MEDIAN GORUNTUSUNU OLUSTUR
%  ============================================================
image_reference = zeros(image_height, image_width, "uint8");

for output_row = 1:image_height
    for output_column = 1:image_width
        window_3x3 = image_padded(output_row : output_row + 2, output_column : output_column + 2);
        window_pixels = double(window_3x3(:));
        median_value = median(window_pixels);
        image_reference(output_row, output_column) = uint8(median_value);
    end
end

assert(isequal(size(image_reference), [128 128]), "Referans goruntu 128x128 olmali.");
assert(isa(image_reference, "uint8"), "Referans goruntunun veri tipi uint8 olmali.");

%% ============================================================
%  9. GORUNTULERI GOSTER
%  ============================================================
figure;
tiledlayout(1, 4);
nexttile; imshow(image_gray); title("Grayscale 128x128");
nexttile; imshow(image_noisy); title("Noisy 128x128");
nexttile; imshow(image_padded); title("Padded 130x130");
nexttile; imshow(image_reference); title("Median Reference 128x128");

%% ============================================================
%  10. GORUNTULERI PNG OLARAK KAYDET
%  ============================================================
imwrite(image_gray, "image_gray_128.png");
imwrite(image_noisy, "image_noisy_128.png");
imwrite(image_padded, "image_noisy_padded_130.png");
imwrite(image_reference, "image_reference_128.png");

%% ============================================================
%  11. TEK BIR 3x3 PENCEREYI KONTROL ET
%  ============================================================
center_row = 64;
center_column = 64;
window_test = image_padded(center_row : center_row + 2, center_column : center_column + 2);
window_test_row_major = reshape(window_test.', 1, 9);
calculated_test_median = uint8(median(double(window_test_row_major)));
reference_test_median = image_reference(center_row, center_column);

fprintf("\nSecilen 3x3 pencere:\n");
disp(window_test);
fprintf("VHDL'ye gonderilecek 9 piksel:\n");
disp(window_test_row_major);
fprintf("VHDL tuple: (%d, %d, %d, %d, %d, %d, %d, %d, %d)\n", window_test_row_major);
fprintf("Pencereden hesaplanan median: %d\n", calculated_test_median);
fprintf("Referans goruntudeki median: %d\n\n", reference_test_median);
assert(calculated_test_median == reference_test_median, "Tek pencere median testi basarisiz.");
disp("MATLAB WINDOW TEST SUCCESSFUL");

%% ============================================================
%  12. PADDED GIRISI SATIR SATIR DUZLESTIR
%  ============================================================
input_pixels_row_major = reshape(image_padded.', [], 1);
assert(numel(input_pixels_row_major) == 130 * 130, "VHDL giris piksel sayisi 16900 olmali.");

%% ============================================================
%  13. REFERANS CIKISI SATIR SATIR DUZLESTIR
%  ============================================================
reference_pixels_row_major = reshape(image_reference.', [], 1);
assert(numel(reference_pixels_row_major) == 128 * 128, "Referans piksel sayisi 16384 olmali.");

%% ============================================================
%  14. 130x130 PADDED GIRISI METIN DOSYASINA YAZ
%  ============================================================
input_file = fopen(vhdl_input_filename, "w");
assert(input_file ~= -1, "VHDL giris dosyasi olusturulamadi.");
fprintf(input_file, "%d\n", double(input_pixels_row_major));
fclose(input_file);

%% ============================================================
%  15. 128x128 REFERANS CIKISI METIN DOSYASINA YAZ
%  ============================================================
reference_file = fopen(vhdl_reference_filename, "w");
assert(reference_file ~= -1, "VHDL referans dosyasi olusturulamadi.");
fprintf(reference_file, "%d\n", double(reference_pixels_row_major));
fclose(reference_file);

%% ============================================================
%  16. DOSYALARI TEKRAR OKUYARAK KONTROL ET
%  ============================================================
input_file_check = readmatrix(vhdl_input_filename);
reference_file_check = readmatrix(vhdl_reference_filename);
assert(numel(input_file_check) == 16900, "Giris dosyasinda 16900 piksel bulunmuyor.");
assert(numel(reference_file_check) == 16384, "Referans dosyasinda 16384 piksel bulunmuyor.");
assert(isequal(uint8(input_file_check), input_pixels_row_major), "Giris dosyasina yazilan veriler hatali.");
assert(isequal(uint8(reference_file_check), reference_pixels_row_major), "Referans dosyasina yazilan veriler hatali.");

%% ============================================================
%  17. SONUC BILGILERINI YAZDIR
%  ============================================================
fprintf("\n============================================\n");
fprintf("MATLAB HAZIRLIK TAMAMLANDI\n");
fprintf("============================================\n");
fprintf("Orijinal grayscale boyutu : %d x %d\n", size(image_gray, 1), size(image_gray, 2));
fprintf("Gurultulu goruntu boyutu  : %d x %d\n", size(image_noisy, 1), size(image_noisy, 2));
fprintf("Padded giris boyutu       : %d x %d\n", size(image_padded, 1), size(image_padded, 2));
fprintf("Referans cikis boyutu     : %d x %d\n", size(image_reference, 1), size(image_reference, 2));
fprintf("VHDL giris dosyasi       : %s\n", vhdl_input_filename);
fprintf("VHDL giris piksel sayisi : %d\n", numel(input_pixels_row_major));
fprintf("Referans dosyasi         : %s\n", vhdl_reference_filename);
fprintf("Referans piksel sayisi   : %d\n", numel(reference_pixels_row_major));
fprintf("============================================\n");
disp("ALL MATLAB TESTS SUCCESSFUL");