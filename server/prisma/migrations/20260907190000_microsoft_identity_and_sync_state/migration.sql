-- Add Microsoft identity linking and provider-owned incremental sync state.
ALTER TABLE `User`
  ADD COLUMN `microsoftSubject` VARCHAR(255) NULL;

CREATE UNIQUE INDEX `User_microsoftSubject_key`
  ON `User`(`microsoftSubject`);

ALTER TABLE `EmailAccount`
  ADD COLUMN `providerSyncState` JSON NULL;
