# SenderWho

SenderWho is a Flutter email-safety and inbox-cleanup app with a Node.js backend server.

## Project Structure

```text
SenderWho/
  senderwho/   Flutter mobile app
  server/      Node.js/NestJS backend
  docs/        Architecture and provider setup docs
```

## Architecture

The production backend/frontend plan is documented here:

- [Production Architecture](docs/production_architecture.md)
- [Email Provider Client Requirements](docs/email_provider_client_requirements.md)
- [Yahoo Mail Production Setup](docs/yahoo_production_setup.md)
- [Node.js Server Backend](server/README.md)

## Getting Started

Start MySQL, apply every committed migration, and run the API:

```bash
docker compose up -d mysql
cd server
npm install
npm run dev
```

The development command generates Prisma Client and applies committed
migrations before starting NestJS watch mode.

Then run Flutter in another terminal:

```bash
cd senderwho
flutter pub get
flutter run
```

For visual-only review when Google OAuth is intentionally unavailable, enable
the local UI preview explicitly:

```bash
cd senderwho
flutter run --dart-define=SENDERWHO_UI_PREVIEW=true
```

Tap **Connect my inbox** on the welcome page, then **Connect my inbox** on the
connection page. Preview mode opens the dashboard with non-production sample
metrics. It cannot be enabled in a profile or release build and does not perform
Gmail actions.

Normal debug runs use the real API and Google OAuth flow. Start one with:

```bash
flutter run --dart-define=SENDERWHO_API_URL=http://localhost:3000/api/v1
```

To view MySQL visually, run
`docker compose --profile tools up -d adminer`, open
`http://localhost:8080`, and follow the credentials and safety notes in the
[server database guide](server/README.md#see-the-database).

When running the Flutter app against a custom API URL:

```bash
cd senderwho
flutter run --dart-define=SENDERWHO_API_URL=http://localhost:3000/api/v1
```

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Android production release

Release builds must use an application-owned signing key. Copy
`senderwho/android/key.properties.example` to
`senderwho/android/key.properties`, fill it with the private keystore values,
and keep both the properties file and keystore outside version control. Replace
the remaining `com.example.sender_who` application ID only after the final
reverse-DNS ID has been chosen and registered; changing it later creates a
different Android application.

Before deploying the backend, replace every `REPLACE_WITH_...` value in the
runtime environment. Production startup rejects placeholders and Gmail scan
settings outside the tested quota-safe ranges.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
