# ---------------------------------------------------------------------------
# run_all.R — de hele keten in één keer
#
# Open Rekenkamer.Rproj en draai:  source("run_all.R")
# ---------------------------------------------------------------------------

source("R/00_config.R")
source("R/functies.R")

log_regel("=== Start volledige run (scriptversie ", scripts_versie, ") ===")
log_regel("Projectmap: ", projectmap)
start_tijd <- Sys.time()

# 04_cbs_historie.R draait vóór 01, want 01 koppelt de opgehaalde reeksen.
# Het wordt overgeslagen als cbsodataR ontbreekt of de verversing mislukt;
# 01 valt dan terug op de laatst weggeschreven historie_cbs.rds.
stappen <- c(
  "R/04_cbs_historie.R",
  "R/01_inlezen.R",
  "R/02_indicatoren.R",
  "R/03_figuren.R"
)

# Alleen 01 t/m 03 zijn verplicht; een mislukte CBS-verversing mag de run niet
# tegenhouden.
optioneel <- "R/04_cbs_historie.R"

for (s in stappen) {
  uitkomst <- try(source(s), silent = TRUE)
  if (inherits(uitkomst, "try-error")) {
    melding <- conditionMessage(attr(uitkomst, "condition"))
    if (s %in% optioneel) {
      log_waarschuwing(s, " overgeslagen: ", melding)
      next
    }
    log_fout(s, " afgebroken: ", melding)
    stop("Run gestopt bij ", s, ". Zie ", log_bestand)
  }
}

# Dashboard renderen
if (nzchar(Sys.which("quarto"))) {
  code <- system2("quarto", c("render", "docs/dashboard.qmd"))
  if (code == 0) {
    log_regel("Dashboard klaar: docs/dashboard.html")
  } else {
    log_waarschuwing("Quarto render gaf foutcode ", code)
  }
} else {
  log_waarschuwing("Quarto niet gevonden. Installeer via quarto.org, ",
                   "of render docs/dashboard.qmd vanuit RStudio.")
}

duur <- round(difftime(Sys.time(), start_tijd, units = "secs"))
log_regel("=== Run klaar in ", duur, " seconden ===")
