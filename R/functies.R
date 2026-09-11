# ---------------------------------------------------------------------------
# functies.R — herbruikbare bouwstenen
# ---------------------------------------------------------------------------


# === Doelkolom ontleden ====================================================
# De kolom "Doel/Streefwaarde/Bedoeling" is vrije tekst. Er zitten drie soorten
# in: alleen een richting ("Hoe lager, hoe beter"), een streefwaarde met
# jaartal ("Doel 2030: 80%"), of een drempel zonder jaartal ("Minimaal 95%").
# Deze functies halen eruit wat er ondubbelzinnig in staat en laten de rest
# leeg; wat leeg blijft, vul je zelf in via het reviewbestand.

# Volgorde van de regels is bepalend: de eerste match wint. Ontkenningen en
# rangindicatoren staan bovenaan, omdat "niet hoger dan" anders als "hoger"
# wordt gelezen en een lagere ranglijstpositie juist beter is.
richting_regels <- list(
  c("niet hoger dan|max\\.|maximum",                                 "lager"),
  c("niet lager dan|minimaal|^\\s*>",                                "hoger"),
  c("lager getal|lagere rang|lager het cijfer|lager #|lager tekort", "lager"),
  c("hogere rang|hogere positie",                                    "hoger"),
  c("hoe minder|hoe lager|lager is beter|lagere|een lager|lager %",  "lager"),
  c("hoe hoger|hoger is beter|meer is beter|meer opgehelderd|hogere|hoger",
                                                                     "hoger")
)

parse_richting <- function(tekst) {
  vapply(tekst, function(t) {
    if (is.na(t)) return(NA_character_)
    t <- tolower(as.character(t))
    for (regel in richting_regels) {
      if (stringr::str_detect(t, regel[1])) return(regel[2])
    }
    NA_character_
  }, character(1), USE.NAMES = FALSE)
}

# Nederlandse notatie: punt is duizendtal, komma is decimaal.
nl_getal <- function(x) {
  suppressWarnings(as.numeric(gsub(",", ".", gsub("\\.", "", x))))
}

# Levert per tekst één streefwaarde en streefjaar. Staan er meerdere in
# ("Doel 2030: 50%; 2035: 74%"), dan wordt de eerste gebruikt en blijft de
# rest bewaard in `doel_meerdere`.
parse_streefwaarde <- function(tekst) {
  purrr::map_dfr(tekst, function(t) {
    leeg <- tibble::tibble(doel = NA_real_, doeljaar = NA_real_,
                           doel_meerdere = NA_character_)
    if (is.na(t)) return(leeg)

    kaal <- suppressWarnings(as.numeric(t))
    if (!is.na(kaal) && !stringr::str_detect(as.character(t), "[a-zA-Z]")) {
      return(tibble::tibble(doel = kaal, doeljaar = NA_real_,
                            doel_meerdere = NA_character_))
    }

    t <- as.character(t)
    getal <- "-?\\d{1,3}(?:\\.\\d{3})*(?:,\\d+)?"

    paren <- stringr::str_match_all(
      t, paste0("(20\\d{2})\\s*:\\s*(?:minimaal\\s*)?(", getal, ")"))[[1]]

    if (nrow(paren) > 0) {
      return(tibble::tibble(
        doel     = nl_getal(paren[1, 3]),
        doeljaar = as.numeric(paren[1, 2]),
        doel_meerdere = if (nrow(paren) > 1) {
          paste(paren[-1, 2], paren[-1, 3], sep = ": ", collapse = "; ")
        } else NA_character_
      ))
    }

    los <- stringr::str_match(t, paste0("(", getal, ")\\s*%"))
    if (!is.na(los[1, 2])) {
      return(tibble::tibble(doel = nl_getal(los[1, 2]), doeljaar = NA_real_,
                            doel_meerdere = NA_character_))
    }
    leeg
  })
}

# Eenheid heeft geen eigen kolom maar staat tussen haakjes in de naam:
# "EMU-saldo (€ mld)" -> "€ mld".
parse_eenheid <- function(indicator) {
  stringr::str_squish(stringr::str_match(indicator, "\\(([^()]{1,25})\\)\\s*$")[, 2])
}


# === Trend en projectie ====================================================
# De reeksen zijn kort: de meeste indicatoren hebben 2020-2025, sommige maar
# twee metingen. De trend is een grove richtingsschatting, geen model.

bereken_trend <- function(jaar, waarde,
                          n_jaren = instel$trend_jaren,
                          min_punten = instel$min_punten) {

  d <- data.frame(jaar = as.numeric(jaar), waarde = as.numeric(waarde))
  d <- d[!is.na(d$jaar) & !is.na(d$waarde), ]
  d <- d[order(d$jaar), ]
  d <- utils::tail(d, n_jaren)

  if (nrow(d) < min_punten || length(unique(d$jaar)) < 2) {
    return(list(helling = NA_real_, intercept = NA_real_,
                r2 = NA_real_, n = nrow(d)))
  }

  fit <- stats::lm(waarde ~ jaar, data = d)
  list(
    helling   = unname(stats::coef(fit)[2]),
    intercept = unname(stats::coef(fit)[1]),
    r2        = summary(fit)$r.squared,
    n         = nrow(d)
  )
}

projecteer <- function(trend, doeljaar) {
  if (is.na(trend$helling) || is.na(doeljaar)) return(NA_real_)
  trend$intercept + trend$helling * doeljaar
}


# === Status ================================================================
# richting: "hoger" = hogere waarde is beter, "lager" = lagere waarde is beter.

bepaal_status <- function(laatste, doel, projectie, richting,
                          marge = instel$marge_op_koers) {

  if (is.na(richting)) return("Geen richting")
  if (is.na(doel))     return("Alleen richting")
  if (is.na(laatste) || is.na(projectie)) return("Te weinig data")

  gehaald <- if (richting == "hoger") laatste >= doel else laatste <= doel
  if (gehaald) return("Doel gehaald")

  speling <- abs(doel) * marge
  haalt <- if (richting == "hoger") projectie >= doel - speling
           else                     projectie <= doel + speling
  if (haalt) return("Op koers")

  beweging   <- projectie - laatste
  goede_kant <- if (richting == "hoger") beweging > 0 else beweging < 0
  if (goede_kant) "Te traag" else "Verkeerde richting"
}

# Beschrijft de beweging in woorden en cijfers, als vervanging van een
# geextrapoleerd jaartal. `drempel` bepaalt wanneer een reeks als vlak geldt:
# standaard een half procent van de laatste waarde per jaar.
beschrijf_helling <- function(helling, laatste, eenheid = NA, drempel = 0.005) {
  if (is.na(helling) || is.na(laatste)) return(NA_character_)

  eenheid_tekst <- if (is.na(eenheid) || !nzchar(eenheid)) "" else paste0(" ", eenheid)
  omvang <- format(round(abs(helling), 2), decimal.mark = ",", trim = TRUE)

  if (abs(helling) < abs(laatste) * drempel) return("beweegt nauwelijks")

  paste0(if (helling > 0) "stijgt met " else "daalt met ",
         omvang, eenheid_tekst, " per jaar")
}

# Voor indicatoren zonder streefwaarde: beweegt hij de gewenste kant op?
beoordeel_beweging <- function(helling, richting) {
  if (is.na(helling) || is.na(richting)) return(NA_character_)
  goed <- if (richting == "hoger") helling > 0 else helling < 0
  if (goed) "Goede kant op" else "Verkeerde kant op"
}


# === Doelafstand ===========================================================

doelafstand <- function(start, laatste, doel) {
  if (any(is.na(c(start, laatste, doel)))) return(NA_real_)
  if (isTRUE(all.equal(start, doel))) return(NA_real_)
  (laatste - start) / (doel - start)
}


# === Grafiek ===============================================================

sparkline <- function(df_reeks, doel = NA, doeljaar = NA, doel_alt = NA,
                      trend = NULL, kleur = "#12263A") {

  p <- ggplot2::ggplot(df_reeks, ggplot2::aes(jaar, waarde))

  # Een reeks van één meting kan geen lijn vormen
  if (nrow(df_reeks) >= 2) {
    p <- p + ggplot2::geom_line(colour = kleur, linewidth = 0.7)
  }
  p <- p + ggplot2::geom_point(data = utils::tail(df_reeks, 1),
                               colour = kleur, size = 1.6)

  if (!is.na(doel)) {
    p <- p + ggplot2::geom_hline(yintercept = doel, colour = "#8A9199",
                                 linetype = "22", linewidth = 0.5)
  }

  # Tweede streefwaarde, bijvoorbeeld een nationaal doel naast een EU-doel:
  # dunner en lichter, zodat het hoofddoel de leidende lijn blijft
  if (!is.na(doel_alt)) {
    p <- p + ggplot2::geom_hline(yintercept = doel_alt, colour = "#B0B6BA",
                                 linetype = "12", linewidth = 0.4)
  }

  if (!is.null(trend) && !is.na(trend$helling) && !is.na(doeljaar)) {
    laatste_jaar <- max(df_reeks$jaar, na.rm = TRUE)
    lijn <- data.frame(jaar = c(laatste_jaar, doeljaar))
    lijn$waarde <- trend$intercept + trend$helling * lijn$jaar
    p <- p + ggplot2::geom_line(data = lijn, colour = kleur,
                                linetype = "11", linewidth = 0.5, alpha = 0.8)
  }

  p + ggplot2::theme_void() +
    ggplot2::theme(plot.margin = ggplot2::margin(2, 2, 2, 2))
}

thema_rk <- function(basis = 12) {
  ggplot2::theme_minimal(base_size = basis) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title    = ggplot2::element_text(face = "bold", size = basis * 1.15,
                                            colour = "#12263A"),
      plot.subtitle = ggplot2::element_text(colour = "#4A5A68", size = basis * 0.9),
      panel.grid.minor   = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(colour = "#E5E3DE", linewidth = 0.4),
      axis.title   = ggplot2::element_blank(),
      axis.text    = ggplot2::element_text(colour = "#5B666F"),
      plot.caption = ggplot2::element_text(colour = "#8A9199", hjust = 0)
    )
}
