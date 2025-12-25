# Setup n8n Workflow - AI Chatbot Đơn Giản

## 🎯 Tổng quan

Workflow đơn giản này chỉ có:
1. Nhận message từ Flutter app
2. Gửi đến Gemini AI
3. Trả response về app

**KHÔNG cần:**
- ❌ Supabase database
- ❌ IF conditions
- ❌ Multiple branches
- ❌ Query user data

---

## 🚀 Bước 1: Setup n8n (5 phút)

### Cách 1: n8n Cloud (Khuyến nghị)
1. Truy cập https://n8n.io
2. Đăng ký tài khoản (free tier - 5,000 executions/tháng)
3. Click "Create new workflow"

### Cách 2: Self-hosted (Nếu muốn)
```bash
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  docker.n8n.io/n8nio/n8n
```

---

## 🔑 Bước 2: Lấy Gemini API Key (2 phút)

1. Vào https://aistudio.google.com/app/apikey
2. Đăng nhập Google
3. Click **"Create API Key"**
4. Copy key (dạng: `AIzaSy...`)

**✅ Miễn phí:**
- 15 requests/phút
- 1,500 requests/ngày
- 1M tokens/tháng

---

## 🎨 Bước 3: Tạo Workflow (10 phút)

### 📌 Node 1: Webhook (Nhận request từ Flutter)

**Cấu hình:**
```
Node Type: Webhook
HTTP Method: POST
Path: english-chat
Respond: Using 'Respond to Webhook' Node  ← QUAN TRỌNG!
Authentication: None
```

Sau khi tạo xong, n8n sẽ cho bạn **Production URL**:
```
https://yourname.app.n8n.cloud/webhook/english-chat
```

→ **Copy URL này** để dùng trong Flutter app!

---

### 📌 Node 2: Code - Prepare Input (Validation + Content Filtering)

Nối từ Webhook → Thêm **Code** node:

**Node Name:** Prepare Input

**Code JavaScript:**
```javascript
// Extract message từ request
const userMessage = $json.message || "";

// Validate empty message
if (!userMessage || userMessage.trim().length === 0) {
  return {
    json: {
      output: "❌ Vui lòng nhập câu hỏi!"
    }
  };
}

// Validate English learning topics only (optional strict filtering)
const blockedKeywords = [ 
  'chính trị', 'political', 'bầu cử', 'election',
  'tôn giáo', 'religion', 'phật giáo', 'thiên chúa',
  'sex', 'tình dục', 'porn',
  'hack', 'crack', 'phá',
  'mua bán', 'kinh doanh', 'tiền', 'crypto'
];

const messageLower = userMessage.toLowerCase();
const hasBlockedContent = blockedKeywords.some(keyword => 
  messageLower.includes(keyword.toLowerCase())
);

if (hasBlockedContent) {
  return {
    json: {
      output: "⚠️ Xin lỗi, mình chỉ trả lời các câu hỏi về **học tiếng Anh** thôi nhé!\n\n" +
             "📚 Bạn có thể hỏi về:\n" +
             "• Ngữ pháp (grammar)\n" +
             "• Từ vựng (vocabulary)\n" +
             "• Phát âm (pronunciation)\n" +
             "• Dịch câu (translation)\n" +
             "• Viết email/essay tiếng Anh\n" +
             "• Giao tiếp hàng ngày"
    }
  };
}

return {
  json: {
    userMessage: userMessage.trim()
  }
};
```

---

### 📌 Node 3: HTTP Request - Gemini AI

Nối từ Code → Thêm **HTTP Request** node:

**Cấu hình:**
```
Node Name: Gemini AI
Method: POST
URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_GEMINI_API_KEY
Authentication: None
```

**Headers:**
```json
{
  "Content-Type": "application/json"
}
```

**Body (JSON):**
```json
{
  "contents": [{
    "parts": [{
      "text": "{{ $json.userMessage }}\n\nHướng dẫn: Trả lời ngắn gọn, dùng tiếng Việt, có ví dụ, dùng emoji. CHỈ về tiếng Anh."
    }]
  }],
  "systemInstruction": {
    "parts": [{
      "text": "Bạn là trợ lý học tiếng Anh. KHÔNG giới thiệu bản thân. Trả lời trực tiếp câu hỏi."
    }]
  },
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 400,
    "topP": 0.9
  }
}
```

**⚠️ Quan trọng:** Thay `YOUR_GEMINI_API_KEY` bằng key bạn lấy ở Bước 2!

---

### 📌 Node 4: Code - Extract Response

Nối từ HTTP Request → Thêm **Code** node:

**Node Name:** Extract Response

**Code JavaScript:**
```javascript
// Extract response từ Gemini
try {
  const data = $json;
  
  // Check if response is valid
  if (data.candidates && data.candidates.length > 0) {
    const candidate = data.candidates[0];
    
    if (candidate.content && candidate.content.parts && candidate.content.parts.length > 0) {
      const responseText = candidate.content.parts[0].text;
      
      return {
        json: {
          output: responseText
        }
      };
    }
  }
  
  // If blocked by safety filters
  if (data.promptFeedback && data.promptFeedback.blockReason) {
    return {
      json: {
        output: "😅 Xin lỗi, câu hỏi này vi phạm chính sách an toàn. Bạn có thể hỏi về tiếng Anh không?"
      }
    };
  }
  
  // If error from Gemini
  if (data.error) {
    const errorMsg = data.error.message || "Unknown error";
    console.error("Gemini API Error:", errorMsg);
    
    return {
      json: {
        output: "😅 Có lỗi xảy ra. Vui lòng thử lại sau!"
      }
    };
  }
  
  // Fallback
  return {
    json: {
      output: "😅 Mình không thể trả lời lúc này. Bạn thử lại sau nhé!"
    }
  };
  
} catch (e) {
  console.error("Extract Error:", e.message);
  return {
    json: {
      output: "😅 Có lỗi xảy ra khi xử lý phản hồi. Vui lòng thử lại!"
    }
  };
}
```

---

### 📌 Node 5: Respond to Webhook

Nối từ Extract Response → Thêm **Respond to Webhook** node:

**Cấu hình:**
```
Respond With: JSON
```

**Response Body:**
- Click vào icon **⚡** (expression mode) bên phải field
- Nhập: `$json`
- **KHÔNG nhập** `{{ $json }}` (sẽ bị lỗi parse JSON)

---

## 🎯 Workflow Hoàn chỉnh:

```
1. Webhook (Respond: Using 'Respond to Webhook' Node)
      ↓
2. Code - Prepare Input (Validate + Content Filtering)
      ↓
3. HTTP Request - Gemini AI
      ↓
4. Code - Extract Response
      ↓
5. Respond to Webhook (Expression mode: $json)
```

---

## ✅ Bước 4: Test Workflow (2 phút)

### Test trong n8n:

**1. Click "Test workflow"** (nút play ở góc trên)

**2. Click vào node Webhook → "Listen for test event"**

**3. Mở Postman hoặc Terminal:**

```bash
# Test 1: Từ vựng
curl -X POST https://yourname.app.n8n.cloud/webhook/english-chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Nghĩa của collaborate"}'

# Test 2: Ngữ pháp
curl -X POST https://yourname.app.n8n.cloud/webhook/english-chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Phân biệt between và among"}'

# Test 3: Dịch câu
curl -X POST https://yourname.app.n8n.cloud/webhook/english-chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Dịch: Tôi đang học tiếng Anh"}'
```

**Expected Response:**
```json
{
  "output": "📚 **Collaborate** /kəˈlæbəreɪt/\n\n**Nghĩa:** Cộng tác, làm việc chung...\n\n**Ví dụ:**\n- _We collaborated on this project._"
}
```

---

## 🔧 Bước 5: Cập nhật Flutter App (1 phút)

Mở file `lib/screens/chatbot/chatbot_screen.dart`:

**Tìm dòng:**
```dart
final String backend = "https://your-n8n-instance.app.n8n.cloud/webhook/english-chat";
```

**Đổi thành:**
```dart
final String backend = "https://yourname.app.n8n.cloud/webhook/english-chat";
```

→ Thay `yourname` bằng URL thực của bạn từ n8n!

**Chạy app:**
```bash
flutter run
```

---

## 🎉 Xong! Test thử:

1. Mở app → Vào chatbot
2. Hỏi: **"Phân biệt do và make"**
3. Hỏi: **"What is present perfect?"**
4. Hỏi: **"Dịch: Tôi thích học tiếng Anh"**

---

## 🔍 Troubleshooting

### Lỗi: "Unused Respond to Webhook node found"

**Nguyên nhân:** Webhook node setting sai

**Fix:**
1. Click vào node **Webhook**
2. Tìm field **"Respond"**
3. Đảm bảo = **"Using 'Respond to Webhook' Node"** (KHÔNG phải "Immediately")
4. Save node

---

### Lỗi: "API key not valid"

```bash
# Test API key
curl "https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_KEY"
```

**Fix:** Tạo API key mới tại https://aistudio.google.com/app/apikey

---

### Lỗi: "Expected property name or '}' in JSON"

**Nguyên nhân:** Trong node "Respond to Webhook", bạn nhập `{{ $json }}`

**Fix:**
1. Click vào node **Respond to Webhook**
2. Trong field **"Response Body"**, click icon **⚡** (expression mode)
3. Xóa `{{ $json }}`, chỉ nhập: `$json`
4. Save node

---

### Lỗi: "Connection refused" trong Flutter

**Nguyên nhân:** URL webhook sai

**Fix:**
1. Check URL trong `chatbot_screen.dart`
2. Copy lại Production URL từ n8n Webhook node
3. Đảm bảo có `https://` đầu URL
4. Đảm bảo path = `/webhook/english-chat` (không phải `/webhook-test/english-chat`)

---

### Lỗi: "Resource exhausted" (429)

**Nguyên nhân:** Vượt rate limit (15 requests/phút)

**Fix:**
1. Chờ 1 phút rồi thử lại
2. Hoặc tạo thêm Gemini API key (Google account khác)

---

### Lỗi: Response bị timeout

**Nguyên nhân:** Gemini chậm hoặc mạng chậm

**Fix:**
- Flutter app đã có timeout 30s (đủ rồi)
- Nếu vẫn timeout, giảm `maxOutputTokens` xuống 300

---

### Gemini tự giới thiệu thay vì trả lời câu hỏi

**Nguyên nhân:** System prompt chưa đúng

**Fix:** Đảm bảo prompt trong Node 3 có:
```
TRẢ LỜI TRỰC TIẾP câu hỏi sau (không giới thiệu bản thân):

{{ $json.userMessage }}
```

---

## 🛡️ Giới hạn nội dung (Chỉ trả lời về Tiếng Anh)

### Đã được cấu hình sẵn:

**1. Validation ở Node 2 (Prepare Input):**
- Chặn các từ khóa nhạy cảm: chính trị, tôn giáo, sex, hack, mua bán, crypto...
- Tự động trả lời hướng dẫn nếu câu hỏi không liên quan

**2. System Prompt ở Node 3 (Gemini AI):**
- Yêu cầu AI chỉ trả lời về tiếng Anh
- Hướng dẫn AI từ chối lịch sự các câu hỏi khác

### Test các trường hợp:

```bash
# ✅ Câu hỏi hợp lệ
curl -X POST https://your-url/webhook/english-chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Phân biệt do và make"}'

# ❌ Câu hỏi về chính trị → Bị chặn ngay tại Node 2
curl -X POST https://your-url/webhook/english-chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Nói về chính trị Mỹ"}'

# ❌ Câu hỏi về toán → AI từ chối
curl -X POST https://your-url/webhook/english-chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Giải phương trình bậc 2"}'
```

### Tùy chỉnh thêm từ khóa chặn:

Sửa trong **Node 2 - Prepare Input**, thêm vào array `blockedKeywords`:

```javascript
const blockedKeywords = [
  'chính trị', 'political',
  'tôn giáo', 'religion',
  // Thêm từ khóa của bạn ở đây
  'từ_khóa_cần_chặn'
];
```

### Độ chặt chẽ:

- **Chặt chẽ cao:** Dùng cả validation (Node 2) + system prompt (Node 3) ← Đang dùng
- **Vừa phải:** Chỉ dùng system prompt, AI tự quyết định
- **Linh hoạt:** Xóa code validation, chỉ nhắc nhở trong prompt

---

## 📊 Monitoring & Logs

### Xem execution history:
1. Vào n8n → Click **"Executions"** (bên trái)
2. Xem từng request đã chạy
3. Click vào execution → Xem output từng node

### Enable debug:
```
Workflow Settings → Save Execution Progress: Yes
```

---

## 💰 Chi phí

### n8n Cloud Free:
- ✅ 5,000 executions/tháng
- ✅ Đủ cho ~150 câu hỏi/ngày

### Gemini Free:
- ✅ 15 requests/phút
- ✅ 1,500 requests/ngày
- ✅ 1M tokens/tháng

**→ 100% MIỄN PHÍ cho app startup!** 🎉

---

## 🚀 Deploy Production

### n8n Cloud:
1. Workflow đã active tự động
2. Copy Production URL từ Webhook node
3. Update vào Flutter app

### Self-hosted:
```bash
# Docker Compose
version: '3'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=your-domain.com
      - WEBHOOK_URL=https://your-domain.com
```

---

## 🎯 Next Steps (Optional)

### 1. Thêm Rate Limiting

Thêm Code node sau Prepare Input:

```javascript
// Simple rate limiting
const limits = $getWorkflowStaticData('global');
const now = Date.now();
const window = 60000; // 1 minute
const maxRequests = 10;

if (!limits.requests) {
  limits.requests = [];
}

// Clean old requests
limits.requests = limits.requests.filter(t => now - t < window);

// Check limit
if (limits.requests.length >= maxRequests) {
  return {
    json: {
      output: "⏱️ Quá nhiều request. Vui lòng chờ 1 phút!"
    }
  };
}

limits.requests.push(now);
return $input.all();
```

### 2. Logging

Thêm Code node sau Extract Response:

```javascript
// Log for analytics
console.log("User question:", $('Prepare Input').item.json.userMessage);
console.log("Response length:", $json.output.length);
console.log("Timestamp:", new Date().toISOString());

return $input.all();
```

### 3. Context Memory (Nhớ hội thoại)

→ Cần thêm database để lưu context → Phức tạp hơn

---

## 📝 Tóm tắt

✅ **5 nodes chính:**
1. Webhook → Nhận request (Respond: Using 'Respond to Webhook' Node)
2. Code - Prepare Input → Validation + Content filtering
3. HTTP Request → Gọi Gemini AI
4. Code - Extract Response → Parse JSON
5. Respond to Webhook → Trả về Flutter (Expression mode: $json)

✅ **100% miễn phí**
✅ **Setup trong 15 phút**
✅ **Không cần database**

**🎉 Đơn giản và hiệu quả!**

---

## 📞 Support

Nếu gặp lỗi, check:

1. **Executions tab trong n8n** → Xem node nào fail
2. **Console logs** → Thêm `console.log()` để debug
3. **Gemini API status** → https://status.cloud.google.com/
4. **n8n Community** → https://community.n8n.io/

**Good luck! 🚀**
