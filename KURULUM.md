# English Time Ödev Takip Sistemi · Kurulum ve kullanım

English Time Ödev Takip Sistemi GitHub Pages üzerinde yayımlanır. Öğretmen ve öğrenci verileri Supabase projesinde kalır; GitHub deposunda uygulama dosyaları bulunur.

**Canlı site:** https://alperenoymak7-cmd.github.io/odev-pusulasi/

## Yayın bilgisi

- GitHub deposu: https://github.com/alperenoymak7-cmd/odev-pusulasi
- Yayın kaynağı: `main` dalı, kök klasör (`/(root)`).
- Dosyaları `main` dalına kaydettiğinde GitHub Pages otomatik olarak yeni sürümü yayımlar.
- GitHub Pages ücretsiz planda herkese açık depolarda ücretsizdir.

## Supabase bağlantısı

`config.js` dosyası Supabase Project URL ve publishable/anon key içerir. Tarayıcıda kullanılmak üzere tasarlanmış publishable key depoda bulunabilir. `service_role` veya `sb_secret_` anahtarını asla web dosyalarına koyma.

Mevcut tablolar, öğretmen hesapları ve öğrenci yanıtları Supabase’te tutulur. Bu site taşıma işlemi Supabase verilerini değiştirmez. Authentication → URL Configuration bölümünde GitHub Pages adresi Site URL ve Redirect URLs olarak ayarlanmıştır; eski Netlify yönlendirmesi de geçiş sürecinde tutulur.

## Öğretmenin kullanım akışı

1. Öğretmen **Hesap oluştur** ile kayıt olur, e-postasını doğrular ve giriş yapar.
2. Sınıf düzeyi ve şubesini kaydeder; **Sınıf ve öğrenciler** bölümünden öğrenci adlarını ekler.
3. **Sınıfım** bölümünde haftalık ödev adı, açıklaması, hafta başlangıcı ve isteğe bağlı son tarihi girip yayımlar.
4. **Öğrenci bağlantıları** bölümünden öğrencilere özel bağlantı oluşturup yalnızca ilgili öğrenciyle paylaşır.
5. Öğrenci ödev durumunu seçer; iki yeni kelime ve konu yorumunu yazar. Öğretmen yanıtları sınıf ekranında görür ve gerekirse durumu kendisi işaretler.
6. Birden fazla sınıfı sınıf seçicisinden yönetebilir. Süresi biten ödevi kapatabilir; eski yanıtlar geçmişte saklanır.

## Veritabanı güncellemeleri

Mevcut Supabase projesinde SQL değişikliği gerektiğinde ilgili migration dosyasını Supabase SQL Editor’de çalıştır. Tüm şemayı mevcut veritabanında yeniden çalıştırma. Site kodu güncellemeleri ise yalnızca GitHub deposunun `main` dalına kaydedilir.

## Güvenlik

- Depo ve site herkese açıktır. Öğrenci adları, parolaları, ödev yanıtları veya başka özel veriler GitHub’a eklenmemelidir.
- Öğrenci parolaları uygulama veritabanında açık şekilde tutulmaz.
- Öğrenci bağlantıları kişiye özeldir; yalnızca ilgili öğrenciyle paylaşılmalıdır.

