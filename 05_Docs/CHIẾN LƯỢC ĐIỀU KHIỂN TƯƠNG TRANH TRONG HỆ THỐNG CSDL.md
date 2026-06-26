# BÁO CÁO KỸ THUẬT CHI TIẾT VỀ CÁC CHIẾN LƯỢC ĐIỀU KHIỂN TƯƠNG TRANH TRONG HỆ THỐNG CSDL

# 1\. Tổng quan Chiến lược về Điều khiển Tương tranh

Trong vai trò là một Kiến trúc sư Hệ quản trị CSDL (DBMS Architect), tôi nhấn mạnh rằng điều khiển tương tranh không chỉ là một cơ chế kỹ thuật mà là một chiến lược sống còn đối với tính toàn vẹn dữ liệu doanh nghiệp. Trong môi trường giao dịch hiện đại, hàng nghìn tiến trình truy cập dữ liệu đồng thời; nếu không có sự kiểm soát chặt chẽ, tính nhất quán của hệ thống sẽ sụp đổ.Việc đảm bảo tính khả tuần tự (serializability) là mục tiêu tối thượng. Một lịch trình thực thi đồng thời được coi là an toàn khi và chỉ khi kết quả của nó tương đương với một trình tự thực hiện tuần tự nào đó. Dựa trên nguồn tài liệu kỹ thuật, điều khiển tương tranh hướng tới các mục tiêu cốt lõi:

1. **Tối ưu hóa hiệu suất:**  Cho phép nhiều giao tác thực hiện song song để khai thác tối đa tài nguyên hệ thống.  
2. **Đảm bảo tính cô lập:**  Ngăn chặn các giao tác can thiệp vào dữ liệu tạm thời của nhau.  
3. **Duy trì tính nhất quán:**  Đảm bảo CSDL chuyển từ trạng thái nhất quán này sang trạng thái nhất quán khác sau khi kết thúc các giao tác.Nền tảng của các cơ chế này bắt đầu từ việc xác định các đơn vị dữ liệu (Data Items) và quy mô quản lý chúng.

# 2\. Phân tích Đơn vị Dữ liệu và Hiệu suất Hệ thống

Đơn vị dữ liệu là thực thể cơ bản mà hệ thống thực hiện cấp khóa. Việc lựa chọn quy mô (granularity) là một bài toán đánh đổi (trade-off) chiến lược giữa chi phí quản lý và năng lực xử lý đồng thời.**Phân cấp quy mô đơn vị dữ liệu:**

* Mức vi mô: Trường dữ liệu (Field), Bản ghi (Record).  
* Mức vĩ mô: Khối dữ liệu (Block), Bảng (Table), Toàn bộ CSDL.

**Phân tích lớp "So What?":**  Từ góc độ kiến trúc, đơn vị dữ liệu càng lớn thì số lượng khóa cần quản lý càng ít, dẫn đến chi phí vận hành (overhead) cho Lock Manager thấp. Tuy nhiên, nó lại gây ra hiện tượng "nghẽn cổ chai" vì một giao tác chiếm dụng một đơn vị lớn sẽ chặn tất cả các giao tác khác. Ngược lại, đơn vị dữ liệu nhỏ tăng tối đa mức độ thực hiện đồng thời nhưng lại làm bùng nổ kích thước Lock Table, có thể gây quá tải bộ nhớ và làm chậm tốc độ phản hồi của hệ thống.  
**So sánh tác động hiệu suất:**

| Đặc điểm | TH 1: Quy mô Khối dữ liệu (Block) | TH 2: Quy mô Bản ghi (Record) |
| :---- | :---- | :---- |
| **Cơ chế chiếm giữ** | T khóa bản ghi B thuộc khối X \-\> Hệ thống khóa toàn bộ khối X. | T chỉ khóa chính xác bản ghi B. |
| **Tác động tương tranh** | T' muốn truy cập bản ghi C (cùng khối X) buộc phải chờ T giải phóng. | T' có thể truy cập bản ghi C đồng thời với T. |
| **Đánh giá kiến trúc** | Phù hợp cho xử lý lô (batch), giảm chi phí khóa. | Phù hợp hệ thống OLTP, tối ưu hóa giao dịch nhỏ. |

# 3\. Đánh giá các Vấn đề Phát sinh trong Truy cập Đồng thời

Khi các giao tác không được kiểm soát, hệ thống sẽ đối mặt với 4 loại lỗi dữ liệu nghiêm trọng. Việc nhận diện này là tiền đề để áp dụng các giao thức khóa tương ứng.  
**Bảng định nghĩa xung đột tương tranh:**

| Vấn đề | Nguyên nhân kích hoạt | Hậu quả đối với tính nhất quán |
| :---- | :---- | :---- |
| **Mất dữ liệu cập nhật (Lost Update)** | Hai giao tác cùng đọc A, cùng sửa đổi và ghi lại. | Giao tác ghi sau xóa bỏ hoàn toàn kết quả của giao tác ghi trước. |
| **Đọc dữ liệu rác (Dirty Read)** | T2 đọc dữ liệu mà T1 vừa ghi nhưng chưa Commit. | Nếu T1 Rollback, dữ liệu T2 đã dùng là dữ liệu ảo, sai lệch hoàn toàn. |
| **Không đọc lại được dữ liệu (Non-repeatable Read)** | Một giao tác đọc cùng một đơn vị dữ liệu hai lần nhưng nhận hai kết quả khác nhau. | Vi phạm tính cô lập; logic nghiệp vụ dựa trên lần đọc đầu bị sai. |
| **Bóng ma (Phantom)** | Giao tác đọc một tập hợp dữ liệu, nhưng một giao tác khác thêm/xóa bản ghi trong tập đó. | Kết quả truy vấn tập hợp (như SUM, COUNT) bị thay đổi bất ngờ. |

**Minh họa lỗi "Không đọc lại được dữ liệu" (dựa trên**  **SOURCE\_IMAGE\_1**  **):**  Xét đơn vị dữ liệu  $A=50$ . Tại thời điểm  $t2$ ,  $T2$  thực hiện Read(A) và nhận giá trị  **50** . Tại  $t5$ ,  $T1$  thực hiện Write(A) với giá trị  **40**  và hoàn tất. Đến thời điểm  $t6$ , khi  $T2$  thực hiện Read(A) lần thứ hai, giá trị nhận được là  **40** . Sự bất nhất này khiến  $T2$  không thể thực hiện các tính toán nhất quán trên cùng một phiên làm việc.

# 4\. Cơ chế Quản lý Khóa và Xử lý Trạng thái Chờ

Lock Manager quản lý hai cấu trúc dữ liệu quan trọng:  **Lock Table**  (theo dõi trạng thái, loại khóa và hàng đợi yêu cầu) và  **Transaction Table**  (theo dõi danh sách khóa của từng giao tác). Trong quá trình vận hành, kiến trúc sư cần đặc biệt lưu ý hai trạng thái chờ:

* **Livelock (Khóa sống):**  Xảy ra khi một giao tác bị bỏ qua vô hạn do hệ thống ưu tiên các giao tác khác.  
* *Kịch bản thực tế:*   $T2$  đang chờ khóa  $X$ .  $T1$  giải phóng  $X$ , nhưng hệ thống cấp cho  $T3$  (vừa đến).  $T3$  giải phóng, hệ thống lại cấp cho  $T4$ .  $T2$  bị "đói" tài nguyên (starvation).  
* *Giải pháp:*  Áp dụng hàng đợi  **FIFO (First-In-First-Out)**  để đảm bảo tính công bằng.  
* **Deadlock (Khóa chết):**  Xảy ra khi tồn tại chu trình chờ đợi.  
* *Ví dụ (từ*  *SOURCE\_IMAGE\_2*  *):*   $T1$  giữ khóa  $Y$  và đợi khóa  $X$ ; đồng thời  $T2$  giữ khóa  $X$  và đang đợi khóa  $Y$ .  
* *Chiến lược xử lý:*  Xin khóa cùng lúc từ đầu, cấp khóa theo thứ tự định sẵn hoặc sử dụng cơ chế phát hiện chu trình để Rollback một giao tác "già" nhất hoặc "trẻ" nhất.

# 5\. Hệ thống Giao thức Khóa: Từ Cơ bản đến Nâng cao (2PL)

Sự tiến hóa của giao thức khóa nhằm mục đích vừa bảo vệ dữ liệu, vừa tăng khả năng đáp ứng. Trong khi khóa nhị phân quá đơn giản (0/1) gây nghẽn, khóa  **Đọc/Ghi (Shared/Exclusive)**  cho phép nhiều người cùng đọc (S-lock) nhưng chỉ một người được ghi (X-lock), giúp tăng đáng kể hiệu suất hệ thống chỉ đọc.**Giao thức Khóa 2 giai đoạn (2PL):**  Đây là cơ chế tiêu chuẩn để đảm bảo tính khả tuần tự qua hai giai đoạn:

1. **Growing Phase:**  Chỉ được xin khóa, có thể nâng cấp khóa ( $S \\rightarrow X$ ). Không được mở khóa.  
2. **Shrinking Phase:**  Chỉ được mở khóa, có thể hạ cấp khóa ( $X \\rightarrow S$ ). Tuyệt đối không được xin thêm khóa mới.**Phân tích lớp "So What?" \- Lựa chọn biến thể 2PL:**  
* **Conservative 2PL:**  Yêu cầu khóa tất cả dữ liệu từ đầu. Ưu điểm là  **ngăn chặn Deadlock hoàn toàn** , nhưng nhược điểm là làm giảm khả năng thực hiện đồng thời vì giữ tài nguyên quá lâu.  
* **Strict 2PL:**  Giữ các khóa Ghi (Exclusive) cho đến khi Commit. Đây là lựa chọn phổ biến nhất vì nó  **ngăn chặn Dirty Read**  và đơn giản hóa việc phục hồi dữ liệu.  
* **Rigorous 2PL:**  Giữ cả khóa Đọc và Ghi cho đến khi Commit. Biến thể này đảm bảo tính cô lập cao nhất nhưng hạn chế tối đa hiệu suất của các giao tác khác.

# 6\. Giao thức Nhãn thời gian (Timestamp) và Luật ghi Thomas

Giao thức Nhãn thời gian (TO) tiếp cận theo hướng không dùng khóa để tránh Deadlock. Mỗi giao tác  $T$  có nhãn  $TS(T)$  dựa trên thời gian bắt đầu.**Thuật toán TO cơ bản:**

* Read(X): Thành công nếu  $TS(T) \\geq Write\\\_TS(X)$ .  
* Write(X): Thành công nếu  $TS(T) \\geq Read\\\_TS(X)$  và  $TS(T) \\geq Write\\\_TS(X)$ .**Luật ghi Thomas (Thomas Write Rule):**  Đây là một cải tiến tối ưu. Nếu  $TS(T) \< Write\\\_TS(X)$  khi thực hiện ghi, hệ thống sẽ  **bỏ qua (ignore)**  hành động ghi này thay vì Rollback  $T$ .  
* **Kiến trúc Insight:**  Vì một giao tác trẻ hơn đã ghi giá trị mới hơn, nên giá trị ghi của  $T$  đã lỗi thời. Việc cho phép  $T$  tiếp tục thực hiện và Commit thay vì hủy bỏ giúp tiết kiệm tài nguyên hệ thống đáng kể.*Cảnh báo:*  TO cơ bản có thể gây  **Cascading Rollback** . Giải pháp là sử dụng  **Strict TO** , buộc các giao tác phải chờ cho đến khi giao tác ghi trước đó hoàn tất.

# 7\. Kỹ thuật Xác nhận (Validation) và Sơ đồ Đa phiên bản (MVCC)

Đây là các kỹ thuật "lạc quan" (Optimistic) dành cho các hệ thống có tỷ lệ xung đột thấp.

* **Kỹ thuật Xác nhận:**  Giao tác làm việc trên bản sao cục bộ và chỉ kiểm tra tính hợp lệ vào phút chót (Giai đoạn Xác nhận).  
* **Architect's Note:**  Cần cảnh báo về hiện tượng  **Starvation** . Trong môi trường tải cao, các giao tác dài có nguy cơ bị Rollback liên tục vì dữ liệu luôn bị thay đổi bởi các giao tác ngắn khác.  
* **Đa phiên bản (MVCC):**  Không ghi đè, chỉ tạo phiên bản mới ( $X1, X2...$ ).  
* **Phân tích lớp "So What?":**  Đây là bước ngoặt kiến trúc. Trong MVCC, "Người đọc không bao giờ chặn người ghi, và người ghi không bao giờ chặn người đọc". Hành động Đọc luôn thành công vì luôn tìm được một phiên bản có Write\_TS phù hợp. Điều này cực kỳ quan trọng cho các hệ thống Reporting/Analytics chạy song song với hệ thống giao dịch.

**Ma trận tương thích trong MVCC 2PL:**

| Loại khóa | Read | Write | Certify |
| :---- | :---- | :---- | :---- |
| **Read** | Yes | Yes | **No** |
| **Write** | Yes | **No** | **No** |
| **Certify** | **No** | **No** | **No** |

*Giải thích:*  Ô  **No**  tại Read-Certify có nghĩa là giao tác muốn Commit (cấp khóa Certify để biến bản ghi tạm thành chính thức) phải  **đợi**  cho đến khi tất cả các giao tác đang giữ khóa Đọc giải phóng tài nguyên.

# 8\. Giao thức Khóa dựa trên Đồ thị

Khi cấu trúc truy cập dữ liệu được xác định dưới dạng cây (Tree structure), chúng ta có thể tối ưu hóa vượt xa 2PL.**Cấu trúc cây (dựa trên**  **SOURCE\_IMAGE\_12**  **):**

* Gốc  $A$  là cha của  $B$ .  
* $B$  là cha của  $C$  và  $D$ .  
* $D$  là cha của  $E$ .**Quy tắc chiến lược:**  
1. Khóa đầu tiên có thể đặt ở bất kỳ đâu.  
2. Chỉ được khóa nút con nếu đang giữ khóa ở nút cha.  
3. **Quan trọng:**  Có thể Unlock bất kỳ lúc nào (không cần đợi cuối giao tác). Điều này cho phép các giao tác khác vào tài nguyên sớm hơn so với 2PL.**Ví dụ thực thi:**   $T1$  khóa  $B, D, E$  sau đó giải phóng  $B$  ngay để  $T2$  có thể vào khóa  $B$  và  $C$ . Giao thức này đảm bảo khả tuần tự xung đột và  **hoàn toàn tránh được Deadlock** . Hạn chế duy nhất là kiến trúc sư phải hiểu rõ luồng truy cập dữ liệu trước khi thiết kế.

# 9\. Bảng Tổng hợp Báo cáo Kỹ thuật Toàn diện

| Giao thức | Cơ chế cốt lõi | Ưu điểm chính | Nhược điểm | Mục tiêu |
| :---- | :---- | :---- | :---- | :---- |
| Khóa nhị phân | Trạng thái 0/1 | Đơn giản | Hiệu suất thấp | Sơ cấp |
| Khóa Đọc/Ghi | S/X Lock | Đọc song song | Deadlock | Read-heavy |
| 2PL | 2 giai đoạn | Serializability | Hạn chế tương tranh | Nhất quán |
| Timestamp | TS Order | No Deadlock | Cascading | Điều phối |
| Xác nhận | Bản sao cục bộ | Lạc quan | Rollback cao | Xung đột thấp |
| MVCC | Đa phiên bản | Đọc không chặn | Tốn dung lượng | Tối ưu tương tranh |
| Đồ thị | Cấu trúc cây | Unlock sớm | Cần biết cấu trúc | Định sẵn |

**Lời kết:**  Không có giao thức hoàn hảo nhất, chỉ có giao thức phù hợp nhất. Một DBMS Architect cần đánh giá dựa trên tỷ lệ Đọc/Ghi, cấu trúc dữ liệu và yêu cầu về độ trễ để cấu hình giải pháp điều khiển tương tranh tối ưu cho doanh nghiệp.  
