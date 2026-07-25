import { SettingsService } from "./settings.service";

describe("SettingsService", () => {
  it("returns the persisted preference state when audit storage is unavailable", async () => {
    const settings = {
      notificationsEnabled: false,
      inboxScanFrequency: "DAILY",
      theme: "DARK",
    };
    const prisma = {
      userSettings: {
        upsert: jest.fn().mockResolvedValue(settings),
        update: jest.fn().mockResolvedValue(settings),
      },
      emailAccount: { count: jest.fn().mockResolvedValue(1) },
      message: { count: jest.fn().mockResolvedValue(0) },
      sender: { count: jest.fn().mockResolvedValue(0) },
      auditLog: {
        create: jest.fn().mockRejectedValue(new Error("audit unavailable")),
      },
    };
    const service = new SettingsService(prisma as never);

    await expect(
      service.updatePreferences("user-1", {
        notificationsEnabled: false,
        inboxScanFrequency: "DAILY",
        theme: "DARK",
      }),
    ).resolves.toMatchObject({ preferences: settings });
    expect(prisma.userSettings.update).toHaveBeenCalledTimes(1);
  });
});
