# Buvvas Thermal Printer Driver — Setup & Distribution Guide

## 📦 Package Contents

```
Buvvas-Driver-Package/
├── installer/
│   └── BuvvasSetup.iss          # Inno Setup script → compile to .exe on Windows
├── driver-files/
│   ├── config.ini                # Buvvas-branded installer config
│   ├── DriverSetup.exe           # Original driver installer (used internally)
│   ├── SETUP_ENG/                # 32-bit driver files (rebranded)
│   └── SETUP64_ENG/              # 64-bit driver files (rebranded)
└── license-server/
    ├── server.js                 # License API + Admin dashboard server
    ├── database.js               # SQLite database layer
    ├── index.html                # Admin dashboard UI
    ├── package.json              # Node.js dependencies
    └── .env                      # Configuration (API keys, secrets)
```

---

## 🚀 Quick Start

### 1. Start the License Server

```bash
cd license-server
npm install          # First time only
npm start            # Starts on http://localhost:3000
```

Open http://localhost:3000 in your browser to access the admin dashboard.

### 2. Configure the Admin Dashboard

1. Open the dashboard at http://localhost:3000
2. Enter the API key (default: `buvvas-admin-secret-change-me`)
3. Click **Save** — the key is stored in your browser

### 3. Generate License Keys

1. In the dashboard, go to **Generate Keys**
2. Set the number of keys to generate
3. Optionally enter a customer name and notes
4. Click **Generate** → keys appear in format `BUVVAS-XXXX-XXXX-XXXX`
5. Copy and share keys with your customers

### 4. Compile the Windows Installer

> ⚠️ This step requires a **Windows PC** with Inno Setup 6 installed.

1. Download & install [Inno Setup 6](https://jrsoftware.org/isinfo.php) (free)
2. Copy the entire `Buvvas-Driver-Package` folder to your Windows PC
3. Open `installer/BuvvasSetup.iss` in Inno Setup Compiler
4. **Update the license server URL** on line 12:
   ```
   #define LicenseServerURL "https://your-server.com"
   ```
5. *(Optional)* Add your logo BMP files in `installer/assets/` and uncomment the logo lines in the `[Setup]` section
6. Press **Ctrl+F9** to compile → creates `BuvvasDriverSetup_v1.0.0.exe`
7. Distribute the `.exe` to your customers

### 5. Customer Installation Flow

1. Customer runs `BuvvasDriverSetup_v1.0.0.exe`
2. Welcome page → clicks **Next**
3. License Key page → enters their `BUVVAS-XXXX-XXXX-XXXX` key
4. Clicks **Activate Online** → validated against your server
5. If no internet → clicks **Offline Activation**:
   - Notes their Machine Code (e.g., `A1B2-C3D4-E5F6`)
   - Contacts Buvvas support with License Key + Machine Code
   - You generate an Activation Code in the dashboard
   - Customer enters the Activation Code → activated
6. Driver files are installed → printer appears in Windows

---

## 🔐 License System Details

### Online Activation
- Customer's license key is bound to their machine's **Windows Machine GUID**
- One key = one machine (reinstall on same machine is allowed)
- You can revoke or reset keys from the dashboard

### Offline Activation
- Uses **HMAC-SHA256** cryptographic signatures
- Machine Code = formatted Windows Machine GUID (unique per PC)
- Activation Code = HMAC(secret, key + machineCode) → first 16 chars
- Even without internet, the code is cryptographically verified

### Key Format
```
BUVVAS-XXXX-XXXX-XXXX
```
Characters used: `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no ambiguous 0/O/1/I/L)

---

## 🌐 Deploying the License Server

### For Testing (Local)
```bash
cd license-server && npm start
```
Dashboard: http://localhost:3000

### For Production (Free Tier Options)

#### Railway.app (Recommended)
1. Push `license-server/` to a GitHub repo
2. Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub
3. Set environment variables in Railway dashboard:
   - `PORT` = 3000
   - `ADMIN_API_KEY` = (choose a strong secret)
   - `ACTIVATION_SECRET` = (choose a different strong secret)
4. Railway gives you a public URL (e.g., `https://buvvas-license.up.railway.app`)
5. Update `LicenseServerURL` in `BuvvasSetup.iss` with this URL

#### Render.com
1. Similar steps — deploy from GitHub, set env vars
2. Free tier available with some limitations

---

## ⚙️ Configuration

### .env File
```env
PORT=3000                                    # Server port
ADMIN_API_KEY=buvvas-admin-secret-change-me  # Change this! Admin dashboard access
ACTIVATION_SECRET=buvvas-offline-secret-change-me  # Change this! Offline code signing
```

> ⚠️ **IMPORTANT**: Change both secrets before deploying to production!

### Installer Branding (BuvvasSetup.iss)

| Setting | Line | Purpose |
|---------|------|---------|
| `LicenseServerURL` | 12 | Your license server URL |
| `WizardImageFile` | — | Sidebar logo (164×314 BMP) |
| `WizardSmallImageFile` | — | Header logo (150×57 BMP) |
| `SetupIconFile` | — | Installer icon (.ico) |

### Contact Info (BuvvasSetup.iss)
Update the support contact info in the offline activation page (search for `support@buvvas.com`).

---

## 🔧 Admin API Reference

All admin endpoints require `x-api-key` header.

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| POST | `/api/validate` | `{key, hardwareId}` | Validate & activate key |
| POST | `/api/validate-offline` | `{key, machineCode, activationCode}` | Offline validation |
| POST | `/api/admin/keys/generate` | `{count, customerName, notes}` | Generate keys |
| GET | `/api/admin/keys?status=&search=` | — | List all keys |
| POST | `/api/admin/keys/:key/revoke` | — | Revoke a key |
| POST | `/api/admin/keys/:key/reset` | — | Reset key to unused |
| POST | `/api/admin/offline/generate` | `{licenseKey, machineCode}` | Generate offline code |
| GET | `/api/admin/stats` | — | Get key statistics |
