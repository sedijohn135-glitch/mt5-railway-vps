# MT5 në Railway

MetaTrader 5 që punon 24/7 në Railway, pa kompjuter dhe pa MetaApi.

- **Ekrani i MT5** (edhe nga telefoni): domain-i i shërbimit `mt5` në Railway, me përdoruesin `CUSTOM_USER` dhe fjalëkalimin `PASSWORD`.
- **Botët** lidhen me MT5 te `mt5.railway.internal:8001` (API-ja zyrtare MetaTrader5 përmes RPyC), vetëm brenda rrjetit privat të Railway.

## Variablat (Railway → mt5 → Variables)

| Variabla | Çfarë është |
|---|---|
| `CUSTOM_USER`, `PASSWORD` | Hyrja në ekranin e MT5. Pa `PASSWORD` shërbimi nuk niset. |
| `MT5_LOGIN`, `MT5_PASSWORD`, `MT5_SERVER` | Llogaria MT5 (serveri si në email-in e IC Markets, p.sh. `ICMarketsSC-Demo`). Me to MT5 hyn vetë në llogari dhe niset me Algo Trading të ndezur. Pa to, hyr nga ekrani. |

Volumi: `/config`. Aty ruhen MT5, Wine dhe hyrja në llogari, kështu që një restart nuk e instalon MT5 nga e para.

**Nëse MT5 nuk lidhet** (titulli s'ka "Demo Account"/"Real Account", Journal-i s'ka "authorized"): MT5 i MetaQuotes nuk e
njeh serverin e brokerit. Një herë në ekran: File → Open an Account → shkruaj serverin (p.sh. `ICMarketsSC-Demo`) →
Find your company → Cancel. MT5 lidhet vetë dhe e mban serverin në volum.

**Kujdes:** porta 8001 nuk hapet kurrë publikisht. Kushdo që e arrin mund të tregtojë në llogarinë tënde.

Image-i bazë: [gmag11/MetaTrader5-Docker-Image](https://github.com/gmag11/MetaTrader5-Docker-Image), me Wine 11 (WineHQ), sepse MT5 i sotëm nuk niset me Wine 10.

## Kontrolli

`sh test.sh`
