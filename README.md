# Discord DPI (macOS)

Türkiye'deki Discord erişim engelini macOS'ta aşmak için tek tıkla açılan bir uygulama.

`/Applications` klasörüne **Discord DPI** adında bir uygulama kurar. Bu uygulamayı açınca:

1. [GoodbyeDPI-Turkey](https://github.com/cagritaskn/GoodbyeDPI-Turkey)'nin macOS yöntemi ([byedpi](https://github.com/hufrea/byedpi) / `ciadpi`) `127.0.0.1:1080` adresinde yerel bir HTTP proxy olarak başlar.
2. Discord bu proxy ile açılır. Proxy'den yalnızca Discord geçer; sistemin proxy ve DNS ayarlarına dokunulmaz.
3. Discord kapatılınca proxy de kendiliğinden kapanır.

Discord zaten proxy'siz açıksa (ya da bir güncellemeden sonra proxy'siz yeniden açılırsa) uygulama onu kapatıp proxy ile yeniden açar.

## Kurulum

Gerekenler: macOS 13 veya üstü (Apple Silicon ya da Intel), `/Applications` içinde kurulu Discord ve Xcode Command Line Tools (yoksa betik kurulum penceresini kendisi açar).

```bash
git clone https://github.com/alisencerefeturk/gitdpi.git
cd gitdpi
./install.sh
```

Betik byedpi'yi kaynak koddan derler, uygulamayı oluşturur ve Discord'a proxy üzerinden erişilebildiğini test eder. Uygulama bilgisayarında derlendiği için "geliştirici doğrulanamadı" uyarısı çıkmaz.

Kurulumdan sonra Discord'u her zaman **Discord DPI** uygulamasından aç. İstersen Dock'a sabitleyebilirsin. Discord'u doğrudan açarsan proxy kullanılmaz.

## Çalışmazsa: başka yöntem dene

Servis sağlayıcıya göre farklı yöntemler işe yarayabilir. Kurulumu yöntem adıyla tekrar çalıştırman yeterli:

```bash
./install.sh alt3     # ya da: alt, alt6, default
```

| Yöntem | ciadpi parametreleri |
|---|---|
| `default` | `--split 1+s --disorder 3+s --tlsrec 3+s --mod-http hcsmix,dcsmix` |
| `alt` | `--disorder 3+s --tlsrec 3+s` |
| `alt3` | `--disorder 1+s --tlsrec 1+s` |
| `alt6` | `--split 1+s --tlsrec 1+s` |

Kayıtlar: `~/Library/Logs/DiscordDPI/`

## Notlar

- Sesli sohbet UDP kullandığı için proxy'den geçmez, doğrudan bağlanır.
- `1080` portu başka bir program tarafından kullanılıyorsa uygulama uyarı verip kapanır.

## Kaldırma

```bash
./uninstall.sh
```

## Teşekkürler

- [byedpi](https://github.com/hufrea/byedpi) (hufrea): DPI atlatma aracı
- [GoodbyeDPI-Turkey](https://github.com/cagritaskn/GoodbyeDPI-Turkey) (cagritaskn): Türkiye için yöntem ayarları ve macOS eşlemeleri
