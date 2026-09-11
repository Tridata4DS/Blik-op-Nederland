# ---------------------------------------------------------------------------
# 00_config.R — paden, packages, logging en instellingen
#
# Alle paden worden absoluut gemaakt vanaf de projectmap. Open Rekenkamer.Rproj,
# dan staat de werkmap automatisch goed en hoef je hier niets aan te passen.
# ---------------------------------------------------------------------------

## Packages -----------------------------------------------------------------

# svglite en ragg maken svg/png zonder cairo of XQuartz. Op macOS zonder
# XQuartz faalt het standaard svg-device met "libXrender.1.dylib not found";
# daarom worden alle figuren via deze twee weggeschreven.
pkgs <- c("readODS", "dplyr", "tidyr", "purrr", "stringr", "readr",
          "janitor", "tibble", "ggplot2", "scales", "glue", "knitr",
          "svglite", "ragg")

laad_packages <- function(x = pkgs) {
  mist <- x[!(x %in% rownames(installed.packages()))]
  if (length(mist)) install.packages(mist, quiet = TRUE)
  invisible(lapply(x, library, character.only = TRUE))
}
laad_packages()


## Paden --------------------------------------------------------------------

# De projectmap wordt gevonden door vanaf de werkmap omhoog te lopen tot het
# ankerbestand Rekenkamer.Rproj gevonden is. Geen vaste paden en geen aanname
# over de werkmap: dit werkt vanuit de projectmap, vanuit docs/ (waar Quarto
# rendert) en vanuit elke andere submap.
vind_projectmap <- function(start = getwd(), anker = "Rekenkamer.Rproj",
                            max_niveaus = 6) {
  huidig <- normalizePath(start, mustWork = FALSE)
  for (i in seq_len(max_niveaus)) {
    if (file.exists(file.path(huidig, anker))) return(huidig)
    ouder <- dirname(huidig)
    if (ouder == huidig) break          # bij de wortel aangekomen
    huidig <- ouder
  }
  NULL
}

# Altijd opnieuw bepalen. Een `projectmap` die nog in de sessie hangt van een
# eerder project zou anders stilzwijgend worden hergebruikt, waardoor scripts
# naar de verkeerde map schrijven.
projectmap <- vind_projectmap()

if (is.null(projectmap)) {
  stop("Projectmap niet gevonden: geen Rekenkamer.Rproj aangetroffen vanaf ",
       getwd(), " of hoger.\n",
       "Open Rekenkamer.Rproj in RStudio, of zet de werkmap met setwd() ",
       "naar de projectmap.")
}

pad <- list(
  raw     = "data/raw",       # ingelezen brondata, per datum bewaard
  interim = "data/interim",   # tussenresultaten (.rds)
  clean   = "data/clean",     # analyseklare tabellen (.csv)
  R       = "R",              # scripts
  graphs  = "output/graphs",  # losse figuren
  tables  = "output/tables",  # geëxporteerde tabellen
  docs    = "docs",           # dashboard en vormgeving
  logs    = "logs"            # draailogboek
)
pad <- lapply(pad, function(p) file.path(projectmap, p))
invisible(lapply(pad, dir.create, recursive = TRUE, showWarnings = FALSE))


## Logging ------------------------------------------------------------------

log_bestand <- file.path(pad$logs, format(Sys.Date(), "run_%Y%m%d.log"))

log_regel <- function(..., niveau = "INFO") {
  regel <- sprintf("%s [%s] %s",
                   format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                   niveau, paste0(...))
  cat(regel, "\n", sep = "", file = log_bestand, append = TRUE)
  message(regel)
  invisible(regel)
}

log_waarschuwing <- function(...) log_regel(..., niveau = "WAARSCHUWING")
log_fout        <- function(...) log_regel(..., niveau = "FOUT")


## Versie -------------------------------------------------------------------
# Verschijnt bovenaan elke run. Zie je hier een oudere datum dan verwacht,
# dan draai je nog op oude scriptbestanden.

scripts_versie <- "2026-09-08f"


## Bron ---------------------------------------------------------------------

bron_url <- paste0(
  "https://www.rekenkamer.nl/site/binaries/site-content/collections/documents/",
  "2026/05/20/dataset-blik-op-nederland-dashboard-doelen-en-resultaten/",
  "dataset-blik-op-nederland.ods"
)


## Analyse-instellingen -----------------------------------------------------

# De bron bevat 2012, 2018 en 2020-2025; de mediane indicator heeft
# 5 metingen en 15 indicatoren hebben er minder dan 3. De trend is daarom
# een grove richtingsschatting, geen prognose.
instel <- list(
  trend_jaren        = 10,    # alle beschikbare jaren meenemen
  min_punten         = 3,     # minimaal aantal metingen voor een trend
  marge_op_koers     = 0.05,  # projectie mag 5% van het doel afwijken
  standaard_doeljaar = 2030,
  # Grafieken tonen alleen dit venster. De volledige CBS-historie blijft in de
  # data en telt mee voor de trend, maar in beeld gemengde reekslengtes geven
  # een rommelig resultaat. Zie LOGBOEK.md.
  plot_vanaf         = 2020
)


## Statuskleuren ------------------------------------------------------------

# Slechts een deel van de indicatoren heeft een becijferde streefwaarde.
# De statusschaal maakt dat zichtbaar in plaats van het te verbergen.
status_kleur <- c(
  "Doel gehaald"       = "#1B6B5A",
  "Op koers"           = "#3E8E7E",
  "Te traag"           = "#C99A2E",
  "Verkeerde richting" = "#A3352B",
  "Alleen richting"    = "#7C8A94",  # wel een gewenste richting, geen getal
  "Geen richting"      = "#B0B6BA",  # bron zegt niet wat beter is
  "Te weinig data"     = "#C6C9CC"
)
status_volgorde <- names(status_kleur)


## Figuren wegschrijven -----------------------------------------------------
# Eén ingang voor alle figuren, zodat het device op één plek geregeld is.

bewaar_fig <- function(plot, naam, map = pad$graphs,
                       breedte = 8.5, hoogte = 5, ook_png = TRUE) {
  dir.create(map, recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(file.path(map, paste0(naam, ".svg")), plot,
                  width = breedte, height = hoogte,
                  device = svglite::svglite)
  if (ook_png) {
    ggplot2::ggsave(file.path(map, paste0(naam, ".png")), plot,
                    width = breedte, height = hoogte, dpi = 300,
                    device = ragg::agg_png, bg = "#FAF9F6")
  }
  invisible(file.path(map, paste0(naam, ".svg")))
}
