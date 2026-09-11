# ---------------------------------------------------------------------------
# 03_figuren.R — losse figuren voor hergebruik buiten het dashboard
# Alles komt in output/graphs, als svg en png.
# ---------------------------------------------------------------------------

if (!exists("pad")) source(if (file.exists("R/00_config.R")) "R/00_config.R" else "../R/00_config.R")
if (!exists("thema_rk")) source(file.path(projectmap, "R", "functies.R"))

log_regel("Start 03_figuren")

df  <- readRDS(file.path(pad$interim, "indicatoren_lang.rds"))
sam <- readRDS(file.path(pad$interim, "samenvatting.rds"))

bewaar <- function(p, naam, breedte = 8.5, hoogte = 5) {
  bewaar_fig(p, naam, breedte = breedte, hoogte = hoogte)
}

# Reeksen met één meting kunnen geen lijn vormen; die tonen we als punt.
# Dat voorkomt de waarschuwing "each group consists of only one observation".
met_lijn <- function(d) {
  n <- dplyr::count(d, indicator, name = "n_")
  dplyr::semi_join(d, dplyr::filter(n, n_ >= 2), by = "indicator")
}


# --- 1. Meetbaarheid per thema --------------------------------------------
# De kernbevinding: bij hoeveel indicatoren is voortgang überhaupt te meten?

p_meetbaar <- sam |>
  dplyr::count(thema, status) |>
  ggplot2::ggplot(ggplot2::aes(n, reorder(thema, n), fill = status)) +
  ggplot2::geom_col(width = 0.68) +
  ggplot2::scale_fill_manual(values = status_kleur, drop = FALSE, name = NULL) +
  ggplot2::labs(
    title = "Bij hoeveel indicatoren is voortgang te meten?",
    subtitle = "Alleen indicatoren met een becijferde streefwaarde laten een oordeel toe",
    caption = "Bron: Algemene Rekenkamer, Blik op Nederland (CC0). Eigen bewerking."
  ) +
  thema_rk() +
  ggplot2::theme(legend.position = "bottom",
                 panel.grid.major.y = ggplot2::element_blank(),
                 panel.grid.major.x = ggplot2::element_line(
                   colour = "#E5E3DE", linewidth = 0.4))

bewaar(p_meetbaar, "meetbaarheid_per_thema", 9, 5.5)


# --- 2. Doelafstand --------------------------------------------------------

afst <- dplyr::filter(sam, !is.na(afstand))

if (nrow(afst) > 0) {
  p_afstand <- afst |>
    ggplot2::ggplot(ggplot2::aes(afstand, reorder(stringr::str_trunc(indicator, 55),
                                                  afstand), colour = status)) +
    ggplot2::geom_vline(xintercept = 1, colour = "#12263A", linewidth = 0.4) +
    ggplot2::geom_segment(ggplot2::aes(
      x = 0, xend = afstand,
      yend = reorder(stringr::str_trunc(indicator, 55), afstand)),
      linewidth = 0.5) +
    ggplot2::geom_point(size = 2.4) +
    ggplot2::scale_colour_manual(values = status_kleur, drop = FALSE, name = NULL) +
    ggplot2::scale_x_continuous(labels = scales::percent) +
    ggplot2::labs(
      title = "Hoeveel van de weg naar het doel is afgelegd?",
      subtitle = "Gemeten vanaf het begin van de reeks; de verticale lijn is de streefwaarde",
      caption = "Bron: Algemene Rekenkamer, Blik op Nederland (CC0). Eigen bewerking."
    ) +
    thema_rk() +
    ggplot2::theme(legend.position = "bottom")

  bewaar(p_afstand, "doelafstand", 9.5, max(4, 0.32 * nrow(afst)))
}


# --- 3. Eén figuur per thema ----------------------------------------------

for (th in unique(sam$thema)) {
  reeksen <- dplyr::filter(df, thema == th, jaar >= instel$plot_vanaf) |>
    dplyr::mutate(facetlabel = stringr::str_wrap(
      ifelse(herkomst == "CBS", paste0(indicator, "  [CBS]"), indicator), 42))
  deel    <- dplyr::filter(sam, thema == th) |>
    dplyr::mutate(facetlabel = stringr::str_wrap(
      ifelse(herkomst == "CBS", paste0(indicator, "  [CBS]"), indicator), 42))

  p <- ggplot2::ggplot(reeksen, ggplot2::aes(jaar, waarde)) +
    ggplot2::geom_hline(data = dplyr::filter(deel, !is.na(doel)),
                        ggplot2::aes(yintercept = doel),
                        colour = "#8A9199", linetype = "22", linewidth = 0.45) +
    ggplot2::geom_line(data = met_lijn(reeksen),
                       colour = "#12263A", linewidth = 0.8) +
    ggplot2::geom_point(colour = "#12263A", size = 1.2) +
    # Gedeelde x-as kan weer, omdat alle reeksen op instel$plot_vanaf beginnen
    ggplot2::facet_wrap(~ facetlabel, scales = "free_y", ncol = 3) +
    ggplot2::scale_x_continuous(breaks = scales::pretty_breaks(4)) +
    ggplot2::labs(title = th,
                  caption = paste0("Onderbroken lijn: streefwaarde. Bron: Algemene Rekenkamer (CC0)",
                                   if (any(deel$herkomst == "CBS")) "; reeksen met [CBS] uit CBS StatLine." else ".")) +
    thema_rk() +
    ggplot2::theme(strip.text = ggplot2::element_text(
      hjust = 0, size = 8.5, colour = "#12263A"))

  bewaar(p, paste0("thema_", janitor::make_clean_names(th)),
         9.5, max(3, 2.4 * ceiling(nrow(deel) / 3)))
}

log_regel("Figuren weggeschreven: ", length(list.files(pad$graphs)), " bestanden")
