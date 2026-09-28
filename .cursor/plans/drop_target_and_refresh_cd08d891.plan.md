---
name: Drop target and refresh
overview: Bırakılan klasör bırakma sırasında belli olur; taşıma veya kopya bitince hedef klasör açılır. Uygulama öne gelince ekrandaki liste, boşaltılmadan yenilenir.
todos:
  - id: drop-highlight
    content: Klasör satırında dropEntered/dropExited vurgusu; hover seçim veya gezinme yapmaz
    status: completed
  - id: drop-open-target
    content: Başarılı bırakmada hedef farklıysa oraya git, seçimi koru, yazılan öğeleri seç
    status: completed
  - id: activate-refresh
    content: didBecomeActive iken açık liste ve açık ağacı boşaltmadan yenile; silinen satırları seçimden çıkar
    status: completed
isProject: false
---

# Bırakma hedefi ve öne gelince yenileme

## 1. Üzerinde durulan klasör belli olsun

Hover klasörü seçmez ve içine girmez. Sadece vurgu verir.

[Macxplorer/Views/FileDrop.swift](Macxplorer/Views/FileDrop.swift) içindeki `FileDropDelegate` `dropEntered` ve `dropExited` alır. Yalnızca `.folder` hedeflerinde bir kapanış çağrılır: girdi `true`, çıktı `false`. Dosya satırı, kayıp favori ve listenin boş alanı (açık klasörün kendisi) vurgu yakmaz.

- [Macxplorer/Views/FileListView.swift](Macxplorer/Views/FileListView.swift): `@State` olarak üzerinde durulan URL. Klasör satırının her hücresine aynı arka plan (`accentColor` yaklaşık 0.35 opaklık), böylece satır boyu okunur.
- [Macxplorer/Views/SidebarTreeView.swift](Macxplorer/Views/SidebarTreeView.swift): aynı durum favori ve ağaç satırında. `dropExited` yalnızca kendi URL’si işaretliyse temizler; üstteki tablo bırakması satır vurgusunu silmez.

## 2. Bırakınca hedef klasör açık kalsın

Yazma yeri değişmez. [Macxplorer/Editing/FileEditing.swift](Macxplorer/Editing/FileEditing.swift) `transfer` başarıdan sonra hâlâ `refreshedEntries` ile açık klasörü yeniliyor; o klasör kaynak.

Hedef, `selectedURL` ile aynı değilse:

1. [Macxplorer/ViewModels/BrowserModel.swift](Macxplorer/ViewModels/BrowserModel.swift) içindeki `preservesSelectionForRename` bayrağını navigate’den önce kaldır. [Macxplorer/ContentView.swift](Macxplorer/ContentView.swift) `selectedURL` değişince seçimi siliyor; rename ile aynı kapı bunu atlar.
2. `navigate(to: destination)` ile hedefi aç.
3. Gelen listeyi bekle. İkinci bir `refresh()` yok; `beginDetailLoad` listeyi boşaltır.
4. Yazılan URL’leri `listSelection` yap.

Hedef zaten açıksa bugünkü yol durur: açık klasör yenilenir, yeni öğeler seçilir.

## 3. Uygulama öne gelince ekrandakini yenile

[Macxplorer/ContentView.swift](Macxplorer/ContentView.swift) zaten `didBecomeActiveNotification` dinliyor; bugün yalnızca panoyu tazeliyor.

Aynı yerde, rename veya aktarım yokken ve ilk yükleme bitmişken (`isLoadingDetail && entries.isEmpty` değilken), görünür listeyi yenile.

`refresh()` kullanma. O, `beginDetailLoad` ile `entries = []` yapıyor ve `resetTree()` ile ağacı boşaltıyor; her Finder dönüşünde tablo flaşlar.

Yeni `refreshVisible()`:

- Açık klasörü yerinde listele. Eski satırlar yeni sonuç gelene kadar durur. Klasör silinmişse hata ve boş liste.
- Açık yan çubuk düğümlerini `loadChildren` ile güncelle. `resetTree()` yok.
- `listSelection` içinde artık listede olmayan URL’leri at. Quick Look, mevcut seçim değişince zaten kapanıyor.

Araç çubuğundaki Refresh (`Cmd-R`) sert `refresh()` olarak kalır.
