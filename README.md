# myJIRA

Minimal macOS Jira client with a local-first data model.

## Direction

- Native macOS app built with SwiftUI.
- Local-first cache using SQLite through GRDB.
- Jira Cloud data is synchronized into local storage, then the UI reads from local repositories.
- Clean Architecture shape with Presentation, Domain, Data, and Infrastructure layers.
- MVVM for screens and a small typed router for desktop selection state.
- No unit tests for now.

## First Milestones

1. Jira Cloud OAuth with `ASWebAuthenticationSession`.
2. Secure token storage in Keychain.
3. Fetch accessible Jira cloud workspaces.
4. Fetch projects and persist them locally.
5. Fetch backlog issues with JQL and persist them locally.
6. Add polling refresh based on Jira `updated` timestamps.

## Jira OAuth Setup

Create an OAuth 2.0 integration in the Atlassian Developer Console and configure:

```text
Callback URL: myjira://oauth/callback
Scopes: read:jira-user read:jira-work write:jira-work offline_access
```

Enable sharing for the integration in the Atlassian Developer Console so other
Atlassian accounts can authorize the app.

Copy the local build configuration template and fill in the shared OAuth app credentials:

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

`Secrets.xcconfig` is ignored by Git. The credentials are embedded in the built app,
so users only need to click **Se connecter avec Atlassian** and authorize their own account.

After OAuth succeeds, the app currently syncs accessible Jira workspaces and their projects into the local GRDB cache.

## Atlassian personal data reporting

myJIRA reports locally stored Atlassian account references through the Jira
Personal Data Reporting API. Reporting runs when the app is active and an
account is due, in batches of at most 90 accounts. The default cycle is seven
days, or the period returned by Atlassian.

When Atlassian returns `closed` or `updated`, myJIRA removes that account's
stored profile fields (display names and account IDs) from issues, comments,
and changelog entries. Disconnecting Jira removes the local reporting index
along with the synchronized Jira data.

## Run

Open the project in Xcode:

```bash
open myJIRA.xcodeproj
```

The canonical project is now `myJIRA.xcodeproj`. Use the Codex Run action or:

```bash
./script/build_and_run.sh
```

The local database is stored under:

```text
~/Library/Application Support/myJIRA/myjira.sqlite
```
