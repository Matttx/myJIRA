<p align="center">
  <img src="./Sources/Assets.xcassets/AppIcon.appiconset/image%201.png" width="128" height="128" alt="myJIRA app icon">
</p>

<h1 align="center">myJIRA</h1>

<p align="center">
  A fast, native and local-first Jira Cloud client for macOS.
</p>

<p align="center">
  <a href="https://github.com/Matttx/myJIRA/releases/latest/download/myJIRA-macOS.zip"><strong>Download myJIRA for macOS</strong></a>
  ·
  <a href="https://github.com/Matttx/myJIRA/releases/latest">Release notes</a>
</p>

<p align="center">
  <img alt="Latest release" src="https://img.shields.io/github/v/release/Matttx/myJIRA?style=flat-square">
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-orange?style=flat-square&logo=swift&logoColor=white">
  <img alt="Release downloads" src="https://img.shields.io/github/downloads/Matttx/myJIRA/total?style=flat-square">
</p>

## Jira without the browser overhead

I built myJIRA because I was tired of using Jira through a web browser. Moving between pages meant more loading states, repeated API calls and a workflow that never felt like a desktop application.

myJIRA is the client I wanted instead: a focused, native macOS app that synchronizes Jira Cloud data into a local SQLite database and renders the interface from that local data. The result is a faster, calmer way to work with a backlog and board without reloading the same information on every screen.

## What you can do

- Browse your Jira Cloud workspaces and projects.
- Work from a dedicated backlog grouped by sprint.
- Reorder sprints and collapse groups to match your workflow.
- Filter issues by sprint and other issue attributes.
- Search across the current project.
- Use a Kanban board with persistent column ordering and visibility controls.
- Move issues between statuses and reorder them with drag and drop.
- Create issues and subtasks directly from the app.
- Edit summaries, descriptions and story points.
- Assign or unassign issues.
- Read issue details, subtasks, comments and change history.
- Add comments and manage issues without returning to the browser.
- Copy the canonical Jira URL for any issue.
- Refresh on demand while keeping synchronized data available locally.

## Local-first by design

myJIRA uses Jira Cloud as the source of truth, but it does not treat every screen as a new network request.

1. The app authenticates with Jira Cloud through OAuth.
2. Accessible workspaces, projects and issues are synchronized locally.
3. Data is stored in SQLite using GRDB.
4. The interface reads from local repositories and updates as synchronization completes.

This architecture reduces redundant loading, keeps navigation responsive and makes the app feel like a native desktop tool rather than a website in another window.

Authentication tokens are stored in the macOS Keychain. The local database is stored at:

```text
~/Library/Application Support/myJIRA/myjira.sqlite
```

## Requirements

- macOS 14 Sonoma or later.
- A Jira Cloud account.
- Permission to authorize the myJIRA OAuth integration for your Atlassian account.

Jira Server and Jira Data Center are not currently supported.

## Install

1. [Download the latest macOS release](https://github.com/Matttx/myJIRA/releases/latest/download/myJIRA-macOS.zip).
2. Unzip the downloaded archive.
3. Move `myJIRA.app` to your Applications folder.
4. Open myJIRA and choose **Connect with Atlassian**.
5. Approve access in the Atlassian authorization window.

The downloadable app is signed with a Developer ID certificate. The current GitHub build is not yet notarized by Apple, so macOS may block the first launch. If that happens, open **System Settings → Privacy & Security**, find the myJIRA notice and choose **Open Anyway**. You only need to do this once.

## First release

Version **1.1 (build 6)** is the first downloadable public release of myJIRA. It includes the native backlog, Kanban workflow, issue editing, Jira URL sharing and the local-first synchronization foundation.

[Read the full release notes](https://github.com/Matttx/myJIRA/releases/tag/1.1)

## Build from source

You need Xcode with the macOS 14 SDK or later.

Create an OAuth 2.0 integration in the [Atlassian Developer Console](https://developer.atlassian.com/console/myapps/) with the following configuration:

```text
Callback URL: myjira://oauth/callback
Scopes: read:jira-user read:jira-work write:jira-work offline_access
```

Enable sharing for the integration if other Atlassian accounts need to authorize it. Then create the local secrets configuration:

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

Add the OAuth client ID and secret to `Secrets.xcconfig`, then open the Xcode project:

```bash
open myJIRA.xcodeproj
```

You can also build and launch from Terminal:

```bash
./script/build_and_run.sh
```

## Technology

- Swift and SwiftUI
- Native macOS navigation and inspector layouts
- SQLite persistence through GRDB
- OAuth with `ASWebAuthenticationSession`
- Secure token storage in Keychain
- Clean Architecture with MVVM at the presentation layer

## Privacy

Jira data is cached locally to provide the local-first experience. Disconnecting Jira removes the synchronized Jira data and the local personal-data reporting index.

myJIRA reports stored Atlassian account references through Jira's Personal Data Reporting API when required. If Atlassian reports an account as closed or updated, locally stored profile fields associated with that account are removed from issues, comments and changelog entries.

## Feedback

Found a bug or have an idea? [Open a GitHub issue](https://github.com/Matttx/myJIRA/issues/new).

myJIRA is an independent project and is not affiliated with or endorsed by Atlassian.
