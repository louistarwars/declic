# 📸 Déclic

**Le défi photo du jour entre potes.** Chaque jour, ton groupe reçoit un thème (« Quelque chose de bleu », « Ta tasse de café », « Le pire stylo de ta trousse »…). Chacun poste sa photo, puis tout le monde vote pour la plus **drôle** 😂, la plus **belle** 😍 et la plus **originale** 🤯. Les votes rapportent des points, et un classement désigne le champion de chaque saison (un mois).

## Jouer

- 🤖 **Android** : télécharge l'APK dans les [Releases](https://github.com/louistarwars/declic/releases/latest).
- 📱 **iPhone** (et tout navigateur) : ouvre **<https://louistarwars.github.io/declic/>** dans Safari, puis touche **Partager → « Sur l'écran d'accueil »**. Déclic s'installe comme une vraie app, sans App Store et sans licence Apple. Tout le monde joue dans les mêmes groupes.

## Fonctionnalités

- **Groupes privés** : création, invitation par code à 6 caractères, partage du code
- **Défi du jour** : un thème par jour et par groupe, tiré d'un catalogue de plus de 170 idées. Les idées proposées par le groupe passent en priorité.
- **Photo** : appareil photo ou galerie, avec une légende. Les photos des autres restent cachées tant que tu n'as pas posté la tienne.
- **Vote** : trois catégories. Le vote s'ouvre à l'heure choisie par le groupe (20h par défaut), ou plus tôt si tout le monde a posté. Il se termine à minuit, ou dès que tout le monde a voté.
- **Résultats** : gagnants par catégorie et classement du jour
- **Classement par saison** (mensuel), avec un podium et l'historique des saisons passées
- **Historique** de tous les défis, avec leurs photos et leurs résultats
- **Séries** 🔥 de jours consécutifs
- **Notifications** : le thème du jour chaque matin, à l'heure de ton choix, et un rappel quand le vote s'ouvre
- Profil avec emoji et couleur, suppression du compte, politique de confidentialité

**Barème** : +1 pt par photo postée, +2 pts par vote reçu, +3 pts par catégorie remportée.

## Stack

- **App** : Flutter (Android)
- **Backend** : [Supabase](https://supabase.com) (auth, Postgres avec RLS, stockage des photos). Toute la logique du jeu (phases, points) tourne côté serveur dans `supabase/schema.sql`.
- **CI** : GitHub Actions compile un APK et un AAB signés à chaque push, et déploie la version web sur GitHub Pages. Chaque tag `v*` publie une Release.

## Mise en route

### 1. Backend Supabase (gratuit, environ 5 minutes)

1. Crée un projet sur <https://supabase.com/dashboard>.
2. **SQL Editor → New query** : colle le contenu de [`supabase/schema.sql`](supabase/schema.sql), puis clique sur **Run**.
3. **Authentication → URL Configuration → Redirect URLs** : ajoute `com.louistarwars.declic://login-callback/` et `https://louistarwars.github.io/declic/` (liens « mot de passe oublié » et confirmation d'e-mail qui rouvrent l'app).
4. **Authentication → Sign In / Providers → Email** : désactive *Confirm email* si tu veux que tes amis puissent jouer tout de suite (facultatif).
5. **Project Settings → API** : récupère la *Project URL* et la clé *anon / publishable*.

### 2. Secrets GitHub

Dans **Settings → Secrets and variables → Actions** du dépôt :

| Secret | Valeur |
|---|---|
| `SUPABASE_URL` | URL du projet Supabase |
| `SUPABASE_ANON_KEY` | clé anon / publishable |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 declic-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | `declic` |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

Relance ensuite le workflow (**Actions → Build Android → Run workflow**). L'APK se trouve dans les *artifacts* du run, ou dans la page **Releases** pour les tags.

> ⚠️ Garde précieusement le keystore et ses mots de passe : sans eux, impossible de publier une mise à jour sur le Play Store.

### Développement local

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
```

### Publier une nouvelle version

Incrémente `version:` dans `pubspec.yaml`, puis :

```bash
git tag v1.0.1 && git push --tags
```

Le fichier `.aab` de la release s'envoie tel quel sur la Google Play Console.

## Notes

- Le jeu vit à l'heure de Paris (`Europe/Paris`), à la fois dans `supabase/schema.sql` et dans `lib/config.dart`.
- La version web n'a pas de rappels quotidiens : ils n'existent que dans l'app Android.
- Les notifications sont programmées localement sur le téléphone. Les défis des 7 prochains jours sont générés à l'avance, ce qui permet d'afficher le vrai thème dans la notification, même application fermée.
