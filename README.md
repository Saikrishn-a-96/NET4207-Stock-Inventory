# NET4207 Stock Inventory Manager

This is a fresh Flutter project source for the NET4207 stock inventory lab. The app code and Firebase packages are included. Connect it to the lecturer's Firebase project before running the Firestore features.

## Create platform files and connect Firebase

1. Extract this folder and open a terminal inside `stock_inventory_flutter_project`.
2. Run `flutter create .` to generate the Android, web, and desktop runner files for your computer.
3. Run `flutter pub get`.
4. Ask the lecturer for the Firebase project ID and access instructions if you do not have them. Configure this project with the class Firebase project using FlutterFire (`flutterfire configure`). This generates `lib/firebase_options.dart`; select the platforms you will demonstrate. The supplied `lib/main.dart` imports this generated file.
5. Ensure Firestore is enabled and the class access rules permit this app to read and write `stockItems`.
6. Run `flutter run` (or `flutter run -d chrome` for web) and test the features below.

Never add passwords, service-account JSON, or private keys to this project or GitHub. The Firebase project ID is **[fill in lecturer-provided project ID]**.

## Features and Firestore schema

The scrollable form validates all six required values before writing. SKU must match `STK-` plus three digits; item names are trimmed and at least 3 characters; category must be Electronics, Stationery, Hardware, or Grocery; quantity and reorder level must be non-negative whole numbers; price must be greater than RM 0. Save progress and write errors are shown, and the form is cleared only after the Firestore write succeeds.

Records are stored in `stockItems` with Firestore-generated document IDs and fields: `sku` (String), `itemName` (String), `category` (String), `quantity` (Integer), `unitPrice` (Number), `reorderLevel` (Integer), and `createdAt` (server Timestamp). The screen retrieves live saved records from Firestore and displays all required fields. Search is partial and case-insensitive across item name or SKU. Category, keyword, and low-stock (`quantity <= reorderLevel`) filters combine together. Quantity sorting works in both directions; Clear filters restores the full list. Loading, empty, and error states are provided.

## Test log

Run and fill in actual results and screenshot filenames before submission; do not mark a test as passed until you observe it.

| Input / action | Expected result | Actual result / screenshot |
|---|---|---|
| Submit blank form or malformed SKU / negative quantity | Inline validation errors; no new document | To run |
| Save STK-101 USB C Cable, Electronics, qty 4, RM 19.90, reorder 5; reload | Saved record appears again with correct values | To run |
| Search `mouse`, choose Electronics, enable Low stock | Only STK-103 Wireless Mouse appears | To run |

Also verify STK-102 partial SKU search, ascending order STK-103 / STK-101 / STK-102, low-stock-only, Clear filters, and screenshots of the demo.
