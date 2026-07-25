ALTER TABLE `Sender`
  ADD COLUMN `identityStatus` ENUM('VERIFIED', 'UNVERIFIED', 'SUSPICIOUS') NOT NULL DEFAULT 'UNVERIFIED',
  ADD COLUMN `identityRiskLevel` ENUM('LOW', 'REVIEW', 'POSSIBLE_IMPERSONATION', 'HIGH') NOT NULL DEFAULT 'LOW',
  ADD COLUMN `identityRiskScore` INTEGER NOT NULL DEFAULT 0;

ALTER TABLE `Message`
  ADD COLUMN `identityRiskScore` INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN `identityRiskLevel` ENUM('LOW', 'REVIEW', 'POSSIBLE_IMPERSONATION', 'HIGH') NOT NULL DEFAULT 'LOW',
  ADD COLUMN `identityStatus` ENUM('VERIFIED', 'UNVERIFIED', 'SUSPICIOUS') NOT NULL DEFAULT 'UNVERIFIED',
  ADD COLUMN `identityEvidence` JSON NULL,
  ADD COLUMN `claimedBrand` VARCHAR(80) NULL,
  ADD COLUMN `authenticatedDomain` VARCHAR(255) NULL,
  ADD COLUMN `replyToEmail` VARCHAR(320) NULL;

CREATE INDEX `Message_userId_identityRiskLevel_idx`
  ON `Message`(`userId`, `identityRiskLevel`);
CREATE INDEX `Message_senderId_identityRiskScore_idx`
  ON `Message`(`senderId`, `identityRiskScore`);
