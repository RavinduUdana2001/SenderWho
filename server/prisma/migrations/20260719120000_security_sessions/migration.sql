ALTER TABLE `AppSession`
    ADD COLUMN `familyId` VARCHAR(64) NULL,
    ADD COLUMN `parentId` VARCHAR(191) NULL,
    ADD COLUMN `replacedById` VARCHAR(191) NULL,
    ADD COLUMN `authenticatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ADD COLUMN `revocationReason` VARCHAR(64) NULL,
    ADD COLUMN `deviceIdHash` VARCHAR(64) NULL,
    ADD COLUMN `deviceName` VARCHAR(120) NULL;

UPDATE `AppSession` SET `familyId` = `id` WHERE `familyId` IS NULL;

ALTER TABLE `AppSession` MODIFY `familyId` VARCHAR(64) NOT NULL;
CREATE INDEX `AppSession_familyId_revokedAt_idx` ON `AppSession`(`familyId`, `revokedAt`);

ALTER TABLE `OAuthLoginSession`
    ADD COLUMN `purpose` VARCHAR(32) NOT NULL DEFAULT 'LOGIN',
    ADD COLUMN `pkceVerifierEncrypted` TEXT NULL,
    ADD COLUMN `nonceHash` VARCHAR(64) NULL;

UPDATE `OAuthLoginSession`
SET `pkceVerifierEncrypted` = '', `nonceHash` = ''
WHERE `pkceVerifierEncrypted` IS NULL OR `nonceHash` IS NULL;

ALTER TABLE `OAuthLoginSession`
    MODIFY `pkceVerifierEncrypted` TEXT NOT NULL,
    MODIFY `nonceHash` VARCHAR(64) NOT NULL;
