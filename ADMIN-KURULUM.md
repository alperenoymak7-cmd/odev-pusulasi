# Yönetici erişimi kurulumu

Bu özellik e-posta ve şifreye ek olarak ayrı bir yönetici kodu ister. Yönetici tüm öğretmenlerin sınıflarını, öğrencilerini, ödevlerini ve öğrenci yanıtlarını görüntüler. Ekran salt okunurdur. Öğrenci şifreleri, oturum anahtarları ve bağlantı tokenları yöneticiye açılmaz.

## Mevcut Supabase projesinde etkinleştirme

1. Supabase Dashboard → **SQL Editor → New query** bölümünde `admin-access-migration.sql` dosyasının tamamını çalıştırın.
2. Kendi öğretmen hesabınızın e-posta adresini ve en az 16 karakterlik rastgele bir yönetici kodunu seçin. Kodu parola yöneticinizde saklayın; siteye ya da bu projedeki dosyalara yazmayın.
3. Supabase SQL Editor'de aşağıdaki sorguda e-posta ve kod yer tutucularını değiştirip çalıştırın. Bu sorgu yalnızca kodun bcrypt özetini saklar.

```sql
insert into private.admin_allowlist(email, code_hash)
values (
  lower('YOUR_TEACHER_EMAIL'),
  extensions.crypt('YOUR_LONG_RANDOM_ADMIN_CODE', extensions.gen_salt('bf', 12))
)
on conflict (email) do update set code_hash = excluded.code_hash;
```

4. Yönetici alanına girmek için siteyi açıp **Yönetici girişi** sekmesini seçin. Aynı yetkili öğretmen e-postasını, normal şifresini ve ayrı yönetici kodunu girin. Kod 8 saatlik yönetici oturumu açar; 15 dakika içinde 5 hatalı kod denemesi olursa kod doğrulaması 15 dakika kilitlenir.

Yönetici kodunu değiştirmek için aynı SQL sorgusunu yeni kodla yeniden çalıştırın. Bir hesabın yönetici erişimini kaldırmak için:

```sql
delete from private.admin_allowlist where email = lower('YOUR_TEACHER_EMAIL');
delete from private.admin_sessions
where user_id = (select id from auth.users where lower(email) = lower('YOUR_TEACHER_EMAIL'));
```

## Yeni Supabase kurulumu

`supabase-schema.sql` temel sınıf ve ödev tablolarını kurar. Yönetici özelliğini de kullanacaksanız ardından `admin-access-migration.sql` dosyasını çalıştırıp yukarıdaki özel allowlist kaydını ekleyin.
