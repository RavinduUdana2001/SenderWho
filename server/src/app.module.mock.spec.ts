import { Test } from "@nestjs/testing";

describe("AppModule mock-mode wiring", () => {
  const originalMockMode = process.env.MOCK_DATA_ENABLED;

  beforeAll(() => {
    process.env.MOCK_DATA_ENABLED = "true";
  });

  afterAll(() => {
    if (originalMockMode === undefined) {
      delete process.env.MOCK_DATA_ENABLED;
    } else {
      process.env.MOCK_DATA_ENABLED = originalMockMode;
    }
  });

  it("initializes every module without MySQL or Google credentials", async () => {
    const { AppModule } = await import("./app.module");
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    await expect(moduleRef.init()).resolves.toBeDefined();
    await moduleRef.close();
  });
});
