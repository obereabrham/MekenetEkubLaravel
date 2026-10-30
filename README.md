# Mekenet Ekub — Laravel + MySQL / PostgreSQL

This is the Laravel/PHP port of the supplied Flask Mekenet Ekub website. It keeps the original page design, CSS, JavaScript, logo, and main member/admin workflows, with Laravel routing, sessions, uploads, mail configuration, and MySQL/PostgreSQL connection support.
The original Jinja templates were carried over as Twig templates so their layout and styling stay close to the supplied site. Laravel renders them through the small Twig view engine in `app/View`.

## Requirements

- PHP 8.3–8.5, with PDO MySQL and/or PDO PostgreSQL, OpenSSL, Mbstring, Fileinfo, and the standard Laravel PHP extensions
- Composer
- MySQL 8.0+ or PostgreSQL 14+

## Local setup

1. Copy `.env.example` to `.env`.
2. Create an empty MySQL database named `mekenet_ekub`, or set `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` in `.env` for an existing database.
3. Set `ADMIN_USERNAME`, `ADMIN_PHONE`, and `ADMIN_PASSWORD` in `.env` before seeding if you want the seeder to create the first admin account. The password should be at least 8 characters and include an uppercase letter, a number, and a special character. You can also set `ADMIN_FIRST_NAME`, `ADMIN_LAST_NAME`, and `ADMIN_EMAIL`.
4. Install dependencies and initialize the app:

   ```sh
   composer install
   php artisan key:generate
   php artisan migrate --seed
   php artisan serve
   ```

5. Open the URL printed by `php artisan serve`.

On Windows PowerShell, copy the environment template with `Copy-Item .env.example .env` before editing it.

If the database already has an admin user, the seeder leaves it as-is. If the admin variables are blank, the seeder does not create a default credential.

## Render with Neon PostgreSQL

In the Render web service environment, set `DB_CONNECTION=pgsql` and provide the Neon connection string as `DATABASE_URL` (or `DB_URL`). The connection string must be the one copied from the Neon dashboard; do not use `127.0.0.1` for a hosted database. If using separate settings instead, set `DB_HOST` to the Neon hostname, `DB_PORT=5432`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, and `DB_SSLMODE=require`.

Also set `APP_ENV=production` and `APP_DEBUG=false`. Set `LOG_CHANNEL=stderr` so Laravel sends logs to Render instead of trying to append to `storage/logs/laravel.log`. After changing environment variables, redeploy and clear any cached Laravel configuration (`php artisan config:clear`) so the service reloads the Neon URL. Keep the database URL private.

## Site configuration

- Member payments use manual transfer review. Configure PAYMENT_ACCOUNT_TELEBIRR, PAYMENT_ACCOUNT_CBE, PAYMENT_ACCOUNT_BINANCE, and PAYMENT_ACCOUNT_HOLDER in `.env`. Binance Pay also requires PAYMENT_BINANCE_ETB_PER_USDT so the app can show the exact USDT amount. Submissions stay pending until an administrator checks the transaction reference and receipt in Payment Approval.
- Run `php artisan migrate` after updating the project to add the payment currency and exchange rate fields. The ETB amount remains the amount used for Ekub balances and admin approval.
- Configure the `MAIL_*` values in `.env` to deliver payment reminders and email OTP codes. The default `MAIL_MAILER=log` writes email contents (including OTP codes) to `storage/logs/laravel.log`; it does not deliver email.
- To deliver email locally through Gmail SMTP, use your Gmail address and a provider-generated app password in `.env`:
  ```dotenv
  MAIL_MAILER=smtp
  MAIL_HOST=smtp.gmail.com
  MAIL_PORT=587
  MAIL_USERNAME=your-address@gmail.com
  MAIL_PASSWORD=your-provider-app-password
  MAIL_FROM_ADDRESS=your-address@gmail.com
  MAIL_FROM_NAME="Mekenet Ekub"
  ```
  Leave `MAIL_SCHEME` blank so Laravel chooses SMTP automatically for port 587. Use an app password, not your normal email password. Then run `php artisan config:clear` and restart `php artisan serve`.
- Uploaded images, identity documents, videos, and payment receipts are stored under `public/static/uploads`. Keep that directory writable by PHP and exclude uploaded user data from public source control.

## Included features

- Public information pages and Ekub browsing
- Member registration, login, email OTP or authenticator-app two-factor setup, profile, KYC, and payment-method management
- Ekub applications, joining and contribution shares, payment submissions, balances, late penalties, and payment history
- Admin management for Ekubs, members, KYC, payment approvals, partners, ads, applications, winners, and payouts
- Partner portal with permission-based KYC, payment, member, and winner pages
- The source site's responsive styling, theme behavior, animations, and logo

## Project notes

- `database/migrations` defines the MySQL schema. Run `php artisan migrate` after configuring a fresh database.
- No `.env`, live account values, Flask virtual environment, or Composer `vendor` directory is included. `composer install` creates `vendor` on the target machine.
- The Laravel application uses the original site's wording and presentation. Email sending requires a configured mail transport.
