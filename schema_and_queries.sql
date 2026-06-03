-- Bước 1: Chọn làm việc với database dsrlab của bạn
USE dsrlab;
GO

-- Bước 2: Tạo cấu trúc bảng BlockBusters chuẩn xác theo file CSV
IF OBJECT_ID('BlockBusters', 'U') IS NOT NULL DROP TABLE BlockBusters;
GO

CREATE TABLE BlockBusters (
    Main_Genre NVARCHAR(100),       -- Thể loại chính
    Genre_2 NVARCHAR(100),          -- Thể loại phụ 1
    Genre_3 NVARCHAR(100),          -- Thể loại phụ 2
    imdb_rating FLOAT,              -- Điểm số IMDb
    length INT,                     -- Thời lượng phim (phút)
    rank_in_year INT,               -- Xếp hạng trong năm phát hành
    rating NVARCHAR(50),            -- Phân loại độ tuổi (PG, PG-13, R...)
    studio NVARCHAR(255),           -- Hãng sản xuất (Studio)
    title NVARCHAR(255),            -- Tên phim
    worldwide_gross NVARCHAR(100),  -- Doanh thu toàn cầu (tạm để chuỗi vì chứa ký tự $ và dấu phẩy)
    year INT                        -- Năm phát hành
);
GO

-- Bước 3: Tiến hành nạp dữ liệu từ file vào bảng bằng BULK INSERT
BULK INSERT BlockBusters
FROM 'D:\DSR\LAB2\blockbusters.csv' -- Đường dẫn file của bạn
WITH (
    FIRSTROW = 2,              -- Bỏ qua dòng tiêu đề đầu tiên
    FORMAT = 'CSV',            -- Bắt buộc cần có để xử lý dấu phẩy bên trong ngoặc kép ""
    FIELDTERMINATOR = ',',     -- Phân tách cột bằng dấu phẩy
    ROWTERMINATOR = '\n',      -- Xuống dòng mới
    CODEPAGE = '65001',        -- Đọc chuẩn định dạng UTF-8 tránh lỗi font tên phim
    TABLOCK
);
GO

-- top 5 gross
SELECT TOP 5 
    studio AS HangPhim,
    -- Bước 1: Loại bỏ dấu $, dấu phẩy, khoảng trắng và chuyển sang kiểu dữ liệu số DECIMAL
    SUM(TRY_CAST(REPLACE(REPLACE(REPLACE(worldwide_gross, '$', ''), ',', ''), ' ', '') AS DECIMAL(18, 2))) AS TongDoanhThu_USD
FROM 
    BlockBusters
GROUP BY 
    studio
ORDER BY 
    TongDoanhThu_USD DESC;


-- top 5 movie
WITH RankedMovies AS (
    SELECT 
        year,
        title,
        imdb_rating,
        studio,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY imdb_rating DESC) AS RankPerYear
    FROM BlockBusters
)
SELECT year, RankPerYear, title, imdb_rating, studio
FROM RankedMovies
WHERE RankPerYear <= 5
ORDER BY year DESC, RankPerYear ASC;


-- top 5 studio 
WITH StudioYearlyTotal AS (
    SELECT 
        year,
        studio,
        SUM(imdb_rating) AS total_imdb_rating
    FROM BlockBusters
    GROUP BY year, studio
),
RankedStudios AS (
    SELECT 
        year,
        studio,
        total_imdb_rating,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY total_imdb_rating DESC) AS RankPerYear
    FROM StudioYearlyTotal
)
SELECT year, RankPerYear, studio, total_imdb_rating
FROM RankedStudios
WHERE RankPerYear <= 5
ORDER BY year DESC, RankPerYear ASC;


-- the genre that liked most
WITH GenreYearlyTotal AS (
    SELECT 
        year,
        Main_Genre,
        SUM(imdb_rating) AS total_imdb_rating
    FROM BlockBusters
    GROUP BY year, Main_Genre
),
RankedGenres AS (
    SELECT 
        year,
        Main_Genre,
        total_imdb_rating,
        -- Sắp xếp thể loại có tổng điểm cao nhất lên vị trí số 1 của năm đó
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY total_imdb_rating DESC) AS RankPerYear
    FROM GenreYearlyTotal
)
-- Chỉ lấy ra vị trí số 1 (thể loại được yêu thích nhất) của mỗi năm
SELECT year, Main_Genre, total_imdb_rating
FROM RankedGenres
WHERE RankPerYear = 1
ORDER BY year DESC;
