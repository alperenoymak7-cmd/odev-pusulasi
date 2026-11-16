# Ödev Pusulası

Öğretmenlerin sınıf, öğrenci ve haftalık ödev takibi için statik web uygulaması.

**Yayın adresi:** https://alperenoymak7-cmd.github.io/odev-pusulasi/

## Yayın ve güncelleme

Site GitHub Pages üzerinde, `main` dalının kök klasöründen yayımlanır. Yeni sürüm için dosyaları depodaki `main` dalına kaydetmen yeterli; GitHub Pages otomatik günceller.

## Supabase bağlantısı

`config.js` uygulamanın Supabase Project URL ve publishable key değerlerini içerir. Publishable/anon anahtarı tarayıcıda kullanılan anahtardır; `service_role` veya `sb_secret_` anahtarını buraya koyma. Veritabanı, öğretmen hesapları, sınıflar ve öğrenci yanıtları Supabase’te kalır; GitHub’a taşınmaz.

Bu depo ve GitHub Pages sitesi herkese açıktır. Öğrenci bilgilerini, parolaları veya özel verileri depoya ekleme.

## Supabase adresleri

Supabase **Authentication → URL Configuration** bölümünde Site URL ve Redirect URLs olarak GitHub Pages adresi kayıtlıdır. Netlify adresi eski bağlantıların çalışabilmesi için yönlendirme listesinde bırakılmıştır.
