#!/usr/bin/env bash
# 檢查網站是否仍使用 TWCA 序號隨機性不足事件（Mozilla Bug 2087236）中受影響的中繼憑證
# 用法：./check_twca.sh www.example.gov.tw [example.com:8443 ...]
# 需求：openssl（macOS 內建的 LibreSSL 亦可）、perl（macOS 內建）
# 相容 macOS 內建 bash 3.2 與 Linux

# Bugzilla 2087236 列出的 6 張受影響 TLS 中繼 CA（SHA-256 指紋）
affected_name() {
  case "$1" in
    01af2324d098098f5e0cdf6faabada430b21cce777f47eacb26248b2fda3e531) echo "TWCA SSL Certification Authority (2023-02-23)" ;;
    f76e3339a6773dc5922da154628c8d22b5c915edcb15270db8fb3d8d24959e98) echo "TWCA EVSSL Certification Authority (2023-02-23)" ;;
    c6e96a1745707099f02279472fa28a99bae447d77511e19e86baf3047651c1eb) echo "TWCA Secure SSL Certification Authority (2023-08-18)" ;;
    1a2c75fd096e0499e9ff6ac74e526f61eaae3edfc8c2ea4436fee0c24d8b7d0e) echo "TWCA Secure SSL Certification Authority (2023-10-16)" ;;
    815c549c6976bf163eb54710ffc7806b1e7541c688313312b606837767164094) echo "TWCA SSL Certification Authority (2024-09-06)" ;;
    cac9fd0cd35aa5c480cd03fdd6edf0ca1a41fd02ac290ec83d83ceedf8ec245c) echo "TWCA EVSSL Certification Authority (2024-09-06)" ;;
  esac
}

# 重新簽發大約從此日開始（Bugzilla 通報日 2026-10-30）
REISSUE_AFTER="2026-10-30"

# 跨平台的逾時執行（macOS 沒有 timeout 指令，改用 perl alarm）
run_with_timeout() {
  local secs="$1"; shift
  perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
}

# 把 openssl 的日期（例如 "Nov  1 03:00:00 2026 GMT"）轉成 YYYY-MM-DD，不依賴 GNU/BSD date
to_iso_date() {
  local mon day year m
  read -r mon day _ year _ <<<"$1"
  case "$mon" in
    Jan) m=01;; Feb) m=02;; Mar) m=03;; Apr) m=04;; May) m=05;; Jun) m=06;;
    Jul) m=07;; Aug) m=08;; Sep) m=09;; Oct) m=10;; Nov) m=11;; Dec) m=12;;
    *) echo "?"; return;;
  esac
  printf "%s-%s-%02d\n" "$year" "$m" "$((10#$day))"
}

if [ $# -eq 0 ]; then
  echo "用法：$0 網域[:埠] [網域[:埠] ...]"; exit 1
fi

for target in "$@"; do
  host="${target%%:*}"
  port="${target#*:}"; [ "$port" = "$target" ] && port=443
  echo "=== $host:$port ==="

  chain=$(echo | run_with_timeout 15 openssl s_client -connect "$host:$port" -servername "$host" -showcerts 2>/dev/null)
  if [ -z "$chain" ] || ! grep -q "BEGIN CERTIFICATE" <<<"$chain"; then
    echo "  [錯誤] 無法連線或取得憑證"; echo; continue
  fi

  # 把伺服器送出的每張憑證拆開
  certs=()
  cur=""
  while IFS= read -r line; do
    [ "$line" = "-----BEGIN CERTIFICATE-----" ] && cur=""
    cur="$cur$line"$'\n'
    [ "$line" = "-----END CERTIFICATE-----" ] && certs+=("$cur")
  done <<<"$chain"

  leaf="${certs[0]}"
  issuer=$(openssl x509 -noout -issuer <<<"$leaf" | sed 's/^issuer= *//')
  notbefore=$(openssl x509 -noout -startdate <<<"$leaf" | cut -d= -f2)
  nb_iso=$(to_iso_date "$notbefore")
  echo "  網站憑證簽發者：$issuer"
  echo "  網站憑證生效日：$nb_iso"

  if ! grep -qi "TAIWAN-CA\|TWCA" <<<"$issuer"; then
    echo "  [不適用] 不是 TWCA 簽發的憑證"; echo; continue
  fi

  hit=0
  i=1
  while [ $i -lt ${#certs[@]} ]; do
    fp=$(openssl x509 -noout -fingerprint -sha256 <<<"${certs[$i]}" | cut -d= -f2 | tr -d ':' | tr 'A-F' 'a-f')
    cn=$(openssl x509 -noout -subject <<<"${certs[$i]}" | sed 's/.*CN *= *//; s/[,/].*//')
    name=$(affected_name "$fp")
    if [ -n "$name" ]; then
      echo "  [受影響] 中繼憑證：$name"
      hit=1
    else
      echo "  [正常]   中繼憑證：$cn ($fp)"
    fi
    i=$((i + 1))
  done
  [ ${#certs[@]} -lt 2 ] && echo "  [注意] 伺服器沒有送出中繼憑證（憑證鏈不完整，建議補上）"

  if [ "$nb_iso" != "?" ] && [[ "$nb_iso" < "$REISSUE_AFTER" ]]; then
    echo "  [受影響] 網站憑證在 $REISSUE_AFTER 之前簽發，應是舊憑證，需換成 TWCA 重新簽發的版本"
    hit=1
  fi

  if [ $hit -eq 1 ]; then
    echo "  >> 結論：需要更新"
  else
    echo "  >> 結論：看起來已更新完成"
  fi
  echo
done
