# ---------------------------------------------------------------------------
# 01_inlezen.R — inlezen en normaliseren
#
# Bronstructuur (geverifieerd op het bestand van 2026-09-08):
#   Sheet1, 71 indicatoren in 10 thema's, breed formaat.
#   Na janitor::clean_names() en remove_empty() heten de kolommen:
#     thema                        alleen op de eerste rij van elke groep
#     indicator
#     x2012, x2018, x2020 ... x2025   jaarkolommen (2019 was leeg en vervalt)
#     bron
#     doel_streefwaarde_bedoeling  vrije tekst, geen getal
#     legitimatie                  waar het doel op berust
#     doel_coalitie                8 indicatoren
#     bedoeling_coalitie           28 indicatoren
#
# Doelschema: één rij per indicator-jaar, met de doelinformatie meegedragen.
# ---------------------------------------------------------------------------

if (!exists("pad")) source(if (file.exists("R/00_config.R")) "R/00_config.R" else "../R/00_config.R")
if (!exists("parse_richting")) source(file.path(projectmap, "R", "functies.R"))

log_regel("Start 01_inlezen")


# --- 1. Inlezen vanaf de site ----------------------------------------------
# De .ods wordt naar een tijdelijk bestand gehaald, ingelezen en daarna
# weggegooid. Het werkformaat van dit project is rds/csv, niet ods.

tijdelijk <- tempfile(fileext = ".ods")
on.exit(unlink(tijdelijk), add = TRUE)

log_regel("Dataset ophalen van rekenkamer.nl")
ok <- try(download.file(bron_url, tijdelijk, mode = "wb",
                        method = "libcurl", quiet = TRUE), silent = TRUE)

if (inherits(ok, "try-error") || !file.exists(tijdelijk) ||
    file.size(tijdelijk) < 1000) {
  log_waarschuwing("Download mislukt; laatst weggeschreven ruwe data wordt gebruikt")
  reserve <- file.path(pad$raw, "bronblad_ruw.rds")
  if (!file.exists(reserve)) {
    log_fout("Geen bron beschikbaar en geen eerdere kopie in ", pad$raw)
    stop("Kan de dataset niet ophalen. Controleer je internetverbinding.")
  }
  ruw <- readRDS(reserve)
} else {
  log_regel(sprintf("Opgehaald: %.1f KB", file.size(tijdelijk) / 1024))
  ruw <- readODS::read_ods(tijdelijk, sheet = 1, col_names = TRUE) |>
    janitor::remove_empty(c("rows", "cols")) |>
    janitor::clean_names()

  # Ruwe versie bewaren met datumstempel: zo bouw je een historie op en zie
  # je later wat er tussen updates veranderd is, ook bijgestelde doelen.
  saveRDS(ruw, file.path(pad$raw, "bronblad_ruw.rds"))
  saveRDS(ruw, file.path(pad$raw,
    sprintf("bronblad_ruw_%s.rds", format(Sys.Date(), "%Y%m%d"))))
  readr::write_csv2(ruw, file.path(pad$raw,
    sprintf("bronblad_ruw_%s.csv", format(Sys.Date(), "%Y%m%d"))), na = "")
}

log_regel(sprintf("Ruwe data: %d rijen x %d kolommen", nrow(ruw), ncol(ruw)))
log_regel("Kolommen: ", paste(names(ruw), collapse = ", "))


# --- 2. Kolommen -----------------------------------------------------------
# Namen zoals ze na clean_names heten.

kol_thema     <- "thema"
kol_indicator <- "indicator"
kol_bron      <- "bron"
kol_doel      <- "doel_streefwaarde_bedoeling"
kol_legit     <- "legitimatie"
kol_coal_doel <- "doel_coalitie"
kol_coal_bed  <- "bedoeling_coalitie"

ontbreekt <- setdiff(c(kol_thema, kol_indicator, kol_bron, kol_doel), names(ruw))
if (length(ontbreekt)) {
  log_fout("Verwachte kolommen ontbreken: ", paste(ontbreekt, collapse = ", "))
  print(names(ruw))
  stop("De bronstructuur is gewijzigd. Pas de kolomnamen aan in stap 2.")
}

# clean_names zet een x voor namen die met een cijfer beginnen: 2012 -> x2012
jaarkolommen <- names(ruw)[stringr::str_detect(names(ruw), "^x?(19|20)\\d{2}$")]
if (length(jaarkolommen) == 0) {
  log_fout("Geen jaarkolommen herkend")
  print(names(ruw))
  stop("Pas de regex voor jaarkolommen aan in stap 2.")
}
log_regel("Jaarkolommen: ", paste(jaarkolommen, collapse = ", "))


# --- 3. Indicatorniveau ----------------------------------------------------
# Thema staat alleen op de eerste rij van elke groep; die vullen we door.

indicatoren <- ruw
indicatoren[[kol_thema]] <- stringr::str_squish(indicatoren[[kol_thema]])
indicatoren <- tidyr::fill(indicatoren, dplyr::all_of(kol_thema), .direction = "down")
indicatoren <- dplyr::filter(indicatoren,
                             !is.na(.data[[kol_indicator]]),
                             stringr::str_squish(.data[[kol_indicator]]) != "")

doelinfo <- parse_streefwaarde(indicatoren[[kol_doel]])

meta <- tibble::tibble(
  thema        = indicatoren[[kol_thema]],
  indicator    = stringr::str_squish(indicatoren[[kol_indicator]]),
  eenheid      = parse_eenheid(indicatoren[[kol_indicator]]),
  bron         = indicatoren[[kol_bron]],
  doel_tekst   = as.character(indicatoren[[kol_doel]]),
  legitimatie  = if (kol_legit %in% names(indicatoren)) indicatoren[[kol_legit]] else NA,
  coalitiedoel = if (kol_coal_doel %in% names(indicatoren)) indicatoren[[kol_coal_doel]] else NA,
  coalitiebedoeling = if (kol_coal_bed %in% names(indicatoren)) indicatoren[[kol_coal_bed]] else NA
) |>
  dplyr::bind_cols(doelinfo) |>
  dplyr::mutate(
    richting = parse_richting(doel_tekst),
    # Hardheid van het doel: waar berust het op?
    doelsoort = dplyr::case_when(
      stringr::str_detect(tolower(legitimatie), "wet|verdrag|grondwet") ~ "Wet of verdrag",
      stringr::str_detect(tolower(legitimatie), "europ|eu |navo|oeso|oecd") ~ "Internationale afspraak",
      stringr::str_detect(tolower(legitimatie), "akkoord|norm|agenda|beleid") ~ "Beleidsafspraak",
      is.na(legitimatie) ~ NA_character_,
      TRUE ~ "Overig"
    ),
    heeft_coalitiedoel = !is.na(coalitiedoel)
  )

log_regel(sprintf("%d indicatoren in %d thema's", nrow(meta),
                  dplyr::n_distinct(meta$thema)))
log_regel(sprintf("Richting automatisch bepaald voor %d van %d indicatoren",
                  sum(!is.na(meta$richting)), nrow(meta)))
log_regel(sprintf("Streefwaarde gevonden voor %d indicatoren",
                  sum(!is.na(meta$doel))))


# --- 4. Reviewbestand ------------------------------------------------------
# Wat de parser niet uit de vrije tekst kan halen, vul je hier eenmalig aan.
# De kolommen richting_handmatig / doel_handmatig / doeljaar_handmatig
# overschrijven altijd de automatische waarde.

review_pad <- file.path(pad$clean, "doelen_review.csv")

if (!file.exists(review_pad)) {
  meta |>
    dplyr::transmute(
      thema, indicator, doel_tekst,
      richting_auto = richting, doel_auto = doel, doeljaar_auto = doeljaar,
      richting_handmatig = NA_character_,
      doel_handmatig = NA_real_,
      doeljaar_handmatig = NA_real_,
      opmerking = NA_character_
    ) |>
    readr::write_csv2(review_pad, na = "")
  log_waarschuwing("Reviewbestand aangemaakt: ", review_pad,
                   " — vul de ontbrekende richtingen en streefwaarden aan.")
}

review <- readr::read_csv2(review_pad, show_col_types = FALSE)

# Oudere reviewbestanden hebben de alt-kolommen nog niet
for (k in c("doel_alt", "doel_alt_label")) {
  if (!k %in% names(review)) review[[k]] <- NA
}

meta <- meta |>
  dplyr::left_join(
    dplyr::select(review, indicator, richting_handmatig,
                  doel_handmatig, doeljaar_handmatig,
                  doel_alt, doel_alt_label),
    by = "indicator"
  ) |>
  dplyr::mutate(
    richting = dplyr::coalesce(as.character(richting_handmatig), richting),
    doel     = dplyr::coalesce(as.numeric(doel_handmatig), doel),
    doeljaar = dplyr::coalesce(as.numeric(doeljaar_handmatig), doeljaar),
    doel_alt = as.numeric(doel_alt),
    doel_alt_label = as.character(doel_alt_label)
  ) |>
  dplyr::select(-richting_handmatig, -doel_handmatig, -doeljaar_handmatig)

log_regel(sprintf("Na review: richting bekend voor %d, streefwaarde voor %d",
                  sum(!is.na(meta$richting)), sum(!is.na(meta$doel))))


# --- 5. Naar lang formaat --------------------------------------------------

lang <- indicatoren |>
  dplyr::mutate(indicator = stringr::str_squish(.data[[kol_indicator]])) |>
  dplyr::select(indicator, dplyr::all_of(jaarkolommen)) |>
  tidyr::pivot_longer(dplyr::all_of(jaarkolommen),
                      names_to = "jaar", values_to = "waarde") |>
  dplyr::mutate(
    jaar   = as.numeric(stringr::str_extract(jaar, "\\d{4}")),
    waarde = suppressWarnings(as.numeric(waarde))
  ) |>
  dplyr::filter(!is.na(waarde)) |>
  dplyr::left_join(meta, by = "indicator") |>
  dplyr::arrange(thema, indicator, jaar)

# Waarschuwen bij dubbele indicatornamen: die zouden de join vervuilen
dubbel <- meta$indicator[duplicated(meta$indicator)]
if (length(dubbel)) {
  log_waarschuwing("Dubbele indicatornamen: ", paste(dubbel, collapse = " | "))
}


# --- 6. CBS-historie koppelen ----------------------------------------------
# Besluit B1 (zie LOGBOEK.md): waar een CBS-reeks bestaat, is die leidend.
# CBS-cijfers zijn actueler en worden herzien; de Rekenkamer neemt ze zelf ook
# van CBS over. De Rekenkamer-waarden blijven bewaard in `waarde_rk`, zodat het
# verschil later na te gaan is.
#
# Draai R/04_cbs_historie.R om historie_cbs.rds te maken of te verversen.

historie_pad <- file.path(pad$interim, "historie_cbs.rds")

if (file.exists(historie_pad)) {

  cbs <- readRDS(historie_pad) |>
    dplyr::select(indicator, jaar, waarde_cbs = waarde, bron_cbs = bron)

  # Alleen indicatoren die ook in de Rekenkamer-data zitten
  cbs <- dplyr::semi_join(cbs, dplyr::distinct(lang, indicator), by = "indicator")

  gekoppeld <- unique(cbs$indicator)

  if (length(gekoppeld) == 0) {
    log_waarschuwing("historie_cbs.rds bevat geen indicatoren uit deze dataset")
  } else {

    # De metagegevens (thema, doel, richting) hangen aan de indicator, niet aan
    # het jaar; die halen we uit de bestaande rijen.
    meta_per_ind <- lang |>
      dplyr::filter(indicator %in% gekoppeld) |>
      dplyr::select(-jaar, -waarde) |>
      dplyr::distinct(indicator, .keep_all = TRUE)

    # Volledige CBS-reeks, aangevuld met de Rekenkamer-waarde per jaar zodat
    # het verschil zichtbaar blijft
    rk_waarden <- lang |>
      dplyr::filter(indicator %in% gekoppeld) |>
      dplyr::select(indicator, jaar, waarde_rk = waarde)

    vervangen <- cbs |>
      dplyr::left_join(meta_per_ind, by = "indicator") |>
      dplyr::left_join(rk_waarden, by = c("indicator", "jaar")) |>
      dplyr::mutate(
        waarde = waarde_cbs,
        bron   = bron_cbs,
        herkomst = "CBS"
      ) |>
      dplyr::select(-waarde_cbs, -bron_cbs)

    behouden <- lang |>
      dplyr::filter(!indicator %in% gekoppeld) |>
      dplyr::mutate(waarde_rk = waarde, herkomst = "Rekenkamer")

    n_voor <- nrow(lang)
    lang <- dplyr::bind_rows(vervangen, behouden) |>
      dplyr::arrange(thema, indicator, jaar)

    log_regel(sprintf("CBS-historie gekoppeld voor %d indicatoren: %d -> %d waarnemingen",
                      length(gekoppeld), n_voor, nrow(lang)))

    for (ind in gekoppeld) {
      r <- dplyr::filter(vervangen, indicator == ind)
      afw <- sum(!is.na(r$waarde_rk) & abs(r$waarde - r$waarde_rk) > 0.001)
      log_regel(sprintf("  %s: %d-%d (%d jaren), %d jaar afwijkend van de Rekenkamer",
                        ind, min(r$jaar), max(r$jaar), nrow(r), afw))
    }
  }

} else {
  lang$waarde_rk <- lang$waarde
  lang$herkomst  <- "Rekenkamer"
  log_regel("Geen historie_cbs.rds gevonden; alleen Rekenkamer-data gebruikt. ",
            "Draai R/04_cbs_historie.R om CBS-reeksen op te halen.")
}


# --- 7. Wegschrijven -------------------------------------------------------

saveRDS(lang, file.path(pad$interim, "indicatoren_lang.rds"))
saveRDS(meta, file.path(pad$interim, "indicatoren_meta.rds"))
readr::write_csv2(lang, file.path(pad$clean, "indicatoren_lang.csv"))
readr::write_csv2(meta, file.path(pad$clean, "indicatoren_meta.csv"))

metingen <- lang |> dplyr::count(indicator, name = "n")
log_regel(sprintf("Lang formaat: %d waarnemingen, mediaan %d metingen per indicator",
                  nrow(lang), stats::median(metingen$n)))
log_regel(sprintf("Indicatoren met minder dan %d metingen: %d",
                  instel$min_punten, sum(metingen$n < instel$min_punten)))
log_regel("Klaar 01_inlezen")
