import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { PrismaService } from "../database/prisma.service";
import { TokenEncryptionService } from "../common/security/token-encryption.service";
import { GmailClient } from "../providers/gmail/gmail.client";
import { InboxJobsService } from "../jobs/inbox-jobs.service";
import { AuthService } from "./auth.service";

describe("sign-in profile identity", () => {
  const setup = (existing?: Record<string, unknown>) => {
    const user = {
      findFirst: jest.fn().mockResolvedValue(existing ?? null),
      findUnique: jest
        .fn()
        .mockResolvedValue(existing ? { id: existing.id } : null),
      create: jest
        .fn()
        .mockImplementation(async ({ data }) => ({ id: "user-1", ...data })),
      update: jest
        .fn()
        .mockImplementation(async ({ data }) => ({ ...existing, ...data })),
    };
    const service = new AuthService(
      new ConfigService(),
      new JwtService({ secret: "test-secret" }),
      { user } as unknown as PrismaService,
      {} as GmailClient,
      {} as TokenEncryptionService,
      {} as InboxJobsService,
    );
    return { service, user };
  };

  it("persists supplied verified Google name and photo for a new user", async () => {
    const { service, user } = setup();
    await service["resolveGoogleUser"](
      "google-1",
      "Owner@Example.com",
      undefined,
      { name: "Ravindu Test", picture: "https://images.example.com/photo.png" },
    );
    expect(user.create).toHaveBeenCalledWith({
      data: {
        email: "owner@example.com",
        googleSubject: "google-1",
        displayName: "Ravindu Test",
        avatarUrl: "https://images.example.com/photo.png",
      },
    });
  });

  it("keeps a saved photo when a later sign-in omits optional claims", async () => {
    const { service, user } = setup({
      id: "user-1",
      email: "owner@example.com",
      googleSubject: "google-1",
      displayName: "Ravindu Test",
      avatarUrl: "https://images.example.com/saved.png",
    });
    await service["resolveGoogleUser"]("google-1", "owner@example.com");
    expect(user.update).toHaveBeenCalledWith({
      where: { id: "user-1" },
      data: {
        email: "owner@example.com",
        googleSubject: "google-1",
        displayName: "Ravindu Test",
        avatarUrl: "https://images.example.com/saved.png",
      },
    });
  });

  it("falls back cleanly when a provider photo cannot be displayed", async () => {
    const { service, user } = setup();
    await service["resolveGoogleUser"](
      "google-1",
      "owner@example.com",
      undefined,
      { picture: "http://images.example.com/photo.png" },
    );
    expect(user.create.mock.calls[0][0].data.avatarUrl).toBeUndefined();
  });
});
