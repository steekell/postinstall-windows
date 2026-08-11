# Postinstall Windows

Outil PowerShell idempotent pour installer, mettre à jour, configurer et désinstaller des logiciels Windows depuis une interface TUI.

Le projet privilégie [WinGet](https://learn.microsoft.com/windows/package-manager/winget/) et conserve un manifeste local des logiciels et configurations gérés. Une même application peut proposer plusieurs configurations ; l’installation du paquet et l’application d’une configuration sont donc deux choix indépendants.

> Le projet est en cours de construction. Les éléments décrits comme « prévus » définissent le contrat fonctionnel et ne signifient pas encore qu’ils sont implémentés.

## Convention de nommage

Tous les fichiers et dossiers du projet utilisent le `kebab-case` : minuscules, mots séparés par des tirets (`setup-postinstall.ps1`, `dark-mode.json`, `package-managers.psm1`). Les deux fichiers d’instructions `AGENTS.md` et `RULES.md` sont les exceptions demandées pour les outils d’agents.

## Structure

```text
setup-postinstall.ps1       # point d’entrée à la racine
catalog/
  config/                    # configurations applicables aux logiciels
  profiles/                  # sélections d’applications et de configurations
src/
  scripts/                   # installations/configurations réalisables par script
  modules/                   # moteur, TUI, catalogue, manifeste
tests/
docs/
personnal/                   # contenu local, jamais versionné
```

Les applications peuvent être installées par WinGet ou par un script dédié placé dans `src/scripts/`. Une définition doit indiquer explicitement la méthode utilisée et les opérations inverses disponibles.

## Parcours de l’interface

Après le lancement de `setup-postinstall.ps1`, les menus apparaissent dans cet ordre :

### 1. Opération

- Installation
- Mise à jour
- Désinstallation

### 2. Profil

- Manuel (aucun profil préchargé)
- Origine
- Steekell

Un profil préremplit la sélection des applications et, pour chaque application, la configuration souhaitée. Le profil `Manuel` laisse l’utilisateur tout choisir.

### 3. Applications et configurations

Les applications sont regroupées ainsi :

1. **Système**
   - créer les dossiers de bibliothèque (`Y:\library\downloads`, etc.) ;
   - supprimer l’icône de la corbeille du bureau ;
   - placer les icônes à gauche ;
   - masquer la barre de recherche ;
   - masquer la vue des tâches ;
   - configurer le menu contextuel au clic droit ;
   - activer le thème sombre.
2. **Web**
   - Brave Browser ;
   - RustDesk.
3. **Intelligence artificielle**
   - OMP ;
   - Codex Desktop.
4. **Éditeur**
   - Visual Studio Code ;
   - LibreOffice.
5. **Communication**
   - Himalaya ;
   - WhatsApp.

Dans la liste, `Espace` sélectionne ou désélectionne l’application. La touche `c` sélectionne ou désélectionne séparément sa configuration par défaut. Cela permet d’installer une application sans configuration, ou de choisir ensuite une autre configuration parmi celles disponibles. Les flèches et les touches Vim (`h`, `j`, `k`, `l` selon le contexte) naviguent dans l’interface ; `q` ou `Échap` quittent sans modifier le système.

Avant toute action, un récapitulatif doit afficher l’opération, le profil, les applications, les configurations, la méthode d’installation, les élévations requises et les suppressions éventuelles. Une confirmation explicite est obligatoire.

## Utilisation

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-postinstall.ps1
```

### Lancement distant par version

Une version publiée peut être lancée en une seule commande depuis PowerShell grâce au bootstrap versionné :

```powershell
irm https://raw.githubusercontent.com/steekell/postinstall-windows/v0.1.3/setup-postinstall-windows.ps1 | iex
```

Le bootstrap télécharge l’archive du tag `v0.1.3` dans un répertoire temporaire, exécute `setup-postinstall.ps1` avec son catalogue et ses modules, puis supprime les fichiers temporaires. Pour une version différente, le tag et la valeur `$version` du bootstrap doivent correspondre.

Cette forme est pratique mais exécute directement du code récupéré sur Internet. Pour une utilisation sensible, télécharger et contrôler le script ou l’archive avant exécution, puis lancer le fichier localement :

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/steekell/postinstall-windows/v0.1.3/setup-postinstall-windows.ps1 -OutFile .\setup-postinstall-windows.ps1
Get-FileHash .\setup-postinstall-windows.ps1 -Algorithm SHA256
.\setup-postinstall-windows.ps1
```

Chaque version publique doit être créée par un tag Git immuable et publier une somme SHA-256 de l’archive. Le bootstrap devra être mis à jour avec le nouveau numéro avant chaque release.

Pour rendre `v0.1.3` disponible, le dépôt GitHub `steekell/postinstall-windows` doit être public et le tag doit être poussé :

```bash
git remote add origin https://github.com/steekell/postinstall-windows.git
git push -u origin main
git push origin v0.1.3
```

GitHub générera alors automatiquement l’archive `https://github.com/steekell/postinstall-windows/archive/refs/tags/v0.1.3.zip` utilisée par le bootstrap.

Prérequis : Windows 10/11, PowerShell 5.1 minimum (PowerShell 7 recommandé), WinGet/App Installer disponible et accès réseau lorsque nécessaire. Le script doit détecter les prérequis, expliquer les droits administrateur requis et ne jamais modifier durablement la politique d’exécution.

## Catalogue et profils

Les fichiers de `catalog/config/` décrivent les configurations indépendantes d’une application. Chaque configuration possède un identifiant stable et une version explicite, par exemple `1.0.0`. Les fichiers de `catalog/profiles/` référencent les applications et associent éventuellement un identifiant de configuration à chacune d’elles.

Exemple conceptuel de profil :

```json
{
  "schema-version": 1,
  "name": "steekell",
  "applications": [
    { "id": "brave-browser", "config": "default" },
    { "id": "visual-studio-code", "config": "steekell" },
    { "id": "whatsapp", "config": null }
  ]
}
```

Les définitions sont validées avant affichage ou exécution. Une configuration doit déclarer au minimum son identifiant, sa version (`config-version`) et les artefacts qu’elle gère. Les configurations doivent être réexécutables, ciblées et réversibles. Les scripts de `src/scripts/` sont contrôlés comme du code et ne doivent pas exécuter de commande arbitraire provenant d’une entrée non validée.

## Manifeste et désinstallation

Le manifeste local doit être configurable et conserver au minimum l’identifiant de définition, la version de l’application, le gestionnaire utilisé, la version installée, l’identifiant et la version de chaque configuration appliquée (`config-version`), son empreinte et le résultat de chaque opération. Il peut être stocké sous `%ProgramData%\Postinstall-Windows\manifest.json` pour les données machine et `%LOCALAPPDATA%\Postinstall-Windows\` pour les données utilisateur.

L’état réel du système doit toujours être vérifié : le manifeste ne constitue pas une preuve suffisante. Ses écritures doivent être atomiques et résistantes aux interruptions. Lorsqu’une nouvelle version de configuration est appliquée, le moteur compare la version déclarée à celle enregistrée et n’applique la migration que si nécessaire.

### Sauvegarde avant modification

Avant toute installation ou mise à jour qui risque de modifier une configuration existante, le moteur doit :

1. détecter la configuration réellement présente ;
2. calculer son empreinte et l’associer à l’application concernée ;
3. créer une copie avant toute écriture ;
4. appliquer la nouvelle configuration uniquement après réussite du backup ;
5. enregistrer le backup dans le manifeste.

Le nom du backup suit exactement le format suivant, avec une date/heure UTC au format compact et les secondes :

```text
<name>.bak.<yyyyMMddTHHmmssZ>.<extension>
```

Exemple :

```text
settings.bak.20260811T145501Z.json
```

L’extension d’origine est conservée. Pour un fichier sans extension, le nom ne comporte pas de point final supplémentaire. Le manifeste doit enregistrer le chemin du backup, le chemin original, la version de configuration remplacée, l’empreinte avant modification, la date UTC et la raison (`installation`, `mise à jour` ou `migration`). Une collision à la seconde doit être traitée de manière sûre et ne doit jamais écraser un backup existant.

La désinstallation doit proposer : logiciel avec conservation de configuration, logiciel avec suppression des configurations gérées, ou suppression d’une configuration seule. La suppression est limitée aux artefacts déclarés explicitement dans `catalog/config/`.

## Gitflow et configuration Git recommandée

Branches : `main` pour les versions publiées, `develop` pour l’intégration, `feature/<nom>`, `release/<version>` et `hotfix/<version>`. Les commits suivent autant que possible Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`).

Réglages utiles à appliquer après initialisation du dépôt :

```bash
git config pull.rebase true
git config fetch.prune true
git config rebase.autosquash true
git config rerere.enabled true
git config core.autocrlf false
git config core.safecrlf true
git config init.defaultBranch main
```

Le dépôt devra également activer la protection de `main` et `develop`, les Pull Requests obligatoires, les contrôles CI obligatoires et l’interdiction des push forcés. Les installations réelles ne doivent jamais s’exécuter par défaut dans la CI.

## Tests et sécurité

```powershell
Invoke-ScriptAnalyzer -Path .\src -Recurse
Invoke-Pester -Path .\tests
```

Les tests doivent couvrir le premier passage, le second passage sans changement, les erreurs WinGet, la reprise après échec, le manifeste, l’élévation, la sélection `Espace`, la configuration avec `c` et les trois modes de désinstallation. Les appels à WinGet et au système sont mockés dans les tests unitaires.

Ne jamais versionner de secrets, jetons, mots de passe, manifestes utilisateur ou journaux contenant des données sensibles. Les identifiants de paquets, sources, URLs, sommes de contrôle et opérations de configuration doivent être revus avant ajout.

## Contribution

Créer une branche `feature/` depuis `develop`, modifier le code, les tests et la documentation associés, exécuter les contrôles locaux, puis ouvrir une Pull Request vers `develop`. Décrire le comportement avant/après, les logiciels concernés, les privilèges requis, les effets sur le manifeste et les tests effectués.

## Licence

La licence sera ajoutée avant la publication du dépôt. Tant qu’elle n’est pas présente, le contenu ne doit pas être redistribué comme un logiciel libre.
