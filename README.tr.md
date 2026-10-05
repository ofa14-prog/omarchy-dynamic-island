# Omarchy için Dynamic Island

[English](README.md)

[Omarchy](https://omarchy.org) bar'ının ortasında Apple tarzı bir Dynamic Island. Gerçeği gibi yay
fiziğiyle açılan, baloncuklara bölünen ve titreyen tek bir siyah şekil: müzik, sayaç, ekran kaydı,
dosya rafı, kısayollar ve **Claude Code** oturumlarınız. Araç izinlerini doğrudan adadan
onaylayabilir ya da reddedebilirsiniz.

## Özellikler

| | |
|---|---|
| **Kompakt** | Boştayken saat; canlı etkinlik varsa solda ve sağda bilgi, ortası temiz |
| **Baloncuklar** | İkinci canlı etkinlik sağa, üçüncüsü sola ayrılır; her biri kendi başına çalışır |
| **Peek** | Şarkı değişti, Claude bitirdi, şarj başladı… için kısa bant |
| **Genişletilmiş** | Ana · Müzik · Claude · Sayaç · Raf sekmeleri |
| **Uyarılar** | Claude izin isterse ya da süre dolarsa ada kendiliğinden açılır, cevaplanana kadar açık kalır |

- **Ana sayfa**: saat/tarih, Claude kullanım halkaları (5 saat / haftalık), pil; *varsayılan*
  ajan, editör, tarayıcı, dosya yöneticisi ve terminaliniz için kendi uygulama ikonlarıyla
  kısayollar; hızlı zamanlayıcılar.
- **Müzik**: tüm MPRIS oynatıcılar; kapak, sürüklenebilir ilerleme çubuğu, kontroller. Dalga formu kapak renginde.
- **Claude Code**: tüm oturumlar, o an ne yaptıkları ve süreleri; terminale git, klasörü editörde aç, yeni oturum.
- **İzinler**: araç, dosya/komut, renkli diff; **İzin ver / Her zaman / Reddet**. Ada, Claude'un terminal
  sorusuyla yarışır: hangisinden cevap verirseniz diğeri kapanır.
- **Sayaç**: geri sayım (+1 dk, duraklat, tekrarla) ve kronometre; süre dolunca ses.
- **Ekran kaydı**: Omarchy kaydı kırmızı kayıt etkinliği olarak görünür; tıklayınca durur.
- **Raf**: dosyaları adaya bırakın, sonra istediğiniz uygulamaya geri sürükleyin.
- Claude'un kendi spinner'ı (`· ✢ * ✶ ✻ ✽`) ve durum parlaması, canlı bir `claude` oturumundan alındı.
- Türkçe ve İngilizce arayüz; Omarchy sistem fontunu kullanır.

### Etkileşim

| Hareket | Sonuç |
|---|---|
| Üzerine gel | Hafif büyür, imlece doğru eğilir; 380 ms sonra açılır |
| Tıkla | Açılır (basılıyken içe çöker) |
| Sağ tık | Ana sayfa |
| Müzikte orta tık | Oynat / duraklat |
| Kompakt adada tekerlek | Ses |
| Dosya sürükle | Raf açılır |
| İmleç ayrılır | 650 ms sonra kapanır (uyarı beklerken hariç) |
| Baloncuk: tık / sağ tık / orta tık | Aç / adaya geçir / oynat-duraklat |

Klavye (ada odaktayken): `Esc` kapat/reddet · `Enter`/`Y` izin ver · `A` her zaman · `N` reddet ·
`T` terminal · `[` `]` sekme · `Tab` düğmeler arası · `Boşluk` oynat/duraklat.

## Gereksinimler

- Omarchy 4 (Quickshell tabanlı `omarchy-shell`) ve Hyprland
- Omarchy'de zaten var: `python3`, `jq`, `pw-play`, `notify-send`, `wl-copy`, `xdg-open`
- İsteğe bağlı: Claude özellikleri için [Claude Code](https://claude.com/claude-code)

## Kurulum

```sh
omarchy plugin add https://github.com/ofa14-prog/omarchy-dynamic-island.git
omarchy plugin enable io.github.ofa14-prog.dynamic-island
```

Bar'ın ortasında yer açın (ortadaki widget'ları sağa taşır, geri alınabilir):

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-bar-setup
# geri al: …/bin/dynamic-island-bar-setup --undo
```

Claude Code'u bağlayın: adanın Claude sayfasındaki **Bağla** düğmesiyle ya da:

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-claude-setup
```

`~/.claude/settings.json` dosyasını (veya `$CLAUDE_CONFIG_DIR`) yedekleyip hook'ları ekler;
`--remove` yalnızca bunları kaldırır. Durum olayları `async` çalışır, Claude'u yavaşlatmaz. Ada
çalışmıyorsa hook hiçbir şey yazmaz ve Claude normal davranır.

İsteğe bağlı kısayollar, `~/.config/hypr/bindings.lua` içine:

```lua
o.bind("SUPER + ALT + I", "Dynamic Island", "omarchy-shell -q dynamicisland toggle")
o.bind("SUPER + ALT + Y", "Claude: izin ver", "omarchy-shell -q dynamicisland approve")
o.bind("SUPER + ALT + N", "Claude: reddet", "omarchy-shell -q dynamicisland deny")
o.bind("SUPER + ALT + T", "Dynamic Island: sayaç", "omarchy-shell -q dynamicisland open timer")
```

## Ayarlar

İsteğe bağlı `~/.config/omarchy/dynamic-island.json`; değişiklikler anında uygulanır. Tüm anahtarlar
için [İngilizce README'deki tabloya](README.md#settings) bakın. Örnek:

```json
{ "language": "tr", "reduceMotion": false, "hoverDelay": 380 }
```

## IPC

```sh
omarchy-shell dynamicisland toggle | open <home|music|claude|timer|shelf> | close
omarchy-shell dynamicisland approve | always | deny
omarchy-shell dynamicisland timer 300 | stopwatch | timerStop
omarchy-shell dynamicisland shelfAdd /dosya/yolu
omarchy-shell dynamicisland notify "Başlık" "Alt satır"
omarchy-shell dynamicisland status
```

## Kaldırma

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-claude-setup --remove
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-bar-setup --undo
omarchy plugin remove io.github.ofa14-prog.dynamic-island
```

## Teşekkür

Arayüz ikonları [Reicon](https://github.com/dqev/reicon)'dan (MIT; temel ikonlar Solar Icons,
CC BY 4.0). Claude logosu Simple Icons üzerinden; Claude, Anthropic'in ticari markasıdır ve bu proje
Anthropic ile bağlantılı değildir. Ayrıntılar: [icons/NOTICE.md](icons/NOTICE.md).

MIT Lisansı, bkz. [LICENSE](LICENSE).
