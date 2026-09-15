ALTER TABLE `EmailAccount`
  ADD COLUMN `isPrimary` BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX `EmailAccount_userId_isPrimary_idx`
  ON `EmailAccount`(`userId`, `isPrimary`);
