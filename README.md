# PRAX ERP Mobile

Flutter mobile app for PRAX Construction ERP — view-only mode for all modules.

## Setup

1. **Install Flutter** — https://flutter.dev/docs/get-started/install
2. **Clone & install deps**
   ```bash
   git clone https://github.com/dishaanhitechit-hub/erp_mobile
   cd erp_mobile
   flutter pub get
   ```
3. **Backend URL** is pre-configured to `https://132.154.156.82/api` in `lib/config/api.dart`
4. **Run**
   ```bash
   flutter run
   ```

## Modules (View Only)

| Section   | Modules |
|-----------|---------|
| Master    | Sundry Creditor, Sundry Debtor, Supplier, Item Code, Asset Code, Bank & Cash, Cost Center, Category, Unit, Terms |
| Projects  | Projects, Concrete Registry, Drawing Register |
| Resources | Machinery, Manpower |
| Finance   | Purchase Bill, Credit Note, Debit Note, Contra, GIN, Indent |
| Settings  | Users |

## Tech Stack
- Flutter 3.x / Dart 3.x
- `http` for API calls
- `shared_preferences` for token storage
- `google_fonts` + custom Inter font

## Theme
Deep navy glassmorphism — premium dark UI inspired by modern business apps.
