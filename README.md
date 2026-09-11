# Blik op Nederland — alternatief dashboard

**Live:** https://tridata4ds.github.io/Blik-op-Nederland/
**Repository:** https://github.com/Tridata4DS/Blik-op-Nederland

Een eigen dashboard op de indicatordata van de Algemene Rekenkamer, met één
inhoudelijke toevoeging: de vraag of een doel bij het huidige tempo gehaald
wordt. Het originele dashboard toont de reeks en het doel, maar trekt de trend
niet door.

> **Lees eerst [LOGBOEK.md](LOGBOEK.md).** Daar staan alle bevindingen, genomen
> besluiten, fouten in de bron en technische valkuilen. Dat document wordt bij
> elke stap bijgewerkt; deze README beschrijft alleen hoe het project werkt.

## Snel starten

1. Open `Rekenkamer.Rproj` in RStudio. De werkmap staat dan goed.
2. Draai `source("run_all.R")`.

Figuren worden weggeschreven met `svglite` en `ragg`, niet met het standaard
cairo-device. Op macOS zonder XQuartz faalt cairo namelijk met
`libXrender.1.dylib not found`; svglite en ragg hebben X11 niet nodig. Beide
worden bij de eerste run automatisch geïnstalleerd.

De eerste run downloadt de dataset, normaliseert hem, berekent de statussen,
schrijft figuren weg en rendert het dashboard naar `docs/dashboard.html`.

Na het clonen van de repository draai je eerst `00_maak_project.R`: lege
mappen komen niet mee uit Git.

## Mapstructuur

```
Rekenkamer/
├── R/                     scripts, genummerd op volgorde
│   ├── 00_config.R        paden, packages, logging, instellingen
│   ├── 01_inlezen.R       ophalen, inlezen, normaliseren
│   ├── 02_indicatoren.R   trend, projectie, doelafstand, status
│   ├── 03_figuren.R       losse figuren voor hergebruik
│   ├── 04_cbs_historie.R  reeksen verlengen via CBS StatLine
│   ├── 90_bronnen.R       fase 2: CBS, Eurostat, OECD, ramingen
│   └── functies.R         herbruikbare bouwstenen
├── data/
│   ├── raw/               downloads, per datum bewaard
│   ├── interim/           tussenresultaten (.rds)
│   └── clean/             analyseklare tabellen (.csv)
├── output/
│   ├── graphs/            svg en png voor presentaties en artikelen
│   └── tables/            geëxporteerde overzichten
├── docs/
│   ├── dashboard.qmd      het dashboard
│   └── rekenkamer.scss    vormgeving
├── logs/                  draailogboek per dag
├── 00_maak_project.R      mappen aanmaken na het clonen
├── run_all.R              de hele keten in een keer
├── 05_publiceren.R        lokaal testen, pullen, committen, pushen
└── .github/workflows/     wekelijks bouwen en publiceren
```

## Wat de bron wel en niet bevat

De dataset heeft 71 indicatoren in 10 thema's, in breed formaat met jaarkolommen
2012, 2018 en 2020 tot en met 2025. De kolom `Thema` staat alleen op de eerste
rij van elke groep en wordt door het script doorgevuld.

Er is geen numerieke doelkolom. Wat er staat is vrije tekst in
`Doel/Streefwaarde/Bedoeling`, en die valt uiteen in drie soorten:

| Soort | Voorbeeld | Aantal |
|---|---|---|
| Streefwaarde met jaartal | `Doel 2030: 80%` | 9 |
| Alleen een richting | `Hoe lager, hoe beter` | 40 |
| Niets | leeg | 22 |

Dat betekent dat bij slechts negen indicatoren automatisch te bepalen valt of
een doel gehaald wordt. Dat is geen tekortkoming van dit project maar een
eigenschap van de bron, en het dashboard maakt die tweedeling expliciet
zichtbaar in plaats van haar weg te poetsen.

## Eenmalig invullen

`data/clean/doelen_review.csv` bevat alle 71 indicatoren met de automatisch
afgeleide richting en streefwaarde ernaast, plus een kolom `te_doen` die
aangeeft wat nog ontbreekt. Vul de kolommen `richting_handmatig`,
`doel_handmatig` en `doeljaar_handmatig` in waar je een doel kent; die
overschrijven altijd de automatische waarde. Laat de rest leeg.

Het bestand is al voorgevuld meegeleverd, dus je begint niet blanco.

## Hoe de status wordt bepaald

Per indicator wordt een lineaire trend geschat over de laatste acht jaar en
doorgetrokken naar het doeljaar. Daaruit volgt:

| Status | Betekenis |
|---|---|
| Doel gehaald | de laatste meting voldoet al aan de norm |
| Op koers | de projectie komt binnen 5% van het doel uit |
| Te traag | beweegt de goede kant op, maar haalt het doeljaar niet |
| Verkeerde richting | beweegt van het doel af |
| Geen doel | geen norm of richting vastgelegd |

Een lineaire doortrekking is bewust simpel en voor indicatoren met een knik
in de reeks misleidend. Behandel de projectie als een doorrekening van het
verleden, niet als een prognose.

## Hosten

Het dashboard is statische HTML, dus er is **geen R-server nodig**. GitHub
Pages serveert het rechtstreeks uit `docs/` op https://tridata4ds.github.io/Blik-op-Nederland/ — bezoekers hebben geen
GitHub-account nodig. Eenmalig instellen: Settings > Pages > Source = GitHub
Actions. De workflow in `.github/workflows/publiceer.yml`
draait wekelijks, haalt nieuwe data op, bouwt het dashboard opnieuw en
publiceert het.

Een R-server (Shiny, Posit Connect) heb je pas nodig als bezoekers zelf
filters willen zetten waarvoor opnieuw gerekend moet worden. Dat is hier niet
het geval: alles staat al in de pagina. Mocht dat later toch nodig zijn, dan
zijn shinyapps.io of Posit Connect Cloud de eenvoudigste opties.

## Fase 2: rechtstreeks bij de bron

Nu draait alles op de dataset van de Rekenkamer. `R/90_bronnen.R` is het
werkbestand voor de volgende stap, met drie richtingen in volgorde van
prioriteit:

1. **Historie verlengen via CBS.** De meeste reeksen beginnen pas in 2020, met
   2012 en 2018 als losse punten. Met vijf metingen is een trendschatting
   zwak, en de dip van 2020-2021 domineert nu elk beeld terwijl dat corona is
   en geen beleid. CBS StatLine gaat voor veel indicatoren twintig jaar terug.
2. **Officiele ramingen.** Waar PBL (Klimaat- en Energieverkenning) of CPB
   (CEP, MEV, MLT) al een raming publiceert, hoort die de eigen doortrekking
   te vervangen. "Volgens PBL halen we dit niet" weegt zwaarder dan een
   regressielijn. De CPB-bijlagen bevatten bovendien lange historische reeksen.
3. **Internationale vergelijking.** Veel indicatoren komen uit Eurostat of
   OECD en zijn dus voor alle EU-landen beschikbaar. De positie van Nederland
   ten opzichte van het EU-gemiddelde zegt vaak meer dan de trend, en het is
   technisch het eenvoudigst: een API, geen interpretatievraagstuk.

Let bij alle drie op reeksbreuken en op de vraag of een externe reeks
werkelijk hetzelfde meet. Vergelijk altijd eerst de overlappende jaren met de
Rekenkamer-cijfers voordat je een bron activeert.

## Bron en licentie

De data komt uit *Blik op Nederland: Dashboard Doelen en Resultaten* van de
Algemene Rekenkamer, gepubliceerd onder CC0 1.0 Universal en daarmee vrij
herbruikbaar. Bewerking, interpretatie en presentatie in dit project zijn niet
van de Algemene Rekenkamer.
