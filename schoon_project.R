# ---------------------------------------------------------------------------
# schoon_project.R — bewaart alleen de opgegeven bestanden/mappen,
# verwijdert de rest van de projectmap (inclusief .git en .Rproj.user).
#
# Draai dit vanuit de projectmap zelf: setwd() ernaartoe, dan source().
# ---------------------------------------------------------------------------

bewaren <- c(
  "R",
  "docs/dashboard.qmd",
  "docs/rekenkamer.scss",
  "data/raw",
  "data/clean/doelen_review.csv",
  "data/clean/ramingen.csv",
  "run_all.R",
  "05_publiceren.R",
  ".gitignore",
  "LOGBOEK.md",
  "README.md",
  ".github/workflows/publiceer.yml",
  "Rekenkamer.Rproj",
  "schoon_project.R"   # dit script zelf
)

alles <- list.files(".", all.files = TRUE, recursive = FALSE, no.. = TRUE)

is_bewaard <- function(pad) {
  any(vapply(bewaren, function(b) pad == b || startsWith(pad, paste0(b, "/")), logical(1)))
}

# Alle bestanden/mappen op het hoogste niveau die niet (deels) bewaard blijven
te_verwijderen <- alles[!vapply(alles, function(a) {
  a %in% bewaren || any(startsWith(bewaren, paste0(a, "/"))) || is_bewaard(a)
}, logical(1))]

cat("Wordt verwijderd:\n")
cat(paste(" -", te_verwijderen), sep = "\n")
cat("\nWordt bewaard:\n")
cat(paste(" -", bewaren), sep = "\n")

antwoord <- readline("\nDoorgaan? (ja/nee): ")
if (!tolower(trimws(antwoord)) %in% c("ja", "j")) stop("Afgebroken.")

for (item in te_verwijderen) unlink(item, recursive = TRUE, force = TRUE)

# Binnen data/ en docs/ ook de niet-bewaarde deelbestanden opruimen
if (dir.exists("data/clean")) {
  for (f in list.files("data/clean", full.names = TRUE)) {
    if (!basename(f) %in% c("doelen_review.csv", "ramingen.csv")) unlink(f)
  }
}
if (dir.exists("data/interim")) unlink("data/interim", recursive = TRUE)
if (dir.exists("docs")) {
  for (f in list.files("docs", full.names = TRUE)) {
    if (!basename(f) %in% c("dashboard.qmd", "rekenkamer.scss")) {
      unlink(f, recursive = TRUE, force = TRUE)
    }
  }
}
if (dir.exists("output")) unlink("output", recursive = TRUE)

cat("\nKlaar. Resterende inhoud:\n")
print(list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE))
