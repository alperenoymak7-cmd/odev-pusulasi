# Ödev Pusulası · Öğretmen kullanım taslağı

Bu paket, koordinatörün öğretmenlerle paylaşabileceği ortak web uygulamasının yayınlanmaya hazır başlangıç sürümüdür. Her öğretmen kendi hesabını açar, sınıfını ve öğrencilerini ekler, haftalık ödev yayımlar ve öğrenci bağlantılarını paylaşır. Öğrenci bağlantısı öğretmen panelini açmaz; sadece ilgili öğrencinin sınıfını, açık ödevlerini ve yanıt alanını gösterir.

## Dosyalar

- `index.html`: Öğretmen ve öğrenci arayüzü.
- `supabase-schema.sql`: Veritabanı tabloları, erişim kuralları ve öğrenci bağlantısı işlevleri.
- `config.js`: Supabase bağlantı bilgileri girilecek dosya.
- `config.example.js`: Örnek yapılandırma.

## İlk yayın kurulumu

1. Supabase'te yeni bir proje oluştur.
2. Projedeki **SQL Editor** bölümünü aç ve `supabase-schema.sql` içeriğini çalıştır.
3. Supabase **Project Settings → API** bölümünden Project URL ve publishable (anon) key değerlerini al. Bu değerleri `config.js` dosyasındaki örnek değerlerle değiştir. `service_role` veya secret key'i web dosyalarına koyma.
4. `index.html` ve `config.js` dosyalarını HTTPS ile yayın yapan statik site barındırıcısına yükle. Örnek: Netlify Drop veya Cloudflare Pages.
5. Yayındaki sitenin URL'sini Supabase **Authentication → URL Configuration** altında Site URL ve Redirect URLs olarak ekle.
6. Authentication → Email ayarlarından e-posta doğrulamasını açık tut. Öğretmenlerin doğrulama e-postası alabilmesi için özel SMTP sağlayıcısı bağla. Supabase'in varsayılan gönderimi genel öğretmen daveti/kayıtları için üretim gönderimi olarak uygun değildir.
7. Yayın URL'sini öğretmenlerle paylaş. Her öğretmen **Hesap oluştur** ile kayıt olur, e-postasını doğrular ve giriş yaptıktan sonra kendi sınıf/şubesini kurar.

## Öğretmenin kullanım akışı

1. Sınıf düzeyi ve şubeyi kaydeder.
2. **Sınıf ve öğrenciler** bölümünde öğrenci adlarını satır satır yapıştırıp ekler.
3. **Sınıfım** bölümünden haftalık ödev adı, açıklaması, hafta başlangıcı ve isteğe bağlı son tarihi girip yayımlar.
4. **Öğrenci bağlantıları** bölümünden her öğrenci için özel bağlantı oluşturur, kopyalar ve yalnızca o öğrenciyle paylaşır.
5. Yanıtlar geldikçe **Sınıfım** ekranında tamamladı, yapmadı, kısmen yaptı, anlamadığı yer ve henüz yanıt vermedi durumlarını ve öğrenci notlarını görür.
6. Süresi biten ödevi **Ödevi kapat** ile öğrenci ekranından kaldırır. Eski yanıtlar öğretmen ekranında kayıtlı kalır.

## Erişim ve bağlantı notları

- Her öğretmenin verileri Supabase Auth oturumu ve satır düzeyi erişim politikalarıyla kendi hesabına ayrılır.
- Öğrenci bağlantısı uzun, rastgele bir erişim anahtarı taşır. Veritabanında anahtarın kendisi değil özeti saklanır.
- Öğrenci bağlantısı yalnızca o öğrenciye ait bilgileri ve açık ödevleri döndürür. Yanıt gönderimi veritabanı işlevi üzerinden sınıf/ödev/öğrenci eşleşmesi kontrol edilerek yapılır.
- Öğretmen bir bağlantıyı yenilerse önceki bağlantı geçersiz olur.
- Bu paket yayına hazır kaynak taslağıdır; Supabase projesi açılmadan ve site yayınlanmadan çalışan ortak internet sitesi oluşmaz. Bu ortamda senin adına harici hesap açmadım veya site yayımlamadım.

## Güvenlik ayarının özeti

Supabase tablolarında Row Level Security etkinleştirilir. Öğretmenler yalnızca kendi sınıf, öğrenci, ödev ve yanıt satırlarına erişir. Anonim öğrencilerin tablo erişimi yoktur; öğrenci verisini yalnızca erişim anahtarı doğrulayan iki dar kapsamlı veritabanı işlevi sunar. İşlevler sabit ve boş `search_path` ile tanımlıdır.



## Mevcut Supabase projesinde öğrenci girişi

Öğretmenler ve sınıflar zaten kuruluysa tüm şemayı yeniden çalıştırma. Supabase SQL Editor’de "student-login-migration.sql" dosyasının tamamını bir kez çalıştır. Bu ekleme öğrenci kullanıcı adını, şifre özeti saklamayı ve öğrenci oturumlarını kurar. Ardından siteyi yenile; öğretmen "Sınıf ve öğrenciler" bölümünden öğrenci için kullanıcı adı ve şifre belirleyebilir. Şifre kaydedildiğinde yalnızca o anda gösterilir; unutulursa öğretmen yenisini belirler.

Öğrenci ve öğretmen girişleri açılışta ayrı sekmelerde görünür. Öğrenci yalnızca kendi açık ödevlerini ve yanıt alanını görür. Öğrenci bağlantıları da çalışmaya devam eder.

## Mevcut yayına ödev kelimeleri ve yorum alanı ekleme

Supabase projenizde **SQL Editor → New query** bölümünü açın. `homework-reflection-migration.sql` dosyasının tamamını çalıştırın. Bu işlem mevcut yanıtları silmez; yanıt kaydına iki kelime ve konu yorumu alanı ekler. Ardından yeni site dosyalarını Netlify’a yükleyin. Öğrenci durum seçtikten sonra iki kelime ve konu yorumunu doldurup **Yanıtı kaydet** düğmesine basar; öğretmen bunları ödev yanıtının altında görür.
## Öğretmenin durum girişi

Mevcut Supabase projesinde **SQL Editor → New query** bölümünde `teacher-status-migration.sql` dosyasını çalıştır. Öğretmen ödev takibinde öğrenci satırından durumu kendisi kaydedebilir.

## Birden fazla sınıf

Öğretmen panelinin üst kısmındaki sınıf seçicisinden sınıflar arasında geçiş yapabilir; **+ Sınıf ekle** düğmesiyle aynı hesaba yeni sınıf/şube oluşturabilir. Var olan sınıflar ve ödev kayıtları korunur.
