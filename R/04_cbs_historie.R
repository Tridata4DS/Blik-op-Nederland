# ---------------------------------------------------------------------------
# 04_cbs_historie.R — reeksen verlengen met CBS StatLine
#
# De Rekenkamer-dataset begint voor de meeste indicatoren pas in 2020. Met vijf
# metingen is een trend een lijn door ruis, en de coronadip van 2020-2021
# domineert elk beeld. CBS StatLine gaat voor veel indicatoren decennia terug.
#
# WERKWIJZE (zie ook README): een CBS-reeks vervangt pas een Rekenkamer-reeks
# als de overlappende jaren overeenkomen. Wijken ze af, dan meet de tabel iets
# anders en gaat de koppeling niet door. Dit script controleert dat en stopt
# niets stilzwijgend weg.
#
# Draait NIET mee in run_all.R zolang er geen bron op actief staat.
# ---------------------------------------------------------------------------

if (!exists("pad")) source(if (file.exists("R/00_config.R")) "R/00_config.R" else "../R/00_config.R")
if (!exists("bereken_trend")) source(file.path(projectmap, "R", "functies.R"))

if (!requireNamespace("cbsodataR", quietly = TRUE)) {
  install.packages("cbsodataR")
}

log_regel("Start 04_cbs_historie")


# === Register ==============================================================
# Per indicator: welke tabel, welke maatstaf, welke selectie op de dimensies.
# `naam_rk` moet exact overeenkomen met de indicatornaam in de Rekenkamer-data.

cbs_register <- tibble::tribble(
  ~naam_rk,                  ~tabel,     ~kolom,           ~selectie,                                  ~eenheid,
  # 84118NED, jaarcijfers vanaf 1995. Let op: de tabel heeft de schuld zowel
  # in mln euro (SchuldEMU_4) als in % bbp (SchuldEMU_13); wij willen % bbp.
  # De dimensie heet InstitutioneleSectoren, met "Overheid" als totaal.
  "EMU-schuld (% BBP)",      "84118NED", "SchuldEMU_13",   list(InstitutioneleSectoren = "Overheid"),     "% bbp",
  "EMU-saldo (% BBP)",       "84118NED", "Saldo_12",       list(InstitutioneleSectoren = "Overheid"),     "% bbp",

  # 84644NED, vanaf 2013 (bewuste ondergrens, zie toelichting onderaan).
  # Dimensie Sectoren, totaal heet "Alle sectoren".
  "R en D uitgaven (% BBP)", "84644NED", "RDIntensiteit_4", list(Sectoren = "Alle sectoren"),             "% bbp"
)


# === Hulpfuncties ==========================================================

# Toont welke dimensies en categorieën een tabel heeft. Gebruik dit als een
# selectie niet werkt: de exacte labels verschillen per tabel.
verken_tabel <- function(tabel_id) {
  meta <- cbsodataR::cbs_get_meta(tabel_id)
  cat("\n=== ", tabel_id, ": ", meta$TableInfos$Title, " ===\n", sep = "")
  cat("Periode: ", meta$TableInfos$Period, "\n\n", sep = "")

  cat("-- Meetbare kolommen --\n")
  print(meta$DataProperties[meta$DataProperties$Type == "Topic",
                            c("Key", "Title", "Unit")], row.names = FALSE)

  dims <- meta$DataProperties$Key[meta$DataProperties$Type == "Dimension"]
  for (d in dims) {
    cat("\n-- Dimensie: ", d, " --\n", sep = "")
    if (!is.null(meta[[d]])) print(utils::head(meta[[d]][, c("Key", "Title")], 20),
                                   row.names = FALSE)
  }
  invisible(meta)
}

# Haalt één jaarreeks op uit een StatLine-tabel.
haal_cbs_reeks <- function(tabel_id, kolom, selectie = list(), eenheid = NA) {

  ruw <- cbsodataR::cbs_get_data(tabel_id) |>
    cbsodataR::cbs_add_date_column() |>
    cbsodataR::cbs_add_label_columns()

  d <- ruw
  # Alleen jaarcijfers; kwartaal- en maandcijfers vallen af
  if ("Perioden_freq" %in% names(d)) d <- d[d$Perioden_freq == "Y", ]

  for (dim in names(selectie)) {
    labelkolom <- paste0(dim, "_label")
    kol <- if (labelkolom %in% names(d)) labelkolom else dim
    if (!kol %in% names(d)) {
      stop("Dimensie '", dim, "' bestaat niet in ", tabel_id,
           ". Draai verken_tabel(\"", tabel_id, "\") om de namen te zien.")
    }
    beschikbaar <- unique(trimws(as.character(d[[kol]])))
    d <- d[trimws(as.character(d[[kol]])) %in% selectie[[dim]], ]

    if (nrow(d) == 0) {
      stop("Selectie '", paste(selectie[[dim]], collapse = ", "),
           "' levert niets op voor dimensie '", dim, "' in ", tabel_id,
           ".\nBeschikbaar: ", paste(utils::head(beschikbaar, 15), collapse = " | "))
    }
  }

  if (!kolom %in% names(d)) {
    stop("Kolom '", kolom, "' bestaat niet in ", tabel_id,
         ". Draai verken_tabel(\"", tabel_id, "\").")
  }

  tibble::tibble(
    jaar    = as.integer(format(d$Perioden_Date, "%Y")),
    waarde  = as.numeric(d[[kolom]]),
    eenheid = eenheid,
    bron    = paste0("CBS StatLine ", tabel_id)
  ) |>
    dplyr::filter(!is.na(waarde)) |>
    dplyr::distinct(jaar, .keep_all = TRUE) |>
    dplyr::arrange(jaar)
}

# Vergelijkt de overlappende jaren met de Rekenkamer-reeks. Dit is de
# beslissende controle: meet de CBS-tabel hetzelfde?
# tolerantie in eenheden van de reeks. Voor percentages van het bbp is 0,15 te
# streng: CBS herziet voorlopige jaren routinematig met enkele tienden. Zie
# LOGBOEK.md, openstaand punt O1.
vergelijk <- function(cbs, rk, tolerantie = 0.5) {
  samen <- dplyr::inner_join(
    dplyr::select(cbs, jaar, cbs = waarde),
    dplyr::select(rk,  jaar, rk  = waarde),
    by = "jaar"
  ) |>
    dplyr::mutate(verschil = cbs - rk,
                  afwijkend = abs(verschil) > tolerantie)

  list(
    n_overlap  = nrow(samen),
    n_afwijkend = sum(samen$afwijkend),
    max_verschil = if (nrow(samen)) max(abs(samen$verschil)) else NA_real_,
    detail = samen
  )
}


# === Uitvoeren =============================================================

# Dit script draait vóór 01_inlezen.R, dus bij een allereerste run bestaat de
# Rekenkamer-data nog niet. De reeksen worden dan wel opgehaald, alleen de
# vergelijking wordt overgeslagen; de volgende run doet die alsnog.
rk_pad <- file.path(pad$interim, "indicatoren_lang.rds")
kan_vergelijken <- file.exists(rk_pad)
rk <- if (kan_vergelijken) readRDS(rk_pad) else NULL

if (!kan_vergelijken) {
  log_waarschuwing("Nog geen Rekenkamer-data om tegen te vergelijken; ",
                   "reeksen worden wel opgehaald.")
}

resultaten <- list()
rapport    <- list()

for (i in seq_len(nrow(cbs_register))) {
  r <- cbs_register[i, ]
  log_regel("Ophalen: ", r$naam_rk, " uit ", r$tabel)

  reeks <- try(haal_cbs_reeks(r$tabel, r$kolom, r$selectie[[1]], r$eenheid),
               silent = TRUE)

  if (inherits(reeks, "try-error")) {
    log_waarschuwing(r$naam_rk, " mislukt: ",
                     conditionMessage(attr(reeks, "condition")))
    next
  }

  if (kan_vergelijken) {
    eigen <- dplyr::filter(rk, indicator == r$naam_rk)

    if (nrow(eigen) == 0) {
      log_waarschuwing("Indicator niet gevonden in Rekenkamer-data: ", r$naam_rk)
    } else {
      v <- vergelijk(reeks, eigen)

      log_regel(sprintf("  CBS %d-%d (%d jaren) | overlap %d jaren, %d afwijkend, max %.2f",
                        min(reeks$jaar), max(reeks$jaar), nrow(reeks),
                        v$n_overlap, v$n_afwijkend, v$max_verschil))

      if (v$n_afwijkend > 0) {
        log_waarschuwing("  Afwijking groter dan de tolerantie. Controleer of de ",
                         "tabel hetzelfde meet voordat je hierop vertrouwt.")
        print(dplyr::filter(v$detail, afwijkend))
      }
      rapport[[r$naam_rk]] <- dplyr::mutate(v$detail, indicator = r$naam_rk)
    }
  } else {
    log_regel(sprintf("  CBS %d-%d (%d jaren), niet vergeleken",
                      min(reeks$jaar), max(reeks$jaar), nrow(reeks)))
  }

  resultaten[[r$naam_rk]] <- dplyr::mutate(reeks, indicator = r$naam_rk)
}


# === Wegschrijven ==========================================================

if (length(resultaten)) {
  historie <- dplyr::bind_rows(resultaten)
  saveRDS(historie, file.path(pad$interim, "historie_cbs.rds"))
  readr::write_csv2(historie, file.path(pad$clean, "historie_cbs.csv"))

  if (length(rapport)) {
    readr::write_csv2(dplyr::bind_rows(rapport),
                      file.path(pad$tables, "cbs_vergelijking.csv"))
  }

  log_regel(sprintf("Weggeschreven: %d indicatoren, %d waarnemingen",
                    dplyr::n_distinct(historie$indicator), nrow(historie)))
} else {
  log_waarschuwing("Niets opgehaald.")
}

log_regel("Klaar 04_cbs_historie")


# === Bij problemen =========================================================
# De kolomnamen en dimensielabels in `cbs_register` zijn gebaseerd op de
# tabelbeschrijvingen, niet op een uitgevoerde aanroep. Klopt er iets niet,
# draai dan:
#
#   verken_tabel("84118NED")
#   verken_tabel("84644NED")
#
# en pas het register aan. De foutmeldingen hierboven verwijzen daar ook naar.
#
# Bekende aandachtspunten:
#   84118NED  jaarcijfers vanaf 1995, kwartaalcijfers vanaf 1999 (die filteren
#             we eruit). Dimensie InstitutioneleSectoren; "Overheid" is het
#             totaal, de subsectoren (Rijk, gemeenten, provincies, sociale
#             fondsen) staan daarnaast apart in dezelfde tabel.
#   84644NED  begint pas in 2013, en dat is hier de bewuste ondergrens. CBS
#             bracht de R&D-statistiek in 2019 in lijn met de Frascati-
#             handleiding, met terugwerkende kracht tot 2013. De oudere reeks
#             is niet vergelijkbaar en wordt niet gekoppeld.
