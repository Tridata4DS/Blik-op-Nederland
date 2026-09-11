# ---------------------------------------------------------------------------
# 02_indicatoren.R — per indicator: trend, projectie, doelafstand en status
#
# Let op de verhouding in deze bron: van de 71 indicatoren heeft ongeveer een
# derde een becijferde streefwaarde. Voor de rest staat er alleen een gewenste
# richting, of zelfs dat niet. Dit script beoordeelt daarom op twee niveaus:
#   - met streefwaarde: haalt de trend het doel? (status)
#   - zonder streefwaarde: beweegt hij de gewenste kant op? (beweging)
# ---------------------------------------------------------------------------

if (!exists("pad")) source(if (file.exists("R/00_config.R")) "R/00_config.R" else "../R/00_config.R")
if (!exists("bereken_trend")) source(file.path(projectmap, "R", "functies.R"))

log_regel("Start 02_indicatoren")

df <- readRDS(file.path(pad$interim, "indicatoren_lang.rds"))

# Officiële ramingen, indien beschikbaar. Waar die bestaan, vervangen ze onze
# eigen doortrekking als eindpunt van het bekende traject (B11).
ram_pad <- file.path(pad$interim, "ramingen.rds")
ramingen <- if (file.exists(ram_pad)) readRDS(ram_pad) else NULL


samenvatting <- df |>
  dplyr::group_by(thema, indicator) |>
  dplyr::group_modify(function(d, key) {

    d <- dplyr::arrange(d, jaar)
    trend <- bereken_trend(d$jaar, d$waarde)

    eerste <- function(x) {
      x <- stats::na.omit(x)
      if (length(x) == 0) NA else x[1]
    }

    doel     <- as.numeric(eerste(d$doel))
    doeljaar <- as.numeric(eerste(d$doeljaar))
    richting <- as.character(eerste(d$richting))
    if (is.na(doeljaar) && !is.na(doel)) doeljaar <- instel$standaard_doeljaar

    proj    <- projecteer(trend, doeljaar)
    laatste <- dplyr::last(d$waarde)
    start   <- dplyr::first(d$waarde)

    # Bestaat er een officiële raming voor deze indicator? Dan is die
    # gezaghebbender dan onze regressielijn. We nemen het laatste
    # ramingsjaar als eindpunt van het bekende traject.
    ram <- if (!is.null(ramingen)) {
      dplyr::filter(ramingen, indicator == key$indicator)
    } else NULL

    heeft_raming  <- !is.null(ram) && nrow(ram) > 0
    raming_jaar   <- if (heeft_raming) max(ram$jaar) else NA_real_
    raming_waarde <- if (heeft_raming) ram$waarde[which.max(ram$jaar)] else NA_real_
    raming_bron   <- if (heeft_raming) paste(unique(ram$bron), unique(ram$publicatie)) else NA_character_

    tibble::tibble(
      eerste_jaar    = min(d$jaar),
      laatste_jaar   = max(d$jaar),
      n_metingen     = nrow(d),
      startwaarde    = start,
      laatste_waarde = laatste,
      eenheid        = as.character(eerste(d$eenheid)),
      bron           = as.character(eerste(d$bron)),
      herkomst       = as.character(eerste(d$herkomst)),
      doel_tekst     = as.character(eerste(d$doel_tekst)),
      legitimatie    = as.character(eerste(d$legitimatie)),
      doelsoort      = as.character(eerste(d$doelsoort)),
      coalitiedoel   = as.character(eerste(d$coalitiedoel)),
      doel           = doel,
      doeljaar       = doeljaar,
      heeft_raming   = heeft_raming,
      raming_jaar    = raming_jaar,
      raming_waarde  = raming_waarde,
      raming_bron    = raming_bron,
      doel_alt       = as.numeric(eerste(d$doel_alt)),
      doel_alt_label = as.character(eerste(d$doel_alt_label)),
      richting       = richting,
      helling        = trend$helling,
      r2             = trend$r2,
      projectie      = proj,
      afstand        = doelafstand(start, laatste, doel),
      gat            = if (is.na(doel)) NA_real_ else doel - laatste,
      gat_projectie  = if (is.na(doel) || is.na(proj)) NA_real_ else doel - proj,
      # Reikt de raming tot het doeljaar, dan oordelen we daarop in plaats
      # van op onze eigen projectie.
      status         = if (heeft_raming && !is.na(doeljaar) &&
                           !is.na(raming_jaar) && raming_jaar >= doeljaar) {
                         bepaal_status(laatste, doel, raming_waarde, richting)
                       } else {
                         bepaal_status(laatste, doel, proj, richting)
                       },
      beweging       = beoordeel_beweging(trend$helling, richting),
      # Verandering over de hele reeks, voor indicatoren zonder streefwaarde
      verandering    = laatste - start,
      verandering_pct = if (isTRUE(start != 0)) (laatste - start) / abs(start) else NA_real_
    )
  }) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    status = factor(status, levels = status_volgorde),
    # BEWUST GEEN "doel bereikt in <jaar>". Dat cijfer is (doel - laatste) /
    # helling, en bij een vrijwel vlakke reeks nadert de helling nul, waardoor
    # de uitkomst explodeert: ontwikkelingssamenwerking kwam zo op 2165 uit.
    # Dat getal is een artefact van bijna delen door nul en suggereert een
    # precisie die er niet is. De helling zelf zegt hetzelfde, eerlijker.
    # Zie LOGBOEK.md, besluit B10.
    heeft_streefwaarde = !is.na(doel)
  ) |>
  dplyr::arrange(thema, indicator)


# --- Themascore ------------------------------------------------------------
# Twee maten naast elkaar: hoeveel indicatoren per thema hebben überhaupt een
# becijferd doel, en hoeveel daarvan liggen op koers.

thema_score <- samenvatting |>
  dplyr::group_by(thema) |>
  dplyr::summarise(
    n_indicatoren   = dplyr::n(),
    n_streefwaarde  = sum(heeft_streefwaarde),
    n_op_koers      = sum(status %in% c("Doel gehaald", "Op koers")),
    n_goede_kant    = sum(beweging == "Goede kant op", na.rm = TRUE),
    aandeel_meetbaar = n_streefwaarde / n_indicatoren,
    .groups = "drop"
  ) |>
  dplyr::arrange(dplyr::desc(aandeel_meetbaar))


# --- Wegschrijven ----------------------------------------------------------

saveRDS(samenvatting, file.path(pad$interim, "samenvatting.rds"))
readr::write_csv2(samenvatting, file.path(pad$clean, "indicatoren_status.csv"))
readr::write_csv2(thema_score,  file.path(pad$clean, "thema_score.csv"))

samenvatting |>
  dplyr::transmute(
    Thema = thema, Indicator = indicator,
    Periode = paste0(eerste_jaar, "-", laatste_jaar),
    Metingen = n_metingen,
    Laatste = round(laatste_waarde, 2), Eenheid = eenheid,
    # doel_tekst is meestal gewone tekst uit de bron ("Minimaal 95%",
    # "Maximum 2026: 18.000") en die laten we ongemoeid. Alleen bij een paar
    # indicatoren is de brontekst zelf een kaal getal (bv. "0.007"), en door
    # een drijvendekommaonnauwkeurigheid schrijft R dat soms weg als
    # wetenschappelijke notatie ("7.0000000000000001E-3"). Dat repareren we
    # gericht: alleen als er een E-notatie in staat, niet de hele tekst.
    `Doel (tekst)` = dplyr::if_else(
      grepl("[0-9][eE][-+]?[0-9]+", doel_tekst),
      format(as.numeric(doel_tekst), scientific = FALSE, trim = TRUE) |>
        gsub("\\.", ",", x = _),
      doel_tekst
    ),
    Streefwaarde = round(doel, 2), Doeljaar = doeljaar,
    `Verwacht in doeljaar` = round(projectie, 2),
    `Verandering per jaar` = round(helling, 3),
    Status = status, Beweging = beweging,
    Legitimatie = legitimatie, Bron = bron, Herkomst = herkomst
  ) |>
  readr::write_csv2(file.path(pad$tables, "indicatoren_overzicht.csv"), na = "")

verdeling <- table(samenvatting$status)
log_regel("Statusverdeling: ",
          paste(names(verdeling), verdeling, sep = "=", collapse = ", "))
log_regel(sprintf("Met becijferde streefwaarde: %d van %d indicatoren",
                  sum(samenvatting$heeft_streefwaarde), nrow(samenvatting)))
log_regel("Klaar 02_indicatoren")
