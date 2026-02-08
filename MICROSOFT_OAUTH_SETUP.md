# Microsoft OAuth2 Setup Guide

## ✅ WORKING SOLUTION

**Critical Fix**: If you get "failed to fetch OAuth2 token" error:

1. **Remove** the redirect URI from the **SPA** section in Azure Portal
2. **Add** the redirect URI to the **Web** section instead
3. Ensure `isFallbackPublicClient: false` in the manifest

**Why?** PocketBase uses client secrets (confidential client), which requires the **Web** platform in Azure, not SPA (public client). Having the redirect URI in the wrong section causes token exchange to fail.

---

## Changes Made to the App

### 1. AuthStore (`lib/features/auth/auth_store.dart`)
- ✅ Added `signInWithMicrosoft()` method that uses PocketBase OAuth2
- ✅ Integrated `url_launcher` to open OAuth URL in system browser
- ✅ Commented out email/password authentication (still available in code)

### 2. LoginPage (`lib/features/auth/pages/login_page.dart`)
- ✅ Added "Logga in med Microsoft" button
- ✅ Commented out email/password input fields
- ✅ Added `handleMicrosoftLogin()` handler

## Azure Portal Configuration

### Step 1: Add Redirect URI in Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **App registrations** → Select your app
3. Go to **Authentication** → **Platform configurations**
4. Click **Add a platform** → Select **Web** (NOT "Mobile and desktop applications")
5. Add this redirect URI:
   ```
   https://school-scheduler-pb.cloud.mustini.com/api/oauth2-redirect
   ```
6. Click **Save**

### Step 2: Verify PocketBase OAuth2 Configuration

In your PocketBase admin panel (`https://school-scheduler-pb.cloud.mustini.com/_/`):

1. Go to **Settings** → **Auth providers**
2. Find **Microsoft** provider
3. Ensure these are configured:
   - **Client ID**: Your Azure App (client) ID
   - **Client Secret**: Your Azure client secret
   - **Authorize URL**: `https://login.microsoftonline.com/YOUR_DIRECTORY_TENANT_ID/oauth2/v2.0/authorize`
   - **Token URL**: `https://login.microsoftonline.com/YOUR_DIRECTORY_TENANT_ID/oauth2/v2.0/token`

Replace `YOUR_DIRECTORY_TENANT_ID` with either:
- Your specific tenant ID (e.g., `12345678-1234-1234-1234-123456789abc`)
- OR `common` for multi-tenant apps
- OR `organizations` for work/school accounts only
- OR `consumers` for personal Microsoft accounts only

**Example for common tenant:**
```
https://login.microsoftonline.com/common/oauth2/v2.0/authorize
https://login.microsoftonline.com/common/oauth2/v2.0/token
```

## How Microsoft OAuth2 Works

1. User clicks "Logga in med Microsoft" button
2. App calls `authStore.signInWithMicrosoft()`
3. PocketBase SDK requests OAuth2 auth URL from your PocketBase server
4. System browser opens with Microsoft login page
5. User authenticates with Microsoft account
6. Microsoft redirects to: `https://school-scheduler-pb.cloud.mustini.com/api/oauth2-redirect`
7. PocketBase exchanges the OAuth code for access token
8. PocketBase creates/updates user record and returns auth data
9. App receives authentication and navigates to dashboard

## Testing the Setup

### 1. Run the App (as Administrator)
```bash
flutter run -d windows
```

Or press **F5** in VSCode (running as Administrator)

### 2. Click "Logga in med Microsoft"

The system browser should open with Microsoft's login page.

### 3. Common Issues

**Issue: Browser doesn't open**
- Check that `url_launcher` package is properly installed
- Verify Windows allows the app to open browser

**Issue: "Redirect URI mismatch" error**
- Verify the redirect URI in Azure Portal matches exactly:
  `https://school-scheduler-pb.cloud.mustini.com/api/oauth2-redirect`
- Make sure it's added as a **Web** platform, not Mobile/Desktop

**Issue: "Provider not configured" error**
- Check PocketBase admin panel → Settings → Auth providers → Microsoft
- Verify Client ID and Client Secret are correct
- Check that the tenant ID in authorize/token URLs is correct

**Issue: User logs in but app doesn't navigate**
- Check browser console for errors
- Verify PocketBase can create user records in the `users` collection
- Check that the OAuth flow completes successfully in PocketBase logs

## Re-enabling Email/Password Login

If you need to re-enable email/password login:

1. In `lib/features/auth/pages/login_page.dart`:
   - Uncomment the email/password form fields (lines ~90-150)
   - Keep both Microsoft button and email/password fields

2. Both authentication methods will work simultaneously

## Azure Portal Reference

**Redirect URI Types:**
- ✅ **Web**: `https://school-scheduler-pb.cloud.mustini.com/api/oauth2-redirect` ← Use this
- ❌ **Mobile and desktop**: NOT for PocketBase OAuth2
- ❌ **Single-page application**: NOT for PocketBase OAuth2

**PocketBase OAuth2 Callback Path:**
- Always: `/api/oauth2-redirect`
- Format: `https://YOUR_POCKETBASE_URL/api/oauth2-redirect`

## Next Steps

1. ✅ Configure Azure Portal redirect URI (see Step 1 above)
2. ✅ Verify PocketBase OAuth2 settings
3. ✅ Test login with a Microsoft account
4. ✅ Verify user is created in PocketBase users collection
5. Monitor logs for any errors during OAuth flow
