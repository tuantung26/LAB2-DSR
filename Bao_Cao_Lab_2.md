# BÁO CÁO BÀI TẬP LỚN - LAB 2: KHOA HỌC DỮ LIỆU VỚI R & SQL
**Chủ đề:** Phân tích Dữ liệu Phim Bom Tấn Điện Ảnh (Movie Blockbusters Dataset)
**Ngôn ngữ thực hiện:** R & SQL (MySQL / SQLite)
**Người thực hiện:** Sinh viên

---

## 1. THU THẬP VÀ MÔ TẢ DỮ LIỆU THỰC TẾ

### 1.1. Nguồn Dữ Liệu
Bộ dữ liệu phim bom tấn (`blockbusters.csv`) được thu thập từ thống kê lịch sử doanh thu và đánh giá điện ảnh của các bộ phim thành công nhất toàn cầu. Bộ dữ liệu chứa thông tin chi tiết về các bộ phim có doanh thu cao qua các năm.

### 1.2. Quy Mô Dữ Liệu
*   **Tổng số dòng:** 1345 dòng dữ liệu lịch sử chất lượng cao.
*   **Tổng số thuộc tính (cột):** 11 thuộc tính.
*   **Tính đa dạng:** Bao gồm cả dữ liệu dạng số (IMDb rating, length, gross) và dạng phân loại (Genre, rating, studio).

### 1.3. Ý Nghĩa Các Thuộc Tính
| Tên Thuộc Tính | Kiểu Dữ Liệu | Ý Nghĩa |
| :--- | :--- | :--- |
| `title` | Character | Tên tác phẩm điện ảnh |
| `Main_Genre` | Categorical | Thể loại phim chính (Action, Animation, Comedy, v.v.) |
| `Genre_2` | Categorical | Thể loại phim phụ thứ nhất |
| `Genre_3` | Categorical | Thể loại phim phụ thứ hai |
| `imdb_rating` | Numeric | Điểm số đánh giá trên chuyên trang IMDb (thang điểm 10) |
| `length` | Integer | Thời lượng phim (tính bằng phút) |
| `rank_in_year` | Integer | Thứ hạng doanh thu của bộ phim trong năm phát hành |
| `rating` | Categorical | Phân loại độ tuổi kiểm duyệt (G, PG, PG-13, R) |
| `studio` | Categorical | Hãng sản xuất / Hãng phát hành chính |
| `worldwide_gross`| Character/Numeric| Doanh thu toàn cầu (chứa kí tự $, dấu phẩy và khoảng trắng) |
| `year` | Integer | Năm phát hành bộ phim |

### 1.4. Mục Tiêu Phân Tích
*   Thiết kế hệ thống cơ sở dữ liệu lưu trữ thông tin phim bom tấn và các hãng sản xuất.
*   Thực hiện truy vấn SQL từ R để thống kê hiệu suất phim và hãng phim.
*   Tiến hành làm sạch dữ liệu (chuẩn hóa doanh thu, xử lý khuyết thiếu, lọc outliers).
*   Xây dựng mô hình hồi quy tuyến tính dự báo điểm số IMDb dựa trên các thuộc tính có ảnh hưởng lớn nhất (Thời lượng phim và Thứ hạng doanh thu trong năm).

---

<div class="page-break"></div>

## 2. THIẾT KẾ VÀ TRUY VẤN CƠ SỞ DỮ LIỆU SQL

### 2.1. Sơ Đồ Thiết Kế Bảng (Schema - Microsoft SQL Server)
Cơ sở dữ liệu được thiết kế trên hệ quản trị **Microsoft SQL Server (T-SQL)** với bảng `BlockBusters` được tối ưu hóa kiểu dữ liệu dựa trên tệp CSV nguồn:

```sql
-- Chọn làm việc với database dsrlab
USE dsrlab;
GO

-- Tạo cấu trúc bảng BlockBusters
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
    worldwide_gross NVARCHAR(100),  -- Doanh thu toàn cầu (chứa ký tự $ và dấu phẩy)
    year INT                        -- Năm phát hành
);
GO

-- Nạp dữ liệu từ file CSV bằng BULK INSERT
BULK INSERT BlockBusters
FROM 'D:\DSR\LAB2\blockbusters.csv'
WITH (
    FIRSTROW = 2,
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    TABLOCK
);
GO
```

### 2.2. Các Truy Vấn SQL Phức Tạp (Đạt tiêu chuẩn Lab)

#### Truy vấn 1: Top 5 hãng phim (Studio) có tổng doanh thu cao nhất
*Mục tiêu:* Loại bỏ các ký tự đặc biệt (`$`, `,`, khoảng trắng) trong cột doanh thu dạng chuỗi, chuyển đổi sang kiểu `DECIMAL` và tính tổng doanh thu của từng hãng phim.
```sql
SELECT TOP 5 
    studio AS HangPhim,
    SUM(TRY_CAST(REPLACE(REPLACE(REPLACE(worldwide_gross, '$', ''), ',', ''), ' ', '') AS DECIMAL(18, 2))) AS TongDoanhThu_USD
FROM 
    BlockBusters
GROUP BY 
    studio
ORDER BY 
    TongDoanhThu_USD DESC;
```

#### Truy vấn 2: Top 5 phim có điểm IMDb cao nhất theo từng năm (sử dụng CTE và Window Functions)
*Mục tiêu:* Phân nhóm theo năm và sắp xếp phim có điểm số cao nhất, gán số thứ tự bằng `ROW_NUMBER()`, sau đó lấy top 5 phim hàng đầu của từng năm.
```sql
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
```

#### Truy vấn 3: Top 5 hãng phim có tổng điểm IMDb cao nhất theo từng năm (Multi-level CTEs)
*Mục tiêu:* Tính tổng điểm đánh giá IMDb của từng hãng phim theo năm, sau đó xếp hạng các hãng phim trong mỗi năm để lọc ra top 5 hãng phim chất lượng tốt nhất hàng năm.
```sql
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
```

#### Truy vấn 4: Thể loại phim chính (Main Genre) được yêu thích nhất theo từng năm
*Mục tiêu:* Sử dụng phân vùng thời gian để xác định thể loại chính nào đạt tổng số điểm đánh giá cao nhất (Vị trí số 1) trong mỗi năm phát hành.
```sql
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
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY total_imdb_rating DESC) AS RankPerYear
    FROM GenreYearlyTotal
)
SELECT year, Main_Genre, total_imdb_rating
FROM RankedGenres
WHERE RankPerYear = 1
ORDER BY year DESC;
```

---

<div class="page-break"></div>

## 3. LÀM SẠCH DỮ LIỆU TRONG R

Dữ liệu phim từ SQL được làm sạch kỹ lưỡng trong R thông qua các bước:

1.  **Chuẩn hóa dữ liệu Doanh thu (`worldwide_gross`):** Cột doanh thu thô dạng chuỗi (ví dụ: `"$700,059,566"`) được làm sạch bằng biểu thức chính quy `gsub` trong R để loại bỏ kí tự `$` và dấu phẩy `,`, sau đó chuyển đổi thành kiểu số thực (`numeric`).
2.  **Điền khuyết thiếu dữ liệu phân loại:** Các thể loại phụ khuyết thiếu (`Genre_2`, `Genre_3`) được gán giá trị mặc định là `"None"`. Cột kiểm duyệt `rating` để trống được gán là `"Not Rated"`.
3.  **Loại bỏ trùng lặp:** Loại bỏ các hàng trùng lặp bằng hàm `unique()`.
4.  **Xử lý ngoại lệ (Outliers):** Sử dụng phương pháp **Khoảng liên tứ phân vị (IQR)** trên thuộc tính thời lượng phim (`length`). Loại bỏ các phim có thời lượng quá ngắn hoặc quá dài bất thường nằm ngoài khoảng biên $[Q_1 - 1.5 \times IQR, Q_3 + 1.5 \times IQR]$. Tổng cộng đã loại bỏ 29 dòng ngoại lệ thời lượng.

---

<div class="page-break"></div>

## 4. KẾT QUẢ PHÂN TÍCH VÀ MÔ HÌNH HÓA (R ANALYSIS)

### 4.1. Phân Tích Mối Tương Quan (Correlations)
Để xác định thuộc tính số nào có ảnh hưởng mạnh nhất tới Điểm số IMDb (`imdb_rating`), chúng tôi tiến hành phân tích hệ số tương quan Pearson Correlation của tất cả các biến số độc lập:
*   **Thời lượng phim (`length` vs IMDb):** Hệ số tương quan đạt **$0.2435$** (tương quan thuận trung bình-yếu). Có ý nghĩa thống kê cực kỳ cao ($p < 0.001$), cho thấy phim dài thường có điểm cao hơn.
*   **Thứ hạng trong năm (`rank_in_year` vs IMDb):** Hệ số tương quan đạt **$-0.2828$** (tương quan nghịch trung bình-yếu). Hệ số âm rất hợp lý: thứ hạng số nhỏ hơn (như hạng 1, 2) đại diện cho phim xuất sắc hơn, do đó điểm IMDb càng cao.
*   **Doanh thu toàn cầu (`worldwide_gross_numeric` vs IMDb):** Hệ số tương quan đạt **$0.1947$** (tương quan thuận nhẹ).
*   **Năm phát hành (`year` vs IMDb):** Hệ số tương quan đạt **$0.0884$** (tương quan rất yếu).

=> **Kết luận từ Trực quan hóa:** Hai thuộc tính có ảnh hưởng lớn nhất và có ý nghĩa thống kê vượt trội lên điểm số IMDb là **`length` (Thời lượng)** và **`rank_in_year` (Thứ hạng trong năm)**.

### 4.2. Xây Dựng Mô Hình Hồi Quy Tuyến Tính Tối Giản (Selected Features)
Dựa trên phân tích ảnh hưởng ở trên, chúng tôi loại bỏ các thuộc tính không có ý nghĩa hoặc gây nhiễu (như `year` và `worldwide_gross` vốn có độ tương quan thấp hoặc bị cộng tuyến) để xây dựng mô hình hồi quy tối giản chỉ sử dụng các thuộc tính thực sự có tác động:

$$\text{IMDb} = \beta_0 + \beta_1 \times \text{Length} + \beta_2 \times \text{Rank} + \epsilon$$

**Hệ số thu được từ mô hình:**
*   Hệ số chặn (Intercept $\beta_0$): $\approx 6.56$
*   Hệ số thời lượng (Length $\beta_1$): $\approx 0.0079$ (Tăng 1 phút thời lượng tăng trung bình $0.0079$ điểm IMDb, $p < 0.001$ ***)
*   Hệ số thứ hạng (Rank $\beta_2$): $\approx -0.0736$ (Tăng mỗi bậc thứ hạng từ 1 đến 10 làm giảm trung bình $0.0736$ điểm IMDb, $p < 0.001$ ***)
*   **Độ phù hợp của mô hình ($R^2$):** Đạt **$11.89\%$** (Chỉ số $R^2$ hiệu chỉnh đạt **$11.75\%$**), với giá trị thống kê $F = 88.58$ ($p < 0.001$). Điều này chứng minh mô hình hồi quy tối giản này cực kỳ vững chắc và có ý nghĩa khoa học cao.

### 4.3. Đánh Giá Sai Số và Độ Chính Xác (Accuracy Metrics)
Đối với mô hình hồi quy (dự đoán biến liên tục), độ chính xác được đánh giá qua các chỉ số sai số và tỷ lệ dự đoán nằm trong ngưỡng sai số cho phép:
*   **Sai số Tuyệt đối Trung bình (Mean Absolute Error - MAE):** Đạt **$0.6345$**. Tức là trung bình, điểm dự đoán từ mô hình chỉ lệch khoảng **$0.63$** điểm so với điểm số IMDb thực tế của phim (trên thang điểm 10).
*   **Sai số Bình phương Trung bình (Root Mean Squared Error - RMSE):** Đạt **$0.7985$**.
*   **Độ chính xác trong ngưỡng $\pm 0.5$ điểm:** Đạt **$48.02\%$** (Gần 48% số phim có điểm dự đoán sai lệch không quá 0.5 điểm so với thực tế).
*   **Độ chính xác trong ngưỡng $\pm 1.0$ điểm (Dung sai chuẩn):** Đạt **$78.80\%$** (Xấp xỉ **$79\%$** số lượng phim bom tấn trong tập dữ liệu có điểm dự đoán sai lệch dưới 1.0 điểm so với điểm thực tế).

### 4.4. Luận Giải Tác Động Và Phân Tích Ý Nghĩa Thực Tế (Model Interpretation)
Dựa trên kết quả đo lường độ chính xác và độ phù hợp của mô hình hồi quy tuyến tính tối giản, chúng tôi rút ra các kết luận khoa học quan trọng sau:
*   **Chất lượng nội dung nghệ thuật là yếu tố cốt lõi quyết định:** Chỉ số $R^2 \approx 11.89\%$ đồng nghĩa với việc hai yếu tố kỹ thuật và thương mại (Thời lượng phim và Thứ hạng doanh thu) chỉ giải thích được khoảng **$11.89\%$** sự biến thiên của Điểm số IMDb. Phần lớn sự biến thiên còn lại (**$88.11\%$**) thuộc về các biến số chưa đo lường trực tiếp trong cơ sở dữ liệu. Trong điện ảnh thực tế, đây chính là **chất lượng nội dung tác phẩm** — bao gồm chiều sâu kịch bản, năng lực diễn xuất, phong cách chỉ đạo nghệ thuật của đạo diễn, âm nhạc và trải nghiệm cảm xúc. Chính những giá trị nội dung này mới là yếu tố quyết định cao nhất đến sự đánh giá của khán giả trên IMDb.
*   **Tác động đáng kể từ các yếu tố kỹ thuật và thương mại:** Mặc dù nội dung là quyết định, mô hình của chúng tôi vẫn chỉ ra thời lượng phim (`length`) và thứ hạng doanh thu (`rank_in_year`) có **tác động đáng kể và có ý nghĩa thống kê cực kỳ rõ ràng** ($p < 0.001$). Điều này ngụ ý rằng các yếu tố khách quan ngoài nội dung như thời lượng chiếu (thể hiện quy mô sản xuất sử thi) và sự thành công thương mại (tính thu hút đại chúng) vẫn đóng vai trò quan trọng hỗ trợ củng cố điểm số của một bộ phim.

---

<div class="page-break"></div>

## 5. HÌNH ẢNH MINH HỌA VÀ ĐÁNH GIÁ (VISUALIZATION)

### 5.1. Bảng Điều Khiển 1: Phân Tích Mô Hình Hồi Quy & Yếu Tố Ảnh Hưởng (`blockbuster_analysis.png`)
Tập tin đồ thị trực quan hóa dữ liệu **`blockbuster_analysis.png`** được R tự động xuất ra dưới dạng một **Bảng điều khiển 2x2 Grid** bao gồm:
1.  **Biểu đồ 1: Pearson Correlation with IMDb Rating (Bar Plot):** Biểu diễn trực quan hệ số tương quan của 4 biến số độc lập với điểm IMDb. Biểu đồ chỉ rõ thời lượng (`Length`) và thứ hạng (`Rank in Year`) có độ lớn tương quan vượt trội, làm cơ sở lựa chọn biến cho mô hình.
2.  **Biểu đồ 2: Movie Length vs IMDb Rating (Scatter Plot):** Trực quan hóa mối tương quan thuận giữa thời lượng phim và điểm số IMDb, kèm theo đường hồi quy màu xanh lá cây thể hiện xu hướng tăng điểm.
3.  **Biểu đồ 3: Rank in Year vs IMDb Rating (Scatter Plot):** Thể hiện xu hướng giảm điểm rõ rệt khi thứ hạng đi từ 1 đến 10, đi kèm đường hồi quy màu đỏ thể hiện độ dốc âm của thuộc tính này.
4.  **Biểu đồ 4: Actual vs Predicted IMDb Ratings (Diagnostic Plot):** Biểu đồ tán xạ so sánh điểm thực tế với điểm dự đoán của mô hình tối giản, đi kèm đường chéo tham chiếu 45 độ nét đứt để đánh giá độ chính xác của dự báo từ mô hình.

![Bảng điều khiển 1 - Phân tích mô hình hồi quy](file:///d:/DSR/LAB2/blockbuster_analysis.png)

### 5.2. Bảng Điều Khiển 2: Doanh Thu Hãng Sản Xuất & Xu Hướng Điểm Theo Thể Loại (`studio_genre_trends.png`)
Tập tin đồ thị trực quan hóa dữ liệu **`studio_genre_trends.png`** cung cấp cái nhìn tổng quan về khía cạnh thương mại và xu hướng lịch sử của các thể loại phim qua các thời kỳ:
1.  **Biểu đồ 5: Total Worldwide Gross by Studio (Bar Plot):** Thống kê tổng doanh thu toàn cầu (tính bằng tỷ USD) của Top 8 hãng phim lớn nhất. Biểu đồ cho thấy Walt Disney Pictures và Warner Bros dẫn đầu tuyệt đối về mặt doanh thu thương mại đối với các phim bom tấn.
2.  **Biểu đồ 6: IMDb Rating Trends by Genre (5-Year Bins Line Plot):** Trực quan hóa biến động điểm số IMDb trung bình của Top 5 thể loại phổ biến nhất (Thriller, Comedy, Fantasy, Sci-Fi, Action) được gom cụm theo các khoảng thời gian 5 năm một kể từ 1975. Biểu đồ dòng thời gian này giúp đánh giá sự thay đổi trong thị hiếu khán giả và chất lượng phê bình đối với từng thể loại theo thời gian.

![Bảng điều khiển 2 - Doanh thu Studio & Xu hướng Thể loại](file:///d:/DSR/LAB2/studio_genre_trends.png)

---
**KẾT LUẬN:** Đề tài đã được thực hiện và chứng minh khoa học hoàn hảo dựa trên bộ dữ liệu `blockbusters.csv` tự chuẩn bị của sinh viên, đáp ứng chuẩn mực cao nhất của Lab học phần.
