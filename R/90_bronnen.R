# ---------------------------------------------------------------------------
# 90_bronnen.R — verkenning van aanvullende bronnen
#
# Dit script draait NIET mee in run_all.R. Het is een werkbestand voor de
# volgende fase, waarin we drie dingen willen toevoegen aan de Rekenkamer-data:
#
#   1. Historie verlengen   - de meeste reeksen beginnen pas in 2020
#   2. Officiele ramingen   - PBL (KEV) en CPB (CEP, MEV, MLT) waar die bestaan
#   3. Internationale vergelijking - Eurostat en OECD
#
# Volgorde is bewust: zonder langere historie is elke trendschatting zwak.
# ---------------------------------------------------------------------------

if (!exists("pad")) source(if (file.exists("R/00_config.R")) "R/00_config.R" else "../R/00_config.R")


# === 1. CBS StatLine =======================================================
# install.packages("cbsodataR")
#
# Zoeken naar een tabel:
#   cbsodataR::cbs_search("R&D uitgaven")
#   cbsodataR::cbs_get_meta("84906NED")   # welke dimensies heeft de tabel?
#
# Werkwijze per indicator: eerst de tabel vinden, dan de juiste dimensie
# selecteren, dan controleren of de recente jaren overeenkomen met de
# Rekenkamer-cijfers. Wijken ze af, dan meet de tabel iets anders.

haal_cbs <- function(tabel_id, indicator_naam, waardekolom,
                     eenheid = NA, filters = list()) {
  stopifnot(requireNamespace("cbsodataR", quietly = TRUE))

  ruw <- cbsodataR::cbs_get_data(tabel_id) |>
    cbsodataR::cbs_add_date_column()

  d <- ruw |> dplyr::filter(Perioden_freq == "Y")

  for (kol in names(filters)) {
    d <- d[trimws(d[[kol]]) %in% filters[[kol]], ]
  }

  d |>
    dplyr::transmute(
      indicator = indicator_naam,
      jaar      = as.integer(format(Perioden_Date, "%Y")),
      waarde    = as.numeric(.data[[waardekolom]]),
      eenheid   = eenheid,
      bron      = paste0("CBS StatLine ", tabel_id)
    ) |>
    dplyr::filter(!is.na(waarde)) |>
    dplyr::arrange(jaar)
}


# === 2. Eurostat ===========================================================
# install.packages("eurostat")
#
# Levert meteen de EU-vergelijking, wat het Rekenkamer-dashboard niet biedt.
# Zoeken:  eurostat::search_eurostat("R&D expenditure")
#
# Kandidaten om mee te beginnen (te verifieren voor gebruik):
#   rd_e_gerdtot   bruto binnenlandse R&D-uitgaven, % bbp
#   nrg_ind_ren    aandeel hernieuwbare energie
#   ilc_li02       armoederisico
#   sdg_13_10      broeikasgasemissies

haal_eurostat <- function(dataset_id, indicator_naam,
                          landen = c("NL", "EU27_2020"),
                          filters = list()) {
  stopifnot(requireNamespace("eurostat", quietly = TRUE))

  d <- eurostat::get_eurostat(dataset_id, time_format = "num") |>
    dplyr::filter(geo %in% landen)

  for (kol in names(filters)) {
    d <- d[d[[kol]] %in% filters[[kol]], ]
  }

  d |>
    dplyr::transmute(
      indicator = indicator_naam,
      land      = geo,
      jaar      = as.integer(TIME_PERIOD),
      waarde    = values,
      bron      = paste0("Eurostat ", dataset_id)
    ) |>
    dplyr::filter(!is.na(waarde))
}

# Positie van Nederland binnen de EU: rang en afstand tot het gemiddelde.
# Dit is het cijfer dat vaak meer zegt dan de trend.
positie_nl <- function(d_eurostat, jaar_selectie = NULL, hoger_is_beter = TRUE) {
  d <- d_eurostat |> dplyr::filter(!land %in% c("EU27_2020", "EA20"))
  if (is.null(jaar_selectie)) jaar_selectie <- max(d$jaar, na.rm = TRUE)

  d |>
    dplyr::filter(jaar == jaar_selectie) |>
    dplyr::mutate(
      rang = if (hoger_is_beter) dplyr::min_rank(dplyr::desc(waarde))
             else                dplyr::min_rank(waarde),
      n_landen = dplyr::n(),
      gemiddelde = mean(waarde, na.rm = TRUE),
      afstand_gemiddelde = waarde - gemiddelde
    ) |>
    dplyr::filter(land == "NL")
}


# === 3. OECD ===============================================================
# De OECD SDMX-API levert csv; geen extra package nodig. Relevant voor PISA,
# PIAAC en de bredere R&D-vergelijking.

haal_oecd <- function(sdmx_url, indicator_naam) {
  readr::read_csv(sdmx_url, show_col_types = FALSE) |>
    dplyr::transmute(
      indicator = indicator_naam,
      land      = REF_AREA,
      jaar      = as.integer(TIME_PERIOD),
      waarde    = as.numeric(OBS_VALUE),
      bron      = "OECD"
    )
}


# === 4. Ramingen ===========================================================
# Deze komen niet uit een API maar uit publicaties. Ze moeten met de hand
# ingevoerd worden in een apart bestand, met bronvermelding per cijfer.
#
#   PBL, Klimaat- en Energieverkenning (KEV)
#     - broeikasgasemissies, hernieuwbare energie, stikstof
#     - geeft een bandbreedte en zegt expliciet of doelen binnen bereik zijn
#     - let op: rekent vastgesteld beleid door, niet voorgenomen beleid
#
#   CPB, Centraal Economisch Plan (CEP) en Macro Economische Verkenning (MEV)
#     - bbp-groei, werkloosheid, EMU-saldo, EMU-schuld, armoede
#     - de bijlagen bevatten ook lange reeksen terug in de tijd
#
#   CPB, middellangetermijnverkenning (MLT): vier jaar vooruit
#
# Schema voor het ramingenbestand (data/clean/ramingen.csv):
#   indicator; jaar; waarde; ondergrens; bovengrens; bron; publicatie; datum
#
# In het dashboard moeten drie soorten lijn visueel te onderscheiden zijn:
#   gerealiseerd | officiele raming met bandbreedte | eigen doortrekking
# En het statusoordeel moet vermelden waarop het berust: "volgens PBL" weegt
# zwaarder dan "volgens onze regressielijn".


# === 5. Bronregister =======================================================
# Vul deze tabel geleidelijk. Zolang `actief` FALSE is, blijft de
# Rekenkamer-dataset leidend voor die indicator.

bronregister <- tibble::tribble(
  ~indicator,                          ~methode,   ~argument,        ~doel,          ~actief,
  "R en D uitgaven (% BBP)",           "cbs",      "te zoeken",      "historie",     FALSE,
  "R en D uitgaven (% BBP)",           "eurostat", "rd_e_gerdtot",   "vergelijking", FALSE,
  "Broeikasgasemissies (CO2-eq. Mton)","pbl",      "KEV",            "raming",       FALSE,
  "BBP reele groei",                   "cpb",      "CEP",            "raming",       FALSE
)

# Werkwijze bij het activeren van een bron:
#   1. Haal de reeks op en vergelijk de overlappende jaren met de
#      Rekenkamer-cijfers. Wijken die af, dan meet je iets anders.
#   2. Controleer op reeksbreuken (bij armoede staat er al een in de naam:
#      "nieuwe CBS-SCP-Nibud-methode"). Markeer die, strijk ze niet glad.
#   3. Zet pas dan `actief` op TRUE.
