# MT5 në Railway

MetaTrader 5 që punon 24/7 në Railway, pa kompjuter dhe pa MetaApi.

- **Ekrani i MT5** (edhe nga telefoni): domain-i i shërbimit `mt5` në Railway, me përdoruesin `CUSTOM_USER` dhe fjalëkalimin `PASSWORD`.
- **Botët** lidhen me MT5 te `mt5.railway.internal:8001` (librari `mt5linux`), vetëm brenda rrjetit privat të Railway.

## Variablat (Railway → mt5 → Variables)

| Variabla | Çfarë është |
|---|---|
| `CUSTOM_USER`, `PASSWORD` | Hyrja në ekranin e MT5. Pa `PASSWORD` shërbimi nuk niset. |
| `MT5_LOGIN`, `MT5_PASSWORD`, `MT5_SERVER` | Llogaria MT5 (serveri si në email-in e IC Markets, p.sh. `ICMarketsSC-Demo`). Me to MT5 hyn vetë në llogari dhe niset me Algo Trading të ndezur. Pa to, hyr nga ekrani. |

Volumi: `/config`. Aty ruhen MT5, Wine dhe hyrja në llogari, kështu që një restart nuk e instalon MT5 nga e para.

**Kujdes:** porta 8001 nuk hapet kurrë publikisht. Kushdo që e arrin mund të tregtojë në llogarinë tënde.

Image-i bazë: [gmag11/MetaTrader5-Docker-Image](https://github.com/gmag11/MetaTrader5-Docker-Image) (Wine 10, KasmVNC, mt5linux).

## Kontrolli

`sh test.sh`
