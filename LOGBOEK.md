# Logboek — Blik op Nederland, verrijkt

Levend document. Elke bevinding, keuze en valkuil komt hier te staan, zodat we
later niet opnieuw hoeven uit te zoeken waarom iets is zoals het is.

Bijwerken bij elke nieuwe bron, elke correctie en elke beslissing.

Laatst bijgewerkt: 8 september 2026.

---

## 1. Genomen besluiten

Vastgelegd, niet opnieuw ter discussie tenzij er nieuwe informatie is.

| # | Besluit | Datum | Reden |
|---|---|---|---|
| B1 | **CBS wint altijd** bij overlappende jaren | 08-09-2026 | CBS-cijfers zijn actueler en herzien; de Rekenkamer neemt ze zelf ook van CBS over |
| B2 | R&D: 3% als hoofdnorm, 2,5% als tweede doel tonen | 08-09-2026 | 3% is de EU-doelstelling waar de Rekenkamer naar verwijst in `legitimatie`; 2,5% is het Nederlandse doel sinds 2011 |
| B3 | R&D-historie alleen vanaf 2013 | 08-09-2026 | CBS bracht de statistiek in 2019 in lijn met de Frascati-handleiding, met terugwerkende kracht tot 2013; oudere jaren zijn niet vergelijkbaar |
| B4 | Geen doelen verzinnen waar ze niet bestaan | 08-09-2026 | Dat 22 indicatoren geen richting hebben is zelf een bevinding, geen gat om te vullen |
| B5 | Politieke richtingen bewust leeg laten | 08-09-2026 | Zie §4; invullen zou een standpunt als feit presenteren |
| B6 | Hosten op GitHub Pages, geen R-server | 08-09-2026 | Quarto levert statische HTML; bezoekers hebben geen account nodig |
| B7 | Correcties via `doelen_review.csv`, niet in de code | 08-09-2026 | Houdt zichtbaar wat de bron zegt en wat onze interpretatie is |

---

## 2. Over de bron

**Dataset:** *Blik op Nederland: Dashboard Doelen en Resultaten*, Algemene
Rekenkamer, gepubliceerd 20-05-2026 onder CC0 1.0 Universal.

**Structuur** (geverifieerd 08-09-2026): één blad, 71 indicatoren in 10
thema's, breed formaat. Na `remove_empty()` en `clean_names()`: `thema`,
`indicator`, `x2012`, `x2018`, `x2020` t/m `x2025`, `bron`,
`doel_streefwaarde_bedoeling`, `legitimatie`, `doel_coalitie`,
`bedoeling_coalitie`.

Bevindingen over de bron zelf:

- **`thema` staat alleen op de eerste rij van elke groep.** Moet doorgevuld
  worden, anders raak je negen van de tien thema's kwijt.
- **De kolom 2019 is volledig leeg** en vervalt bij `remove_empty()`.
- **Er is geen numerieke doelkolom.** `doel_streefwaarde_bedoeling` is vrije
  tekst in drie soorten: een streefwaarde met jaartal (`Doel 2030: 80%`),
  alleen een richting (`Hoe lager, hoe beter`), of niets.
- **Er is geen eenheidkolom.** De eenheid staat tussen haakjes in de
  indicatornaam: `EMU-saldo (€ mld)` → `€ mld`.
- **De reeksen zijn kort.** 332 waarnemingen, mediaan 5 metingen per
  indicator, 15 indicatoren met minder dan 3. De coronadip van 2020-2021
  domineert daardoor vrijwel elk beeld terwijl dat geen beleid is.
- **Slechts 8 indicatoren hebben een expliciet coalitiedoel.**

---

## 3. Fouten in de bron

Gevonden en gecorrigeerd via `doelen_review.csv`. De oorspronkelijke waarde
blijft zichtbaar in de `_auto`-kolommen.

| Indicator | Bron zegt | Moet zijn | Grond |
|---|---|---|---|
| R en D uitgaven (% BBP) | 0,03 | 3 | Fractie waar percentage hoort; OCW: "uitgaven liggen beneden de doelstelling van 3%" |
| Uitgaven ontwikkelingssamenwerking (% BNI) | 0,007 | 0,7 | Fractie waar percentage hoort; VN-norm 0,7% van bni |
| Broeikasgasemissies (Mton) | -90 | 22,7 | Parser pakte de procentuele reductie; 22,7 Mton staat letterlijk in dezelfde brontekst (`2040: -90% t.o.v. 1990 = 22,7`) |

Dat de eerste twee als fractie zijn ingevuld terwijl de meetreeks in procenten
staat, is het soort fout dat een eigen dashboard zichtbaar maakt en het
origineel niet.

---

## 4. Bewust niet ingevuld

Drie indicatoren houden geen richting, omdat er geen afgesproken gewenste
richting bestaat. Dit invullen zou een politiek standpunt als feit
presenteren.

- Totale overheidsuitgaven als % bbp
- Verdeling woningvoorraad naar eigendom (koop)
- Verdeling woningvoorraad naar eigendom (vrije sectorhuur)

Ter vergelijking: bij *sociale huur* stáát er wel een richting in de bron
("Meer is beter"). Dat de Rekenkamer die bij koop en vrije sectorhuur weglaat,
is zelf informatief.

---

## 5. Stand van zaken

Na de eerste invulronde, 08-09-2026:

| | aantal |
|---|---|
| Indicatoren | 71 |
| Richting bekend | 68 |
| Streefwaarde bekend | 25 |
| **Met een echt oordeel** | **22** (was 9) |

Statusverdeling: 5 doel gehaald, 4 op koers, 7 te traag, 6 verkeerde richting,
43 alleen richting, 3 geen richting, 3 te weinig data.

Opvallendste uitkomsten:

- **R&D-uitgaven**: 2,29% in 2024, doel 3%. Bij het huidige tempo bereikt rond
  **2083**. Ook tegen het lagere Nederlandse doel van 2,5% duurt het decennia.
- **Ontwikkelingssamenwerking**: schommelt tussen 0,52 en 0,67 zonder trend.
  Doel 0,7% bereikt rond 2165, wat neerkomt op: niet.
- **Broeikasgas**: daalt met 5,7 Mton per jaar, doel 22,7 in 2040 bereikt rond
  **2047**.
- **Verkeerde richting**: beide vaccinatiegraden, voldoende beweging, rokers
  12-18, vroegtijdig schoolverlaters, vullingsgraad krijgsmacht.

---

## 6. Externe bronnen

### CBS StatLine — gekoppeld

| Indicator | Tabel | Kolom | Dimensie | Periode |
|---|---|---|---|---|
| EMU-schuld (% BBP) | 84118NED | `SchuldEMU_13` | `InstitutioneleSectoren` = "Overheid" | 1995-2025 |
| EMU-saldo (% BBP) | 84118NED | `Saldo_12` | idem | 1995-2025 |
| R en D uitgaven (% BBP) | 84644NED | `RDIntensiteit_4` | `Sectoren` = "Alle sectoren" | 2013-2024 |

Valkuilen die we tegenkwamen:

- **84118NED heeft elke maatstaf twee keer**: in mln euro (`SchuldEMU_4`) en in
  % bbp (`SchuldEMU_13`). Wij willen de tweede.
- **De dimensie heet `InstitutioneleSectoren`**, niet `Overheidssectoren`. Het
  totaal heet "Overheid"; subsectoren (Rijk, gemeenten, provincies, sociale
  fondsen) staan apart in dezelfde tabel en moet je eruit filteren.
- **84644NED gebruikt `Sectoren`** met totaal "Alle sectoren".
- **Kwartaalcijfers zitten in dezelfde tabel** (84118NED vanaf 1999). Filteren
  op `Perioden_freq == "Y"`.
- Gebruik `verken_tabel("<id>")` uit `R/04_cbs_historie.R` om dimensies en
  kolomnamen op te zoeken; raden werkt niet.

### Validatieresultaat (08-09-2026)

| Indicator | Overlap | Afwijkend | Max verschil |
|---|---|---|---|
| EMU-schuld | 6 jaren | 2 (2024, 2025) | 0,30 pp |
| EMU-saldo | 6 jaren | 0 | 0,10 pp |
| R&D | 5 jaren | 0 | 0,07 pp |

**Duiding:** de afwijking bij EMU-schuld zit uitsluitend in 2024 en 2025 — de
jaren die CBS zelf als voorlopig markeert. De Rekenkamer publiceerde in mei
2026; CBS heeft daarna herzien. Dat 2020 t/m 2023 exact matchen, bewijst dat de
tabel hetzelfde meet. Dit is een revisie, geen definitieverschil, en bevestigt
besluit B1.

De tolerantie van 0,15 procentpunt bleek te streng voor reeksen in procenten
van het bbp. Zie openstaand punt O1.

### Nog te koppelen

- **Eurostat** voor de internationale positie. Kandidaten: `rd_e_gerdtot`
  (R&D), `nrg_ind_ren` (hernieuwbaar), `sdg_13_10` (broeikasgas). Levert rang
  van Nederland en afstand tot het EU-gemiddelde.
- **PBL, Klimaat- en Energieverkenning** voor broeikasgas, hernieuwbare energie
  en stikstof. Let op: rekent *vastgesteld* beleid door, niet voorgenomen
  beleid. Dat verschil moet expliciet benoemd worden.
- **CPB** (CEP, MEV, MLT) voor bbp-groei, werkloosheid, EMU-saldo en -schuld,
  armoede. Komt uit publicaties, niet uit een API: handwerk. De bijlagen
  bevatten ook lange historische reeksen.

---

## 7. Technische valkuilen

Opgelost, maar het kostte tijd. Niet opnieuw in trappen.

- **Cairo op macOS.** Zonder XQuartz faalt het standaard svg-device met
  `libXrender.1.dylib not found`. Oplossing: `svglite` en `ragg`, en het device
  in de **YAML-kop** van de qmd zetten — niet in het setup-chunk, want knitr
  opent het device vóór de code van het eerste chunk draait.
- **Werkmap in Quarto.** Quarto rendert vanuit `docs/` en knitr zet de werkmap
  na élk chunk terug. Een `setwd()` in het setup-chunk geldt dus maar één
  chunk. Oplossing: `vind_projectmap()` in `00_config.R` loopt omhoog tot het
  `Rekenkamer.Rproj` vindt; alle paden zijn daarna absoluut.
- **Stale sessievariabelen.** Een `projectmap` uit een vorige sessie werd
  hergebruikt, waardoor scripts naar het oude project schreven. `projectmap`
  wordt nu altijd opnieuw bepaald. Bij twijfel: R herstarten.
- **OneDrive-paden op macOS.** `~/OneDrive/...` en
  `~/Library/CloudStorage/OneDrive-Personal/...` wijzen naar dezelfde plek maar
  zien er verschillend uit. `run_all.R` logt daarom de projectmap.
- **Puntkomma's in csv-tekst.** Het reviewbestand is puntkomma-gescheiden;
  een puntkomma in een opmerking breekt het bestand. Wordt nu gequote.
- **`geom_line()` bij één meting.** Vijftien indicatoren hebben te weinig
  punten voor een lijn. Alleen een lijn tekenen bij ≥2 punten.
- **Excel verbouwt het reviewbestand.** Openen met een teksteditor.

---

## 8. Openstaande punten

| # | Punt | Status |
|---|---|---|
| O1 | Tolerantie in `vergelijk()` verhoogd van 0,15 naar 0,5 pp | **gedaan** 08-09 |
| O2 | CBS-historie koppelen in de keten (B1 toepassen) | volgende stap |
| O3 | `04_cbs_historie.R` opnemen in `run_all.R` | na O2 |
| O4 | 43 indicatoren met alleen een richting: bestaat er ergens toch een norm? | open |
| O5 | Reeksbreuken markeren in de grafiek (armoede: nieuwe CBS-SCP-Nibud-methode) | open |
| O6 | Lineaire trend vervangen door iets dat een knik aankan | open |
| O7 | GitHub Pages inrichten en eigen domein koppelen | project 2 |

---

## 9. Wat dit project niet doet

- Geen eigen metingen; alles komt van CBS, CPB, PBL, RIVM, Eurostat, OESO.
- Geen doelen verzinnen (B4) en geen politieke richtingen invullen (B5).
- Geen interactief rekenen — dat is project 2 (rentescenario's,
  schuldquote, sociale zekerheid).
