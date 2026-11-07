# Clinova — Clinic Appointment Management System

Application **Flutter + Firebase** (Authentication + Cloud Firestore) pour gérer les rendez-vous d'une clinique.
Fonctionne en **application Android** et en **application web** installable sur l'écran d'accueil d'un **iPhone** (Safari).
Interface **FR / EN** (bouton de bascule instantanée), clinique **fermée le vendredi**, **mode démo** avec un compte par rôle.

---

## 1. Ce qu'il faut installer (une seule fois)

| Outil | Pourquoi |
|---|---|
| **Flutter 3.29 ou plus récent** — https://docs.flutter.dev/get-started/install | compiler l'app |
| **Visual Studio Code** + extension *Flutter* | éditer / lancer |
| **Android Studio** (SDK Android) ou un téléphone Android en *débogage USB* | lancer sur Android |
| **Node.js** puis `npm install -g firebase-tools` | règles Firestore + hébergement web |
| `dart pub global activate flutterfire_cli` | relier l'app à votre projet Firebase |

Vérifiez avec : `flutter doctor` (les lignes Flutter, Android et Chrome doivent être vertes).

## 2. Créer le projet Firebase (plan gratuit Spark)

1. https://console.firebase.google.com → **Ajouter un projet** (ex. `clinova-demo`). Google Analytics : facultatif.
2. **Authentication** → *Commencer* → onglet *Sign-in method* → activer **E-mail/Mot de passe**.
3. **Firestore Database** → *Créer une base de données* → mode **production** → région proche (ex. `europe-west1`).

> Aucune carte bancaire n'est nécessaire : l'app n'utilise pas de Cloud Function.

## 3. Préparer le projet (dans le dossier `clinova`, terminal de VS Code)

```bash
# 1) Génère les dossiers Android / Web manquants (vos fichiers existants ne sont pas écrasés)
flutter create . --platforms=android,web --org com.clinova --project-name clinova

# 2) Relie l'app à VOTRE projet Firebase (crée lib/firebase_options.dart)
firebase login
flutterfire configure --project=clinova-demo --platforms=android,web

# 3) Ajuste Android : nom "Clinova", permission Internet, minSdk 23
dart run tool/patch_android.dart

# 4) Dépendances + vérifications
flutter pub get
flutter analyze
flutter test

# 5) Déploie les règles de sécurité (OBLIGATOIRE)
firebase use clinova-demo
firebase deploy --only firestore:rules
```

> Remplacez `clinova-demo` par l'identifiant réel de votre projet Firebase.
> Si `flutterfire` n'est pas reconnu, ajoutez le dossier *pub cache bin* au PATH (le message de `dart pub global activate` l'indique).

## 4. Lancer l'application

**Android (téléphone branché ou émulateur)**
```bash
flutter run
```
**APK à installer sur un téléphone Android**
```bash
flutter build apk --release
# fichier : build/app/outputs/flutter-apk/app-release.apk
```
**Web (ordinateur)**
```bash
flutter run -d chrome
```

## 5. Mettre l'app sur l'écran d'accueil de l'iPhone

```bash
flutter build web --release
firebase deploy --only hosting
```
Firebase affiche une adresse `https://clinova-demo.web.app`.
Sur l'iPhone : ouvrez cette adresse dans **Safari** → bouton **Partager** ⬆︎ → **Sur l'écran d'accueil** → **Ajouter**.
L'icône Clinova apparaît et l'app s'ouvre en plein écran comme une application (aucun Mac nécessaire).

## 6. Premier lancement et comptes démo

Au premier lancement, l'écran **« Bienvenue sur Clinova »** apparaît : touchez **Initialiser Clinova**.
L'app crée alors automatiquement :

| Rôle | E-mail | Mot de passe |
|---|---|---|
| Patient | patient@clinova.demo | Patient123! |
| Médecin (Médecine générale) | dr.ahmed@clinova.demo | Doctor123! |
| Médecin (Pédiatrie) | dr.amina@clinova.demo | Doctor123! |
| Réceptionniste | reception@clinova.demo | Recep123! |
| Administrateur | admin@clinova.demo | Admin123! |

Les deux médecins reçoivent l'horaire par défaut : **samedi → jeudi, 08:00–12:00 et 14:00–17:00** (vendredi fermé).
Sur l'écran de connexion, la zone **Mode démo** permet de se connecter en un clic.
L'administrateur peut masquer ces boutons (Profil → *Afficher les comptes démo*) et recréer les comptes démo.

### Ajouter vos propres données
* **Admin** → onglet *Médecins* → *Nouveau médecin* (avec horaire par défaut), bouton 🕑 pour modifier l'horaire.
* **Admin** → onglet *Utilisateurs* → *Nouveau membre du personnel* (réceptionniste / administrateur).
* **Réceptionniste** → *Patients* → *Nouveau patient* → *Prendre RDV pour ce patient*.
* **Patient** → *Créer un compte patient* sur l'écran de connexion.

### Notifications (in-app, gratuites)
* Une **cloche 🔔 avec compteur** (patient et médecin) en haut de l'écran.
* Le **patient** est prévenu quand un rendez-vous est réservé pour lui, reporté, annulé ou terminé ; le **médecin** quand un rendez-vous est réservé, reporté ou annulé avec lui.
* Si l'app est ouverte, un message apparaît en bas de l'écran dès qu'une notification arrive.
* Section **Rappels** : les rendez-vous des prochaines 24 h.
* Les notifications sont écrites dans la **même transaction** que le rendez-vous (`notifications/{id}`) et seul le destinataire peut les lire (règles Firestore).
* Les e-mails / notifications push téléphone ne sont pas inclus : ils exigent une Cloud Function, donc le plan payant Blaze.

### Scénario conseillé pour la présentation
1. **Patient** : Médecins → Dr Ahmed Hassan → choisir une date (le vendredi est grisé « Fermé ») → créneau → confirmer.
2. **Patient** : Mes RDV → *Reporter* puis *Annuler* (le créneau redevient libre).
3. **Réceptionniste** : Patients → Nouveau patient → Prendre RDV ; Recherche par patient / médecin / date.
4. **Médecin** : Aujourd'hui → *Infos patient* → *Marquer terminé*.
5. **Admin** : Utilisateurs (désactiver un compte, changer un rôle) ; Médecins → horaire (ajouter / désactiver une plage).
6. **Notifications** : réservez en tant que Réceptionniste pour « Fatouma Ali », puis connectez-vous en Patient → la cloche affiche 1 ; en Médecin → « Nouveau rendez-vous ».
7. Bouton **FR / EN** en haut à droite sur chaque écran.

## 7. Correspondance avec le document UML

| Cas d'utilisation | Où |
|---|---|
| UC1 Register / UC2 Log In | `lib/screens/auth/` |
| UC3 Médecins et spécialités | `lib/screens/shared/doctor_picker_screen.dart` |
| UC4 Créneaux / UC5 Réserver / UC8 Reporter | `lib/screens/shared/book_screen.dart`, `lib/services/booking_service.dart` |
| UC6 Voir RDV / UC7 Annuler / UC13 Terminer | `lib/widgets/appointment_card.dart`, `lib/screens/homes.dart` |
| UC9 Patients / UC14 Infos patient | `lib/screens/staff/patient_form_screen.dart`, `lib/screens/shared/patient_info_screen.dart` |
| UC10 Médecins | `lib/screens/staff/doctor_form_screen.dart` |
| UC11 Recherche / UC12 RDV du jour | `lib/screens/staff/staff_tabs.dart` |
| UC15 Gérer les utilisateurs | `lib/screens/admin/users_screen.dart` |
| UC16 Horaire médecin (FR14) | `lib/screens/admin/schedule_screen.dart` |
| BookingService : `bookAtomically()`, `cancelAtomically()`, `rescheduleAtomically()`, `markCompleted()` | `lib/services/booking_service.dart` |
| Énumérations `UserRole`, `AppointmentStatus` | `lib/models/models.dart` |
| Notifications + rappels | `lib/screens/shared/notifications_screen.dart` |
| Collections `users`, `patients`, `doctors`, `doctorSchedules`, `appointments`, `slotReservations`, `notifications` | `firestore.rules`, `lib/services/repo.dart` |

### Écarts assumés par rapport au document (à signaler à la professeure)
* **Plan Firebase gratuit (Spark)** : la réservation n'est pas une Cloud Function (payante) mais une **transaction Firestore atomique**. Les règles `firestore.rules` jouent le rôle de serveur de confiance : rôle, propriétaire, créneau futur, 30 min, horaire du médecin, vendredi fermé, unicité `doctorId_startMillis`, annulation/report atomiques.
* **iOS** : pas d'App Store (pas de Mac). L'app est **Android natif** + **web installable sur iPhone**, comme conseillé par la professeure.
* **Confidentialité médecin** : le médecin n'a aucun accès à la collection `patients` ; il voit uniquement les informations minimales copiées dans ses propres rendez-vous.
* Heure de la clinique : **Africa/Djibouti (UTC+3)**. Annulation / report par le patient : **à tout moment avant le rendez-vous**.

## 8. Tests (section 11 du document)

`flutter test` vérifie l'heure clinique, le vendredi fermé, la durée de 30 min, la clé de réservation et les traductions.
Tests manuels avec les comptes démo :

| Test | Comment | Résultat attendu |
|---|---|---|
| Réservation valide | Patient réserve un créneau libre | RDV « Programmé » + créneau barré pour les autres |
| Double réservation | 2 appareils réservent le même créneau en même temps | un seul réussit, l'autre voit « Ce créneau vient d'être réservé » |
| Hors horaire / vendredi / passé | le calendrier ne les propose pas ; les règles Firestore les refusent aussi | refusé |
| Annulation | Annuler un RDV | statut Annulé, créneau libéré |
| Conflit de report | Reporter vers un créneau pris | refusé, RDV d'origine intact |
| RDV du jour (FR11) | Médecin / réception → Aujourd'hui | triés par heure |
| Recherche (FR12) | Réception → Recherche | résultats filtrés, état vide géré |
| Confidentialité | Médecin ouvre un patient sans RDV avec lui | « Accès refusé » |
| Élévation de rôle | Un patient tente de changer son rôle | refusé par les règles |
| Horaire | Admin modifie une plage | les créneaux proposés changent |
| Notification | Réception réserve / annule pour un patient | le patient et le médecin voient la notification ; personne d'autre ne peut la lire |

## 9. Problèmes fréquents

| Message | Solution |
|---|---|
| `firebase_options.dart` introuvable | lancer `flutterfire configure` (étape 3.2) |
| « Action non autorisée » partout | déployer les règles : `firebase deploy --only firestore:rules` |
| « Impossible de joindre Firebase » | créer la base Firestore (étape 2.3) et vérifier Internet |
| « La connexion par e-mail n'est pas activée » | activer E-mail/Mot de passe (étape 2.2) |
| Erreur `minSdk` à la compilation Android | relancer `dart run tool/patch_android.dart` |
| Ancienne version sur iPhone | fermer l'app web puis la rouvrir (le cache se met à jour) |
