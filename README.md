# VarsityVault

Varsity Vault is a comprehensive, role-based high school athletics management platform built with Flutter and Firebase. It centralizes student medical clearances, roster management, equipment tracking, and game scheduling into a single secure ecosystem.

## 🌐 Live Demo
**Access the live application here:** varsityvault-324f5.web.app

## 🌟 Key Features

The application utilizes a "Many Hats" architecture, dynamically altering the UI and permissions based on the user's assigned role:

* **Students/Athletes:** Submit medical clearances, upload insurance/physical documents, view live schedules, and generate digital Emergency Cards.
* **Head & Assistant Coaches:** Manage varsity, JV, and frosh rosters, view player medical statuses, input game scores, and schedule early-release bus times.
* **Athletic Directors (AD):** "God-mode" access to oversee all school clearances, sync district master calendars via iCal, generate financial/equipment reports, and create secure staff invite links.
* **Athletic Trainers:** Manage the Med-Bay hub, log student injuries (automatically updating their status to "INJURED"), process doctor's notes, and ping the AD for consumable restocks.
* **Equipment Attendants:** Scan barcodes to check gear in/out, track outstanding inventory, and automatically assign missing equipment fines to student accounts.
* **VaultBot AI:** A deeply integrated, context-aware AI assistant powered by Google's Gemini 1.5 Flash. VaultBot can answer dynamic questions about the app's functionality based on the user's current role and trigger interactive UI walkthroughs.

## 🛠 Tech Stack

* **Frontend:** Flutter (Dart) for Web
* **Backend & Database:** Firebase Authentication, Cloud Firestore
* **AI Integration:** `google_generative_ai` (Gemini API)
* **External APIs:** AllOrigins (CORS bypass for iCal syncing)

## 🚀 Deployment Overview
This application is deployed and hosted entirely via Firebase Hosting. All role-based data synchronization, user authentication, and AI routing are handled securely in the cloud environment.
