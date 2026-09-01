# SnowRoles テストRelease補助ツール

これらのツールは、Buildと実機確認が完了したSnowRoles DLLをテスト配布用にまとめるためのものです。GitHub ReleaseのPublishとAsset追加は、GitHub Web画面から手動で行います。

## 前提

- `C:\AmongUsMod\SnowRoles` がcleanであること
- Release DLLとAmong Usへ実機導入したDLLのSize・SHA-256が一致していること
- `git.exe`、`curl.exe`、`certutil.exe`、`tar.exe` が利用できること
- 既存のrelease-workや最終ZIPは上書きされません
- スクリプト内ではBuildを行いません

## test.4での使用例

### STEP 1: Release用READMEを準備

次のファイルを事前に作成します。

`C:\AmongUsMod\release-input\v0.9.0-test.4\README.txt`

READMEには新しいtag、変更点、確認状況を記載します。前回tagの表記を残さないでください。

### STEP 2: 実機確認済みDLLを揃える

次の2ファイルが完全に同じ状態にします。

- `C:\AmongUsMod\SnowRoles\bin\Release\net6.0\SnowRoles.dll`
- `C:\Program Files (x86)\Steam\steamapps\common\Among Us\BepInEx\plugins\SnowRoles.dll`

Among Usの場所は固定Pathだけを使用し、別の場所は探索しません。

### STEP 3: 配布ZIPを準備

```bat
tools\prepare-test-release.cmd v0.9.0-test.4 v0.9.0-test.3
```

前回Public ReleaseのAsset情報を検証し、staging、DLLとREADMEの差し替え、SHA256SUMS再生成、最終ZIP作成と検証を行います。成功してもtag作成やGitHub公開は行いません。

### STEP 4: Release Notesを準備

`C:\AmongUsMod\release-work\v0.9.0-test.4\RELEASE_SUMMARY.txt` の次の値を使い、ChatGPTでRelease Notesを作成します。

- Source commit
- Final ZIP SHA-256

### STEP 5: lightweight tagをpush

```bat
tools\push-test-tag.cmd v0.9.0-test.4
```

Release repositoryのmainとorigin/mainが一致し、ArtifactとSummaryが存在する場合だけ、lightweight tagを作成してそのtag 1件だけをpushします。

### STEP 6: GitHub WebでPublish

- Tag: `v0.9.0-test.4`
- Release title: `SnowRoles v0.9.0 test.4`
- Release label: Pre-release
- Asset: `SnowRoles-v0.9.0-test.4-Steam.zip`

Release NotesとAssetを確認してからPublishします。

### STEP 7: Public Releaseを検証

```bat
tools\verify-public-release.cmd v0.9.0-test.4
```

Public GitHub APIのtag、Pre-release設定、Asset数、Filename、状態、Size、digestをLocal Artifactと照合します。この処理はGitHubを変更しません。

## 失敗時

各ツールは問題が見つかった時点で非0のExit codeを返します。自動的な再試行、作業ディレクトリの削除、成果物の上書き、巻き戻しは行いません。表示された失敗地点と理由を確認してから、手動で原因を調査してください。
