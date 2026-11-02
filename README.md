# تطبيق لمّة - Lamma Party Game App 🎮
**تطبيق ألعاب جماعية أوفلاين باللهجة المصرية**  
**صنع بواسطة: Mohamed Ibrahim**

---

## 🌟 نبذة عن المشروع
"لمّة" هو تطبيق موبايل للألعاب الجماعية في التجمعات العائلية ولمّات الصحاب، مبني بالكامل على معمارية **Clean Architecture** ونظام إدارة الحالة **Riverpod**.

يعمل التطبيق بشكل **أوفلاين بالكامل (Peer-to-Peer)** عبر شبكة الواي فاي أو الهوت سبوت المحلي (Local WebSocket)، دون الحاجة لاتصال بالإنترنت أثناء اللعب، مع دعم خلفية **Laravel 11** لتخزين ومزامنة وتوليد الأسئلة بذكاء اصطناعي (Gemini).

---

## 🕹️ الألعاب المتوفرة
1. **مين الجاسوس 🕵️‍♂️**: لعبة التخفي والاستجواب، كل اللاعبين عارفين المكان السري ما عدا الجاسوس اللي بيحاول يخمّن من غير ما يتكشف.
2. **تحدي الشلة 🎯**: أسئلة ثقافة عامة، إفيهات وقفشات سينمائية، وكورة مصرية، والكل بيجاوب في نفس الوقت مع بونص سرعة.
3. **مثّل ومتتكلمش 🎭**: لعبة تمثيل بدون كلام مع حساسات حركة الموبايل على الجبهة (إمالة لأسفل = صح ✔️، إمالة لأعلى = تخطي ⏩).

---

## 🛡️ نظام مكافحة الغش (Anti-Cheat System)
- مراقبة دورة حياة التطبيق (`AppLifecycleDetector`).
- احتساب مخالفة (Strike) عند الخروج من اللعبة أو فتح تطبيقات أخرى.
- 3 مخالفات = طرد تلقائي من الغرفة لحماية نزاهة المنافسة.

---

## 🏗️ هيكلية المشروع (Clean Architecture)
```text
lib/
├── core/
│   ├── constants/       # روابط وإعدادات الـ API
│   ├── routes/          # مسارات GoRouter لـ 44 شاشة
│   ├── theme/           # ألوان وخطوط Cairo وتوكنز Stitch
│   ├── utils/           # كاشف الخروج ومكافحة الغش
│   └── widgets/         # الأزرار والكروت الدائرية المخصصة
├── data/
│   ├── api/             # عميل Dio للاتصال بالباك إند
│   ├── models/          # نماذج الأسئلة واللاعبين والبيانات
│   ├── providers/       # Riverpod Providers وإدارة الغرفة
│   └── storage/         # التخزين المحلي للكاش
├── features/
│   ├── splash/          # شاشة البداية
│   ├── home/            # الشاشة الرئيسية
│   ├── room/            # إنشاء والانضمام للغرفة
│   ├── lobby/           # اللوبي والإعدادات المتقدمة
│   ├── spy/             # شاشات مين الجاسوس
│   ├── trivia/          # شاشات تحدي الشلة
│   ├── charades/        # شاشات مثّل ومتتكلمش
│   ├── feedback/        # شاشات النتائج، التحذيرات، والطرد
│   ├── settings/        # إعدادات الصوت والاسم والأفاتار
│   └── howto/           # كتيبات وقواعد كل لعبة
└── net/
    ├── client/          # عميل الـ WebSocket المحلي
    ├── protocol/        # رسائل وبروتوكول الغرفة P2P
    └── server/          # سيرفر الهوست المحلي (dart:io HttpServer)
```

---

## 🚀 طريقة التشغيل وإعدادات الـ AI (Gemini)

### 📌 أين يوضع ماذا؟ (إعداد ملفات البيئة .env)
1. **الباك إند (`backend/.env`) - المصدر الوحيد للمفتاح والموديل:**
   ```env
   GEMINI_API_KEY=AIzaSy...
   GEMINI_MODEL=gemini-3.5-flash-lite
   ```
   *ملاحظة: الموديلات الأسرع والأكثر استقراراً حالياً هي `gemini-3.5-flash-lite` أو `gemini-flash-lite-latest`.*

2. **تطبيق الفلاتر (`.env` في المجلد الرئيسي):**
   ```env
   # للمحاكي (Android Emulator):
   API_BASE_URL=http://10.0.2.2:8000/api/v1
   # للأجهزة الحقيقية عبر الواي فاي:
   # API_BASE_URL=http://192.168.1.X:8000/api/v1
   ```
   *تنبيه أمني: تطبيق Flutter لا يتصل بجوجل مباشرة ولا يحوي أي مفاتيح API، بل يطلب التوليد حصراً عبر خادم Laravel.*

---

### ⚙️ الأوامر المطلوبة عند تعديل `.env`:
إذا قمت بتغيير مفتاح أو موديل Gemini في `backend/.env`:
1. مسح كاش الإعدادات في لارافيل:
   ```powershell
   cd backend
   php artisan optimize:clear
   ```
2. فحص صلاحية المفتاح والموديلات تلقائياً عبر الأداة الذكية:
   ```powershell
   php artisan ai:check --test-trivia
   ```
3. تشغيل خادم لارافيل بعدة خيوط (Workers) لدعم التوازي وسرعة الاستجابة:
   ```powershell
   $env:PHP_CLI_SERVER_WORKERS=4
   php artisan serve --host=0.0.0.0 --port=8000
   ```
4. **تطبيق الفلاتر:**
   أعد تشغيل التطبيق بالكامل بالضغط على `R` في التيرمينال أو تشغيل `flutter run` من جديد، لأن الـ Hot Reload لا يعيد تحميل متغيرات الـ assets و `.env`.
   (إذا استمر التطبيق في تذكر كاش قديم جداً، يمكنك مسح بيانات التطبيق Clear Storage من إعدادات الأندرويد).

---

### 1. تشغيل الباك إند (Laravel Backend):
افتح التيرمينال داخل مجلد `backend`:
```powershell
cd backend
composer install
php artisan migrate --seed
$env:PHP_CLI_SERVER_WORKERS=4
php artisan serve --host=0.0.0.0 --port=8000
```

#### تشغيل عمال الطوابير والجدولة الذاتية (Autonomous Workers):
النظام يعمل بنمط غير تزامني ذاتي بالكامل (`QUEUE_CONNECTION=database`):
- لتشغيل عامل الطابور لمعالجة تعويض المخزون تلقائياً في الخلفية:
```powershell
php artisan queue:work --tries=3 --timeout=120
```
- لتشغيل المجدول الدوري (Scheduler) لفحص الأقسام الأقل مخزوناً ليلاً:
```powershell
php artisan schedule:work
```

### 2. إدارة المحتوى الذاتي والأدوات الذكية:
- تجربة واختبار خط التوليد والفلترة والتدقيق التلقائي الحقيقي:
```powershell
php artisan ai:test-autonomous --type=trivia --count=3
php artisan ai:test-autonomous --type=spy
```
- تشغيل تعويض وتجديد المخزون يدوياً:
```powershell
php artisan content:replenish --type=all
```
- عرض وفحص العناصر المعزولة تلقائياً (بسبب بلاغين من اللاعبين):
```powershell
php artisan content:quarantined
```
- فحص وتشخيص موديلات Gemini وصلاحيتها مع تجربة حية:
```powershell
php artisan ai:check --test-trivia
```
- لعرض إحصائيات الأسئلة والمحتوى:
```powershell
php artisan content:stats
```

### 3. تشغيل تطبيق الفلاتر (Flutter App):
افتح تيرمينال جديد في المجلد الرئيسي:
```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## 🎨 توثيق شاشات التصميم (44 شاشة)
تم استخراج جميع الشاشات الـ 44 بدقة كاملة من Stitch MCP إلى المجلد `./design/` (ملفات HTML وسكرين شوتس كاملة) وتم تطبيقها بنسبة 100% داخل التطبيق.

**صنع بحب بواسطة: Mohamed Ibrahim**
