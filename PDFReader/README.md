# PDFReader — iOS App

## What you'll need before starting

1. A Mac computer running macOS Ventura (13) or later
2. An Apple ID (free — the same one you use for iCloud)
3. Xcode 15 or later (Apple's free programming tool)

---

## Step 1 — Install Xcode

1. Open the **App Store** on your Mac
2. Search for **Xcode**
3. Click **Get**, then **Install**
4. This is a large download (~8 GB). Leave it running and come back in 30–60 minutes
5. Once installed, open Xcode from your Applications folder
6. The first time it opens, it will ask to install "Additional Components" — click **Install**

---

## Step 2 — Create the Xcode project

1. Open Xcode
2. Click **Create New Project…**
3. In the template picker:
   - Select **iOS** at the top
   - Choose **App**
   - Click **Next**
4. Fill in the project details:
   - **Product Name:** `PDFReader`
   - **Team:** Select your Apple ID (or "None" for now — you can set it later to run on a real phone)
   - **Organization Identifier:** `com.yourname` (e.g. `com.john` — no spaces, lowercase only)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - Leave everything else as-is
5. Click **Next**
6. Choose where to save the project (e.g. your Desktop), then click **Create**

Xcode will open with a new project. You'll see some default files already there — you'll replace them.

---

## Step 3 — Set the deployment target to iOS 17

iOS 17 is required for SwiftData, which is what this app uses to save data.

1. In the left sidebar, click the very top item — it's blue and named **PDFReader**
2. In the main panel, find **Deployment Info**
3. Change the **minimum deployments** dropdown from whatever it says to **iOS 17.0**

---

## Step 4 — Set up the folder structure

You need to create groups (folders) in Xcode that match the project structure.
In the left sidebar, **right-click** on the `PDFReader` folder and choose **New Group** to create each one.

Create this exact structure:

```
PDFReader/
├── App/
├── Modules/
│   └── Library/
├── Data/
│   ├── Models/
│   └── Repositories/
└── Core/
    └── DesignSystem/
```

To create a nested group like `Modules/Library`:
1. Right-click `PDFReader` → New Group → name it `Modules`
2. Right-click `Modules` → New Group → name it `Library`

---

## Step 5 — Delete the default files

Xcode creates some starter files you don't need. Delete these:
- `ContentView.swift`
- `PDFReaderApp.swift` (you'll replace this with the provided version)

To delete: right-click each file → **Delete** → **Move to Trash**

---

## Step 6 — Add the source files

For each file listed below, you'll:
1. Right-click the correct group in Xcode's sidebar
2. Choose **New File from Template…** → **Swift File** → **Next**
3. Name the file exactly as shown
4. Click **Create**
5. Delete all the default code that Xcode puts in
6. Paste in the code provided

### Files to create (group → filename):

| Group | Filename |
|---|---|
| App | `PDFReaderApp.swift` |
| App | `AppContainer.swift` |
| App | `RootView.swift` |
| Data/Models | `Document.swift` |
| Data/Models | `Highlight.swift` |
| Data/Repositories | `DocumentRepository.swift` |
| Data/Repositories | `HighlightRepository.swift` |
| Data/Repositories | `BookmarkRepository.swift` |
| Modules/Library | `LibraryViewModel.swift` |
| Modules/Library | `LibraryView.swift` |
| Modules/Library | `DocumentCard.swift` |
| Core | `MockData.swift` |
| Core/DesignSystem | `Theme.swift` |

Paste the corresponding code from the provided Swift files into each one.

---

## Step 7 — Run the app

### Option A: In the Simulator (no iPhone needed)

1. At the top of Xcode, find the device selector dropdown (it might say something like "iPhone 15 Pro")
2. Make sure a Simulator is selected (any iPhone model is fine)
3. Press the **Play button** (▶) at the top left, or press **Cmd + R**
4. Xcode will build the app — this takes about 30–60 seconds the first time
5. The iOS Simulator window will open and launch the app

You'll see the Library screen with sample book covers. Importing real PDFs doesn't work in the simulator yet (the PDF viewer is wired up in the next milestone), but the UI is fully working.

### Option B: On your real iPhone

1. Connect your iPhone with a USB cable
2. On your iPhone, tap **Trust** when asked
3. In Xcode's device dropdown, select your iPhone
4. Press **Cmd + R** to build and run
5. The first time, iOS will ask you to trust the developer profile:
   - On your iPhone: Settings → General → VPN & Device Management → tap your Apple ID → Trust
   - Then press **Cmd + R** in Xcode again

---

## Project structure explained simply

Think of the project like a kitchen:
- **App/** — the front door and light switches (app entry point, navigation)
- **Data/Models/** — the recipes (what a Document, Highlight, Note looks like)
- **Data/Repositories/** — the fridge and pantry (saving and loading data)
- **Modules/Library/** — the dining room (everything the user sees in the library)
- **Core/** — the kitchen tools everyone shares (colors, fonts, mock data)

---

## What's implemented in this milestone

- App launches into a library grid view
- Grid shows mock PDF cards with cover colors and metadata
- Toggle between grid and list layouts
- Sort by last opened / title / date added
- Search bar filters documents by title
- Long-press a card to Rename or Delete
- Import button (wires up to document picker — next milestone will copy the file)
- Empty state when no documents exist
- Full dark mode support
- All data models defined and ready for SwiftData persistence
- Preview system with realistic mock data

## What comes next

- Reader view (PDFKit integration)
- Real PDF import from Files app
- Highlight and annotation creation
- Bookmark panel
- Word definition popup
