# جرس المدرسة

تطبيق Android محلي لجدولة أجراس دخول الحصص وخروجها. يستخدم Flutter وProvider، ويحفظ الجداول في Hive على الجهاز؛ اخترت Hive لأنه خفيف ومناسب لبيانات الجداول الصغيرة. لا يطلب التطبيق صلاحية الإنترنت ولا يستخدم Firebase أو التحليلات.

## المتطلبات والتشغيل

- Flutter 3.50 أو أحدث، JDK 17، وAndroid SDK.
- Android 7.0 (API 24) أو أحدث، `minSdk = 24` و`targetSdk = 35`.
- لا يوجد هدف iOS.

```powershell
flutter pub get
flutter test
flutter run
```

تنزيل الحزم مطلوب على جهاز التطوير فقط عند البناء الأول؛ التطبيق المثبت لا يحتاج اتصالاً.

## الاستخدام

عند أول تشغيل يُنشأ جدول افتراضي من 6 حصص، يبدأ 8:30، مدة كل منها 40 دقيقة، والفرصة 5 دقائق باستثناء فرصة الحصة الثالثة (20 دقيقة). الأيام الافتراضية الأحد إلى الخميس. تبدأ الحصص التلقائية بعد نهاية الحصة السابقة وفرصتها. تعديل المدة يحسب أوقات الحصص التلقائية التالية مباشرة؛ تغيير وقت بداية حصة يثبتها يدوياً.

تحتوي الواجهة على الشاشة الرئيسية والإعدادات فقط. من الرئيسية يمكن تبديل أيام الأسبوع، إيقاف أجراس اليوم، تعديل أو حذف حصة، وإيقاف الرنين أثناء عمله. تعرض الإعدادات اختيار صوت من ملفات الهاتف أو نغمات النظام، مدة الرنين، الاهتزاز، وتنسيق الساعة. يُنسخ الملف المختار إلى مجلد التطبيق الخاص حتى يبقى متاحاً بعد إعادة التشغيل؛ إذا تعذر تشغيله يستخدم التطبيق صوت المنبه الافتراضي.

## الصلاحيات والإشعارات

في التشغيل الأول يطلب التطبيق بالتتابع إذن الإشعارات، والمنبهات الدقيقة (Android 12+)، واستثناء تحسين البطارية. إذا سُحبت صلاحية لاحقاً يظهر شريط لإصلاحها. أثناء الرنين يظهر زر إيقاف في الإشعار، وشاشة رنين على شاشة القفل عندما يسمح Android بذلك، وزر إيقاف ثابت في التطبيق. ينتهي الرنين تلقائياً بعد المدة المختارة (10 ثوانٍ افتراضياً).

## بناء APK والتوقيع للتوزيع الخاص

أنشئ مفتاحاً مرة واحدة من جذر المشروع، واحتفظ بنسخة آمنة منه؛ يلزم المفتاح نفسه لتوقيع التحديثات:

```powershell
keytool -genkeypair -v -keystore android\app\school-bell-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias schoolbell
```

أنشئ `android\key.properties` محلياً (وهو مستثنى من Git):

```properties
storePassword=كلمة_مرور_المخزن
keyPassword=كلمة_مرور_المفتاح
keyAlias=schoolbell
storeFile=app/school-bell-release.jks
```

ثم نفّذ:

```powershell
flutter build apk --release --split-per-abi
```

تُكتب الملفات في `build\app\outputs\flutter-apk\`، ومنها `app-arm64-v8a-release.apk` لمعظم الهواتف الحديثة. عند غياب ملف `android\key.properties` يمكن أن ينجح البناء لكنه لن يستخدم مفتاح توزيع خاصاً؛ لا توزع نسخة غير موقعة بمفتاحك.

للتثبيت عبر USB بعد تفعيل USB debugging:

```powershell
adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

أو انقل APK إلى الهاتف واسمح بتثبيت التطبيقات من هذا المصدر. لا تشارك ملف المفتاح أو `key.properties`.

## العمل بالخلفية والقيود

- يستخدم محرك Kotlin `AlarmManager.setAlarmClock()` للجرس التالي، ثم يواصل السلسلة من الخطة المحلية. يعيد BootReceiver الجدولة عند الإقلاع أو تغيير الوقت/المنطقة الزمنية، ويجدد WorkManager الخطة دورياً ويومياً.
- المنبهات الدقيقة مصممة للعمل خلال Doze، لكن لا يمكن ضمان الرنين إذا أوقف النظام أو الشركة المصنّعة التطبيق قسراً، أو سُحبت الصلاحيات، أو كان الهاتف مطفأً/بلا بطارية. جدولة WorkManager الدورية أفضل-جهد وتتأثر بقيود النظام.
- الصوت يستخدم مسار `USAGE_ALARM` ويتبع مستوى صوت المنبه الذي يحدده النظام. لا يستطيع التطبيق تجاوز مستوى المنبه الصفري أو إعدادات عدم الإزعاج.
- أول تشغيل بعد إعادة تشغيل الجهاز قد يسبق فتح المستخدم للهاتف؛ عندها قد لا يكون ملف الصوت الخاص متاحاً قبل فك قفل الجهاز، فيستخدم النظام صوت المنبه الافتراضي.
- إعدادات Autostart تختلف بين طرازات الشركات وإصدارات النظام. لا توفر Android واجهة موحدة للتحقق منها؛ يمكن تهيئتها يدوياً:
  - **Xiaomi/Redmi/POCO:** فعّل Autostart، اختر بلا قيود للبطارية، واقفل التطبيق في قائمة التطبيقات الحديثة.
  - **Huawei/Honor:** من App launch فعّل الإدارة اليدوية والسماح بالتشغيل التلقائي والعمل بالخلفية.
  - **Oppo/Realme:** فعّل Auto launch وAllow background activity، واستثن التطبيق من تحسين البطارية.
  - **Vivo:** فعّل Autostart وHigh background power consumption، واترك التطبيق في التطبيقات الحديثة.
  - **Samsung:** أضف التطبيق إلى Never sleeping apps ولا تضعه ضمن Sleeping apps.
  - **OnePlus:** اسمح بالتشغيل التلقائي والخلفية، واستثنه من تحسين البطارية، وأقفل التطبيق في التطبيقات الحديثة إن توفر الخيار.

قد تختلف الأسماء ومواقع الإعدادات، ولا يستطيع التطبيق ضبط هذه الخيارات نيابة عن المستخدم.

## الاختبارات

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

اختبار يدوي على جهاز فعلي:

1. انتظر جرساً مجدولاً واضغط «إيقاف» من الإشعار والشاشة مقفلة.
2. أعد الاختبار واضغط زر الإيقاف في شاشة الرنين.
3. أوقف الرنين من الشريط الثابت داخل التطبيق، وتأكد أن الجرس التالي لا يزال مجدولاً.
4. اختر ملف صوت محلياً، أعد تشغيل الجهاز، وتحقق من تشغيله عند الجرس التالي.
5. اختبر قفل الشاشة وDoze/توفير البطارية، وتغيير الوقت، وإيقاف أجراس اليوم.

## هيكل المشروع

```text
lib/
  main.dart, app.dart
  core/ (localization, theme, time formatting)
  models/ (Lesson, Schedule, Bell, AppSettings)
  controllers/ (ScheduleController, SettingsController, PermissionsController)
  repositories/ (Hive JSON repository)
  services/ (BellScheduleCalculator, AlarmService adapter)
  views/screens/ (home, settings)
android/app/src/main/
  AndroidManifest.xml
  kotlin/com/Alertschool/alert_school/
    MainActivity.kt, AlarmStore.kt, AlarmPlanner.kt, AlarmScheduler.kt
    BellReceiver.kt, BellService.kt, StopReceiver.kt, RingActivity.kt
    BootReceiver.kt, BellWorkers.kt
assets/fonts/Cairo-Variable.ttf
test/bell_schedule_calculator_test.dart
```
