package com.app.demo

import android.app.backup.BackupAgent
import android.app.backup.BackupDataInput
import android.app.backup.BackupDataOutput
import android.os.ParcelFileDescriptor

/**
 * Backup agent whose only job is to notice that a restore finished.
 *
 * Restore Credentials retrieval has to happen after a system restore, and
 * Android's documentation is explicit that onRestore is the wrong hook - it
 * fires only for key-value backups, whereas onRestoreFinished fires for any
 * kind of restore. This process has no Flutter engine, so the agent records a
 * flag and base_sdk's RestoreCredentialService.consumeRestoreSignal() reads
 * it on the next launch.
 *
 * The key-value callbacks below are intentionally empty: this app uses Auto
 * Backup only. The manifest pairs android:backupAgent with
 * android:fullBackupOnly="true" for exactly that reason - declaring an agent
 * without it would switch the app to key-value backup, where these no-ops
 * would back up nothing and res/xml/data_extraction_rules.xml and
 * res/xml/backup_rules.xml would be ignored entirely. The inherited
 * onFullBackup / onRestoreFile are NOT overridden, so Auto Backup keeps
 * applying those rules exactly as it does without an agent.
 */
class RokctBackupAgent : BackupAgent() {

    override fun onBackup(
        oldState: ParcelFileDescriptor?,
        data: BackupDataOutput?,
        newState: ParcelFileDescriptor?,
    ) {
        // Key-value backup is unused; Auto Backup handles this app.
    }

    override fun onRestore(
        data: BackupDataInput?,
        appVersionCode: Int,
        newState: ParcelFileDescriptor?,
    ) {
        // Key-value restore is unused; see onRestoreFinished below.
    }

    override fun onRestoreFinished() {
        super.onRestoreFinished()
        RestoreCredentialBridge.markRestoreFinished(applicationContext)
    }
}
