# Ödev Pusulası

Öğretmenlerin sınıf, öğrenci ve haftalık ödev takibi için statik web uygulaması.

## GitHub Pages yayını

1. Bu dosyaları bir GitHub deposunun kök dizinine yükle.
2. Depoda **Settings → Pages** bölümünü aç.
3. **Build and deployment → Deploy from a branch** seç; `main` ve `/(root)` ayarlarını kaydet.
4. GitHub Pages adresi yayınlanınca Supabase **Authentication → URL Configuration** bölümünde Site URL’yi bu adrese ayarla ve aynı adresi Redirect URLs listesine ekle. Eski Netlify adresini geçişi tamamlayana kadar listede tutabilirsin.
5. Yeniden yayınlama gerekmez; Pages’in yayınlanmasını bekleyip yeni adreste giriş ekranını kontrol et.

## Supabase bağlantısı

`config.js` uygulamanın Supabase Project URL ve publishable key değerlerini içerir. Publishable/anon anahtarı tarayıcıda kullanılan anahtardır; `service_role` veya `sb_secret_` anahtarını buraya koyma. Veritabanı ve mevcut kullanıcı kayıtları Supabase’te kalır; GitHub’a taşınmaz.

GitHub Pages’te site ve kod herkes tarafından görülebilir. Öğrenci bilgilerini, parolaları veya özel verileri bu depoya ekleme.
