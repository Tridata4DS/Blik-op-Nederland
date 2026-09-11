# ---------------------------------------------------------------------------
# 06_ramingen.R — officiële ramingen inlezen
#
# WAAROM. Waar het CPB of PBL een raming publiceert, hoort die onze eigen
# doortrekking te vervangen. Een regressielijn door zes punten naast een raming
# van een heel modelapparaat zetten wekt de indruk dat er geen betere
# informatie bestaat. Onze extrapolatie is bedoeld voor indicatoren waar
# niemand een raming maakt - PISA-scores, discriminatie, criminaliteit.
#
# Zie LOGBOEK.md, besluit B11.
#
# VINTAGES. Er zijn drie CPB-publicaties in omloop uit 2026: het CEP en de
# MLT van 12 maart, en de cMEV van 14 augustus. Regel: voor 2026 en 2027 de
# cMEV (nieuwst), voor 2030 en 2034 de MLT, want alleen die reikt zo ver.
# Gevolg: de MLT-cijfers rusten op een basispad dat inmiddels is bijgesteld.
# De MLT zag de EMU-schuld in 2027 op 45,3, de cMEV op 46,5. Dat verschil
# staat in LOGBOEK.md en de leeswijzer, niet in het dashboard zelf - het zou
# daar meer verwarring geven dan inzicht.
#
# LABELWIJZIGING. Het CPB heeft de kerngegevenstabel in augustus 2026
# hernoemd; de toelichting heet dan ook "vanaf augustus 2026". Tot en met het
# CEP van maart heette de uitgavenregel "bruto collectieve uitgaven", daarna
# "totale overheidsuitgaven". Dat is dezelfde grootheid, niet alleen omdat
# 46,0 (maart) en 46,3 (augustus) een gewone revisie zijn, maar vooral omdat
# de boekhoudkundige identiteit klopt: in de cMEV geldt 43,5 - 46,3 = -2,8,
# precies het EMU-saldo. Pas je die identiteit toe op maart, dan hoort bij
# saldo -2,6 en uitgaven 46,0 een inkomstenniveau van 43,4 - wat aansluit op
# de 43,5 uit de cMEV. "Bruto" onderscheidt van een nettovariant waarin
# niet-belastingontvangsten zijn afgetrokken, niet van een andere afbakening.
# Aan de inkomstenkant is wel een echte conceptwijziging doorgevoerd:
# "collectieve lasten" (39,0) telt alleen belastingen en premies en is dus
# iets anders dan "totale overheidsinkomsten" (43,5). Die regel gebruiken wij
# niet.
#
# BRON. Ramingen komen uit publicaties, niet uit een API. Ze staan met de hand
# in data/clean/ramingen.csv, met per cijfer de publicatie en de datum. Zo
# blijft controleerbaar waar een getal vandaan komt en wanneer het achterhaald
# raakt.
#
# DEFINITIES GECONTROLEERD (09-09-2026) tegen de CPB-toelichting:
#   https://www.cpb.nl/toelichting-bij-kerngegevenstabel-vanaf-november-2019
#
# Alle acht overgenomen indicatoren sluiten aan op de Rekenkamer-definitie.
# De belangrijkste bevestigingen:
#   - EMU-saldo en EMU-schuld gaan over de collectieve sector, die het CPB
#     gelijkstelt aan de institutionele sector overheid uit de Nationale
#     rekeningen. Dat is dezelfde afbakening als CBS-tabel 84118NED met
#     selectie "Overheid", die wij al gebruiken voor de historie.
#   - Werkloosheid: 15-75 jaar, zonder betaald werk, recent gezocht en direct
#     beschikbaar - letterlijk de omschrijving in de indicatornaam van de
#     Rekenkamer.
#   - Armoede en kinderarmoede: het CPB raamt vanaf het CEP 2025 volgens de
#     nieuwe CBS-SCP-Nibud-definitie, dezelfde die de Rekenkamer in de
#     indicatornaam noemt. Het CPB rekent daarbij met de alternatieve cpi.
#   - Armoede-intensiteit: procentueel verschil tussen besteedbaar
#     huishoudinkomen en armoedegrens, mediaan over de groep in armoede.
#     Het CPB raamt deze pas vanaf de MEV 2026, dus de reeks is kort.
#
# LET OP. Een raming is beleidsafhankelijk. Het CPB rekent vastgesteld en
# voorgenomen beleid door tot en met het lopende jaar plus een of twee; de
# Klimaat- en Energieverkenning van het PBL rekent alleen vastgesteld beleid
# door. Dat verschil hoort benoemd te worden, anders vergelijk je appels met
# peren.
# ---------------------------------------------------------------------------

if (!exists("pad")) source(if (file.exists("R/00_config.R")) "R/00_config.R" else "../R/00_config.R")

log_regel("Start 06_ramingen")

ramingen_pad <- file.path(pad$clean, "ramingen.csv")

if (!file.exists(ramingen_pad)) {
  log_waarschuwing("Geen ramingen.csv gevonden; stap overgeslagen.")
} else {

  ramingen <- readr::read_csv2(ramingen_pad, show_col_types = FALSE) |>
    dplyr::mutate(
      jaar   = as.integer(jaar),
      waarde = as.numeric(waarde)
    ) |>
    dplyr::filter(!is.na(jaar), !is.na(waarde))

  # Controle: sluiten de namen aan op de Rekenkamer-indicatoren? Een typefout
  # in de indicatornaam zou de raming stilzwijgend laten verdwijnen.
  rk_pad <- file.path(pad$interim, "indicatoren_lang.rds")
  if (file.exists(rk_pad)) {
    bekend <- unique(readRDS(rk_pad)$indicator)
    onbekend <- setdiff(unique(ramingen$indicator), bekend)
    if (length(onbekend)) {
      log_waarschuwing("Ramingen voor onbekende indicatoren (naam klopt niet ",
                       "exact): ", paste(onbekend, collapse = " | "))
    }
  }

  saveRDS(ramingen, file.path(pad$interim, "ramingen.rds"))

  overzicht <- ramingen |>
    dplyr::group_by(indicator, bron, publicatie) |>
    dplyr::summarise(van = min(jaar), tot = max(jaar), n = dplyr::n(),
                     .groups = "drop")

  log_regel(sprintf("%d ramingen voor %d indicatoren uit %s",
                    nrow(ramingen), dplyr::n_distinct(ramingen$indicator),
                    paste(unique(ramingen$publicatie), collapse = ", ")))

  for (i in seq_len(nrow(overzicht))) {
    r <- overzicht[i, ]
    log_regel(sprintf("  %s: %d-%d (%s, %s)",
                      substr(r$indicator, 1, 45), r$van, r$tot,
                      r$bron, r$publicatie))
  }
}

log_regel("Klaar 06_ramingen")


# ---------------------------------------------------------------------------
# NOG TOE TE VOEGEN
#
# PBL, Klimaat- en Energieverkenning: broeikasgassen, hernieuwbare energie,
# stikstof. Geeft een bandbreedte, die hoort in ramingen.csv als extra
# kolommen ondergrens en bovengrens.
#
# CPB, middellangetermijnverkenning: kijkt vier jaar vooruit en reikt daarmee
# dichter bij de doeljaren van 2030 dan de cMEV.
# ---------------------------------------------------------------------------
