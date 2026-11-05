# twca-cert-check

檢查網站是否仍在使用 TWCA（臺灣網路認證）**序號隨機性不足事件**中受影響的中繼憑證，或尚未換成重新簽發的網站憑證。

## 事件背景

2026 年 10 月 30 日，Mozilla Bugzilla 有人通報 TWCA 簽發的 CA 憑證序號隨機性不足（[Bug 2087236](https://bugzilla.mozilla.org/show_bug.cgi?id=2087236)）。序號名義上有 128 bits，但只有約 24 bits 是隨機的，未達 CA/Browser Forum 規範要求的 64 bits CSPRNG 輸出。

受影響的中繼憑證會在 **2026-11-06 00:00（UTC+8）** 前被廢止，掛在這些中繼憑證底下的網站憑證需要換成 TWCA 用新中繼憑證重新簽發的版本，否則瀏覽器會出現憑證錯誤。這次是用原金鑰重新簽發，網站的私鑰不需要更換。

## 判斷方式

腳本會連線到網站，取出伺服器實際送出的憑證鏈，再檢查兩件事，符合任一項就判定為需要更新：

1. **中繼憑證的 SHA-256 指紋**是否在 Bugzilla 2087236 列出的 6 張受影響 TLS 中繼 CA 之中。
2. **網站憑證的生效日**是否早於 2026-10-30（推估的重新簽發起始日）。

受影響的 TLS 中繼 CA：

| 名稱 | 簽發日 | SHA-256 |
|---|---|---|
| TWCA SSL Certification Authority | 2023-02-23 | `01af2324d098098f5e0cdf6faabada430b21cce777f47eacb26248b2fda3e531` |
| TWCA EVSSL Certification Authority | 2023-02-23 | `f76e3339a6773dc5922da154628c8d22b5c915edcb15270db8fb3d8d24959e98` |
| TWCA Secure SSL Certification Authority | 2023-08-18 | `c6e96a1745707099f02279472fa28a99bae447d77511e19e86baf3047651c1eb` |
| TWCA Secure SSL Certification Authority | 2023-10-16 | `1a2c75fd096e0499e9ff6ac74e526f61eaae3edfc8c2ea4436fee0c24d8b7d0e` |
| TWCA SSL Certification Authority | 2024-09-06 | `815c549c6976bf163eb54710ffc7806b1e7541c688313312b606837767164094` |
| TWCA EVSSL Certification Authority | 2024-09-06 | `cac9fd0cd35aa5c480cd03fdd6edf0ca1a41fd02ac290ec83d83ceedf8ec245c` |

## 使用方式

需求：`openssl`（macOS 內建的 LibreSSL 亦可）、`perl`（macOS 與多數 Linux 內建）。相容 macOS 內建的 bash 3.2。

```bash
chmod +x check_twca.sh
./check_twca.sh www.example.gov.tw shop.example.com:8443
```

輸出範例：

```
=== www.example.gov.tw:443 ===
  網站憑證簽發者：C = TW, O = TAIWAN-CA, CN = TWCA SSL Certification Authority
  網站憑證生效日：2025-05-20
  [受影響] 中繼憑證：TWCA SSL Certification Authority (2024-09-06)
  [受影響] 網站憑證在 2026-10-30 之前簽發，應是舊憑證，需換成 TWCA 重新簽發的版本
  >> 結論：需要更新
```

## 限制

- 指紋清單只涵蓋 Bugzilla 2087236 截至 2026-11-05 列出的 6 張 TLS 中繼 CA。TWCA 預計在 2026-11-12 更新完整事件報告，清單可能會變動。
- 2026-10-30 這個日期分界是推估。若網站憑證剛好在 10 月底正常續約，請向 TWCA 確認。
- 「不在清單內」只代表沒用到已知的受影響憑證，不是 TWCA 的官方認證結果。

## 參考資料

- [Bugzilla 2087236 – TWCA: CA certificate serial numbers contain fewer than 64 bits of CSPRNG output](https://bugzilla.mozilla.org/show_bug.cgi?id=2087236)
- [數位發展部新聞稿：已督促 TWCA 完成產製符合標準新憑證](https://moda.gov.tw/press/press-releases/21226)

## 授權

[MIT](LICENSE)
