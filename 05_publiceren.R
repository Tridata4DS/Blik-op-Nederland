# ===========================================================================
# 05_publiceren.R — alle Git- en GitHub-stappen op één plek
#
#   Repository : https://github.com/Tridata4DS/Blik-op-Nederland
#   Live site  : https://tridata4ds.github.io/Blik-op-Nederland/
#
# ---------------------------------------------------------------------------
# HOE GEBRUIK JE DIT SCRIPT
# ---------------------------------------------------------------------------
#
#   source("05_publiceren.R")   laadt de functies hieronder
#
#   publiceer()          de normale gang van zaken: bouwen, committen,
#                        pullen, pushen. Dit is wat je bijna altijd doet.
#
#   git_status()         wat is er gewijzigd, en loopt het gelijk met GitHub?
#   git_eerste_keer()    eenmalige inrichting van een nieuwe machine of repo
#   git_identiteit()     naam en e-mail instellen (eenmalig per machine)
#   git_los()            als je vastloopt: uitleg per foutmelding
#
# ---------------------------------------------------------------------------
# WAAROM DEZE VOLGORDE
# ---------------------------------------------------------------------------
#
#   1. lokaal bouwen en controleren
#   2. commit — vastleggen wat jij hebt veranderd
#   3. pull   — halen wat elders is gewijzigd
#   4. push   — naar GitHub sturen
#   5. de Action bouwt opnieuw en publiceert
#
# Eerst lokaal, omdat een mislukte run hier tien seconden kost en op de runner
# vijf minuten, met minder leesbare foutmeldingen.
#
# Commit vóór pull, omdat rebase weigert zolang er ongecommitte wijzigingen
# zijn: "cannot pull with rebase: You have unstaged changes".
#
# Pull vóór push, omdat de wekelijkse Action verse brondata terugcommit naar
# GitHub. Staat daar iets wat jij niet hebt, dan weigert Git je push met
# "Updates were rejected because the remote contains work that you do not have
# locally". Dat is ons twee keer overkomen: één keer lokaal en één keer binnen
# de workflow zelf.
#
# ===========================================================================

if (!exists("pad")) {
  source(if (file.exists("R/00_config.R")) "R/00_config.R" else "../R/00_config.R")
}

repo_naam <- "Tridata4DS/Blik-op-Nederland"
repo_url  <- paste0("https://github.com/", repo_naam)
site_url  <- "https://tridata4ds.github.io/Blik-op-Nederland/"


# ===========================================================================
# Hulpfuncties
# ===========================================================================

# Voert een git-commando uit en vangt de uitvoer op, in plaats van die naar de
# console te laten weglopen. Zo kunnen we op het resultaat reageren.
git <- function(..., toon = TRUE) {
  uit <- suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = TRUE))
  code <- attr(uit, "status")
  if (toon && length(uit)) cat(paste(uit, collapse = "\n"), "\n")
  invisible(list(uit = uit, ok = is.null(code) || code == 0))
}

# Zet de werkmap op de projectmap en zet hem daarna terug. Zonder dit werken de
# git-commando's op de verkeerde map als je vanuit docs/ of R/ draait.
in_projectmap <- function(expr) {
  oud <- getwd()
  on.exit(setwd(oud), add = TRUE)
  setwd(projectmap)
  force(expr)
}

# Controleert of alles klaarstaat: git aanwezig, repo aangemaakt, koppeling
# met GitHub gelegd.
controleer_opzet <- function() {
  if (!nzchar(Sys.which("git"))) {
    stop("git niet gevonden. Draai in de Terminal: xcode-select --install")
  }
  if (!dir.exists(file.path(projectmap, ".git"))) {
    stop("Deze map is nog geen Git-repository. Draai eerst git_eerste_keer().")
  }
  if (!any(grepl("origin", in_projectmap(git("remote", toon = FALSE))$uit))) {
    stop("Geen koppeling met GitHub. Draai eerst git_eerste_keer().")
  }
  invisible(TRUE)
}


# ===========================================================================
# git_identiteit() — eenmalig per machine
# ===========================================================================
# Git zet onder elke commit wie hem maakte. Zonder instelling verzint Git iets
# op basis van je gebruikersnaam en hostnaam ("Ali <ali@MacBook-Air.local>") en
# waarschuwt daarover bij elke commit. Gebruik het e-mailadres van je
# GitHub-account, dan koppelt GitHub de commits aan je profiel.

git_identiteit <- function(naam = NULL, email = NULL) {
  huidig_n <- in_projectmap(git("config", "--global", "user.name",  toon = FALSE))
  huidig_e <- in_projectmap(git("config", "--global", "user.email", toon = FALSE))

  cat("Huidige instelling:\n")
  cat("  naam : ", if (length(huidig_n$uit)) huidig_n$uit else "(niet ingesteld)", "\n")
  cat("  email: ", if (length(huidig_e$uit)) huidig_e$uit else "(niet ingesteld)", "\n")

  if (is.null(naam) || is.null(email)) {
    cat("\nInstellen met:\n")
    cat('  git_identiteit("Ali Aouragh", "jouw@email.nl")\n')
    return(invisible(NULL))
  }

  in_projectmap({
    git("config", "--global", "user.name",  shQuote(naam))
    git("config", "--global", "user.email", shQuote(email))
  })
  cat("\nIngesteld. Geldt voor al je repositories op deze machine.\n")
}


# ===========================================================================
# git_eerste_keer() — eenmalige inrichting
# ===========================================================================
# Alleen nodig bij een nieuwe machine of een nieuw project. Doet vier dingen:
# repository aanmaken, koppelen aan GitHub, eerste commit, eerste push.
#
# Vooraf: maak de repository aan op github.com. Openbaar, en zonder README of
# .gitignore - die heb je al, en anders krijg je meteen een conflict.

git_eerste_keer <- function(url = paste0(repo_url, ".git")) {

  if (!nzchar(Sys.which("git"))) {
    stop("git niet gevonden. Draai in de Terminal: xcode-select --install")
  }

  in_projectmap({

    # 1. Repository aanmaken. Maakt een verborgen map .git aan; aan je
    #    bestanden verandert niets. De -b main zorgt dat de hoofdtak "main"
    #    heet, wat GitHub verwacht.
    if (!dir.exists(".git")) {
      cat("== Repository aanmaken ==\n")
      git("init", "-b", "main")
    } else {
      cat("Repository bestaat al.\n")
    }

    # 2. Koppelen aan GitHub
    if (!any(grepl("origin", git("remote", toon = FALSE)$uit))) {
      cat("\n== Koppelen aan GitHub ==\n")
      git("remote", "add", "origin", url)
    } else {
      cat("Koppeling bestaat al: ")
      git("remote", "get-url", "origin")
    }

    # 3. Eerste commit
    status <- git("status", "--short", toon = FALSE)$uit
    if (length(status)) {
      cat("\n== Eerste commit ==\n")
      git("add", ".")
      git("commit", "-m", shQuote("Eerste versie"))
    }

    # 4. Eerste push. De -u koppelt je lokale main aan die op GitHub, zodat je
    #    daarna kunt volstaan met `git push`.
    cat("\n== Eerste push ==\n")
    cat("GitHub vraagt om inloggen. Je gewone wachtwoord werkt niet meer:\n")
    cat("gebruik een Personal Access Token. Aanmaken via github.com >\n")
    cat("Settings > Developer settings > Personal access tokens >\n")
    cat("Tokens (classic) > Generate new token, met scope 'repo'.\n")
    cat("macOS bewaart hem daarna in de keychain.\n\n")
    git("push", "-u", "origin", "main")
  })

  cat("\n", strrep("-", 66), "\n", sep = "")
  cat("Laatste stap, in de browser:\n")
  cat("  ", repo_url, "/settings/pages\n", sep = "")
  cat("  Zet Source op 'GitHub Actions'.\n\n")
  cat("Zonder die instelling bouwt de Action wel, maar faalt het publiceren\n")
  cat("met een 404 en de melding 'Ensure GitHub Pages has been enabled'.\n")
  cat(strrep("-", 66), "\n")
}


# ===========================================================================
# git_status() — waar sta ik?
# ===========================================================================

git_status <- function() {
  controleer_opzet()

  in_projectmap({
    cat("== Lokaal gewijzigd ==\n")
    status <- git("status", "--short", toon = FALSE)$uit
    if (length(status)) {
      cat(paste(" ", status, collapse = "\n"), "\n")
    } else {
      cat("  niets\n")
    }

    # Haalt de stand op GitHub op zonder iets te wijzigen
    git("fetch", "origin", "main", toon = FALSE)

    voor   <- git("rev-list", "--count", "origin/main..main", toon = FALSE)$uit
    achter <- git("rev-list", "--count", "main..origin/main", toon = FALSE)$uit

    cat("\n== Ten opzichte van GitHub ==\n")
    cat("  ", voor,   " commit(s) klaar om te pushen\n", sep = "")
    cat("  ", achter, " commit(s) op te halen\n", sep = "")

    cat("\n== Laatste commits ==\n")
    git("log", "--oneline", "-5")
  })

  cat("\nSite: ", site_url, "\n", sep = "")
  invisible(NULL)
}


# ===========================================================================
# publiceer() — de normale gang van zaken
# ===========================================================================

publiceer <- function(melding = "Dashboard bijgewerkt",
                      opnieuw_bouwen = TRUE) {

  controleer_opzet()

  # -- 1. Lokaal bouwen ----------------------------------------------------
  # Alles wat hier misgaat, gaat op de runner ook mis. Beter hier ontdekken.

  if (opnieuw_bouwen) {
    cat("\n== 1. Keten lokaal draaien ==\n")
    uitkomst <- try(in_projectmap(source("run_all.R")), silent = TRUE)
    if (inherits(uitkomst, "try-error")) {
      stop("run_all.R is mislukt; niet publiceren.\n",
           conditionMessage(attr(uitkomst, "condition")))
    }
  }

  dashboard <- file.path(projectmap, "docs", "dashboard.html")
  if (!file.exists(dashboard)) {
    stop("docs/dashboard.html bestaat niet. Draai eerst run_all.R.")
  }

  leeftijd <- as.numeric(difftime(Sys.time(), file.mtime(dashboard),
                                  units = "mins"))
  cat(sprintf("\nDashboard: %.0f KB, %.0f minuten oud\n",
              file.size(dashboard) / 1024, leeftijd))
  if (leeftijd > 60 && !opnieuw_bouwen) {
    cat("LET OP: ouder dan een uur. Bevat het wel de huidige data?\n")
  }

  klaar <- FALSE

  in_projectmap({

    # -- 2. Commit ---------------------------------------------------------
    # Eerst vastleggen, want rebase weigert bij ongecommitte wijzigingen.

    status <- git("status", "--short", toon = FALSE)$uit

    if (length(status)) {
      cat("\n== 2. Wijzigingen vastleggen ==\n")
      cat(paste(" ", utils::head(status, 20), collapse = "\n"), "\n")
      if (length(status) > 20) cat("  ... en", length(status) - 20, "meer\n")

      git("add", ".")
      volledig <- paste0(melding, " (", format(Sys.Date(), "%Y-%m-%d"), ")")
      if (!git("commit", "-m", shQuote(volledig))$ok) {
        stop("Commit mislukt; zie de melding hierboven.")
      }
    } else {
      cat("\n== 2. Niets gewijzigd sinds de vorige commit ==\n")
    }

    # -- 3. Pull -----------------------------------------------------------
    # De wekelijkse Action commit verse brondata terug naar GitHub. Zonder
    # deze stap weigert Git de push.
    #
    # --rebase zet jouw commits bovenop wat er stond, in plaats van een
    # merge-commit te maken. Dat houdt de geschiedenis leesbaar.

    cat("\n== 3. Pull ==\n")
    if (!git("pull", "--rebase", "origin", "main")$ok) {
      stop("Pull mislukt. Meestal een conflict: twee kanten wijzigden\n",
           "hetzelfde bestand. Draai git_los() voor uitleg.")
    }

    # -- 4. Push -----------------------------------------------------------

    te_pushen <- git("rev-list", "--count", "origin/main..main",
                     toon = FALSE)$uit

    if (identical(te_pushen, "0")) {
      cat("\n== 4. Niets te pushen; GitHub is al bij ==\n")
      cat("\nSite: ", site_url, "\n", sep = "")
      klaar <<- TRUE
    } else {
      cat("\n== 4. Push (", te_pushen, " commit(s)) ==\n", sep = "")
      if (!git("push", "origin", "main")$ok) {
        stop("Push mislukt. Draai git_los() voor uitleg.")
      }
    }
  })

  if (klaar) return(invisible(NULL))

  # -- 5. Publiceren -------------------------------------------------------
  # Vanaf hier doet GitHub het werk: de Action installeert R en Quarto, draait
  # run_all.R en zet docs/ op Pages.

  cat("\n", strrep("-", 66), "\n", sep = "")
  cat("Gepusht. De Action bouwt nu; reken op 3 tot 8 minuten.\n\n")
  cat("Voortgang : ", repo_url, "/actions\n", sep = "")
  cat("Site      : ", site_url, "\n", sep = "")
  cat(strrep("-", 66), "\n")

  if (interactive()) {
    antw <- readline("Actions openen in de browser? (ja/nee): ")
    if (tolower(trimws(antw)) %in% c("ja", "j", "yes", "y")) {
      utils::browseURL(paste0(repo_url, "/actions"))
    }
  }
  invisible(NULL)
}


# ===========================================================================
# git_los() — vastgelopen?
# ===========================================================================
# Elke foutmelding die we tegenkwamen, met de oorzaak en de oplossing.

git_los <- function() {
  cat("
FOUTMELDINGEN EN WAT ZE BETEKENEN
=================================

'cannot pull with rebase: You have unstaged changes'
  Je hebt wijzigingen die nog niet zijn vastgelegd. Git wil eerst weten wat
  je daarmee wilt.
      git add .
      git commit -m 'beschrijving'
      git pull --rebase origin main

'Updates were rejected because the remote contains work that you do not
have locally'  /  '! [rejected] main -> main (fetch first)'
  Op GitHub staat iets nieuwers, meestal de brondata die de wekelijkse
  Action heeft teruggecommit.
      git pull --rebase origin main
      git push origin main

'Everything up-to-date'
  Geen fout. Je push was al geslaagd, of er viel niets te pushen.

'Authentication failed' bij het pushen
  Je gewone wachtwoord werkt niet meer. Maak een Personal Access Token aan
  via github.com > Settings > Developer settings > Personal access tokens >
  Tokens (classic), met scope 'repo'. Plak die waar Git om een wachtwoord
  vraagt; macOS bewaart hem in de keychain.

'Committer: ... Your name and email address were configured automatically'
  Een tip, geen fout. Oplossen met git_identiteit('Naam', 'mail@adres.nl').

IN DE ACTION OP GITHUB
======================

Job 'bouwen' groen, 'publiceren' rood met 404
'Ensure GitHub Pages has been enabled'
  Pages staat niet op GitHub Actions. Zet dat om via
  Settings > Pages > Source = GitHub Actions, en klik in Actions op
  'Re-run all jobs'. Opnieuw pushen hoeft niet: de commit is al binnen.

Job 'bouwen' rood bij het terugcommitten van brondata
  Tussen het uitchecken en het pushen is er iets op main gepusht. Opgelost
  in de workflow met 'git pull --rebase' voor de push, plus
  'continue-on-error: true' zodat een mislukte datacommit de publicatie
  niet tegenhoudt.

Job 'bouwen' rood tijdens het installeren van packages
  Een R-package installeert niet op de runner. Open de mislukte stap en kijk
  welk package het is; voeg het toe onder 'packages:' in
  .github/workflows/publiceer.yml.

Site toont een oude versie
  Pages cachet. Hard verversen met cmd+shift+R, of enkele minuten wachten.

Waarschuwing over Node.js 20
  Gaat over verouderde actie-versies binnen GitHub zelf. Breekt niets.

VERBORGEN MAPPEN
================

.git en .github zijn niet zichtbaar in Finder omdat ze met een punt
beginnen. Zichtbaar maken met cmd + shift + punt. In RStudio zie je ze wel.
")
  invisible(NULL)
}


# ===========================================================================

if (interactive()) {
  cat("Git-functies geladen.\n\n")
  cat("  publiceer()        bouwen, committen, pullen, pushen\n")
  cat("  git_status()       waar sta ik ten opzichte van GitHub?\n")
  cat("  git_eerste_keer()  eenmalige inrichting\n")
  cat("  git_identiteit()   naam en e-mail instellen\n")
  cat("  git_los()          uitleg per foutmelding\n\n")
  cat("Site: ", site_url, "\n", sep = "")
}
