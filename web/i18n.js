// Site language, stored in localStorage as dailyred-lang. English is the
// default when nothing is saved. Play boots web/game/dailyred.gba.gz for EN
// and web/game/dailyred-fr.gba.gz for FR (see game-files.js). A game already
// on screen keeps its ROM until the next Play.
const KEY = 'dailyred-lang';

export const STRINGS = {
  en: {
    description: "One Pokémon battle a day: six random level 100 Pokémon against RED at the top of the mountain.",
    language: 'Language',
    game: 'Game',
    touch: 'Touch controls',
    dpad: 'Directional pad',
    wins: 'Wins',
    losses: 'Losses',
    winStreak: 'Win streak',
    dayStreak: 'Day streak',
    play: 'Play',
    beat: 'You beat RED today!',
    lost: 'RED won today.',
    next: 'Next battle in {time}',
    practice: "Practice run: results aren't saved.",
    downloading: 'Downloading the game',
    starting: 'Starting the emulator',
    progress: '{loaded} of {total} MB',
    progressUnknown: '{loaded} MB',
    errorHeading: "The game didn't start",
    retry: 'Try again',
    mute: 'Mute',
    unmute: 'Unmute',
    volume: 'Volume',
    fullscreen: 'Full screen',
    exitFullscreen: 'Exit full screen',
    keyboard: 'Keyboard',
    keysMove: 'Walk, move the cursor',
    keysA: 'A button: talk, confirm',
    keysB: 'B button: back, cancel',
    keysStart: 'Start: open the menu',
    keysSelect: 'Select',
    phoneNote: 'On a phone or tablet, use the buttons under the screen.',
    footer: "Daily Red is a free, unofficial fan project. It isn't affiliated with or endorsed by Nintendo, Creatures Inc., GAME FREAK inc. or The Pokémon Company. Pokémon and all game content are © Nintendo, Creatures Inc. and GAME FREAK inc.",
    licenses: 'Licenses',
    source: 'Source',
    browser: "This browser can't run the game. Use a recent version of Chrome, Edge, Firefox or Safari.",
    connection: 'Check your connection and try again.',
  },
  fr: {
    description: 'Un combat Pokémon par jour : six Pokémon de niveau 100 tirés au sort contre RED, au sommet de la montagne.',
    language: 'Langue',
    game: 'Jeu',
    touch: 'Commandes tactiles',
    dpad: 'Croix directionnelle',
    wins: 'Victoires',
    losses: 'Défaites',
    winStreak: 'En série',
    dayStreak: 'Jours',
    play: 'Jouer',
    beat: "Tu as battu RED aujourd'hui !",
    lost: "RED a gagné aujourd'hui.",
    next: 'Prochain combat dans {time}',
    practice: "Partie d'essai : les résultats ne sont pas enregistrés.",
    downloading: 'Téléchargement du jeu',
    starting: "Démarrage de l'émulateur",
    progress: '{loaded} sur {total} Mo',
    progressUnknown: '{loaded} Mo',
    errorHeading: "Le jeu n'a pas démarré",
    retry: 'Réessayer',
    mute: 'Couper le son',
    unmute: 'Remettre le son',
    volume: 'Volume',
    fullscreen: 'Plein écran',
    exitFullscreen: 'Quitter le plein écran',
    keyboard: 'Clavier',
    keysMove: 'Marcher, déplacer le curseur',
    keysA: 'Bouton A : parler, confirmer',
    keysB: 'Bouton B : retour, annuler',
    keysStart: 'Start : ouvrir le menu',
    keysSelect: 'Select',
    phoneNote: "Sur un téléphone ou une tablette, utilise les boutons sous l'écran.",
    footer: "Daily Red est un projet de fan gratuit et non officiel. Il n'est ni affilié à Nintendo, Creatures Inc., GAME FREAK inc. ou The Pokémon Company, ni approuvé par eux. Pokémon et tout le contenu du jeu sont © Nintendo, Creatures Inc. et GAME FREAK inc.",
    licenses: 'Licences',
    source: 'Source',
    browser: 'Ce navigateur ne peut pas lancer le jeu. Utilise une version récente de Chrome, Edge, Firefox ou Safari.',
    connection: 'Vérifie ta connexion et réessaie.',
  },
};

export function getLang() {
  try {
    const saved = localStorage.getItem(KEY);
    if (saved === 'fr' || saved === 'en') return saved;
  } catch { /* storage blocked: stay in English */ }
  return 'en';
}

export function setLang(lang) {
  if (lang !== 'fr' && lang !== 'en') return;
  try { localStorage.setItem(KEY, lang); } catch { /* the choice lasts for this page only */ }
}

export function t(key, vars) {
  const lang = getLang();
  let text = STRINGS[lang][key] ?? STRINGS.en[key] ?? key;
  if (vars) {
    for (const [name, value] of Object.entries(vars)) text = text.replaceAll(`{${name}}`, value);
  }
  return text;
}

// Fills every element marked with data-i18n or data-i18n-aria.
export function applyI18n(root = document) {
  const lang = getLang();
  document.documentElement.lang = lang;
  const description = document.querySelector('meta[name="description"]');
  if (description) description.setAttribute('content', t('description'));
  root.querySelectorAll('[data-i18n]').forEach((el) => {
    el.textContent = t(el.dataset.i18n);
  });
  root.querySelectorAll('[data-i18n-aria]').forEach((el) => {
    el.setAttribute('aria-label', t(el.dataset.i18nAria));
  });
  root.querySelectorAll('.lang-button').forEach((button) => {
    const selected = button.dataset.lang === lang;
    button.setAttribute('aria-pressed', String(selected));
  });
}
