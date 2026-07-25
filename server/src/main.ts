import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import compression from "compression";
import { createConnection } from "node:net";
import type { NextFunction, Request, Response } from "express";
import { json, urlencoded } from "express";
import helmet from "helmet";
import { applyMysqlMigrations } from "./common/database/mysql-migrations";

async function bootstrap() {
  configureHostingerDatabaseUrl();
  await checkDatabaseTcpConnection();
  console.log(JSON.stringify({ event: "application.starting" }));
  const { AppModule } = await import("./app.module");
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
    bodyParser: false,
  });
  const config = app.get(ConfigService);
  const apiPrefix = config.get<string>("apiPrefix", "api/v1");
  const corsOrigins = config.get<string[]>("corsOrigins", []);
  const isProduction = config.get<string>("nodeEnv") === "production";
  const trustedProxyHops = config.get<number>("http.trustedProxyHops", 0);
  const requestBodyLimit = config.get<string>("http.requestBodyLimit", "256kb");

  app.enableShutdownHooks();

  const expressApp = app.getHttpAdapter().getInstance();
  expressApp.set("trust proxy", trustedProxyHops);

  app.setGlobalPrefix(apiPrefix);
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'none'"],
          styleSrc: ["'unsafe-inline'"],
          baseUri: ["'none'"],
          frameAncestors: ["'none'"],
          formAction: ["'none'"],
        },
      },
      crossOriginResourcePolicy: { policy: "same-site" },
      referrerPolicy: { policy: "no-referrer" },
    }),
  );
  app.use((_request: Request, response: Response, next: NextFunction) => {
    response.setHeader("Cache-Control", "no-store, max-age=0");
    response.setHeader("Pragma", "no-cache");
    next();
  });
  app.use(compression());
  if (isProduction) {
    app.use((request: Request, response: Response, next: NextFunction) => {
      if (request.secure) return next();
      response.status(426).json({
        statusCode: 426,
        message: "HTTPS is required.",
      });
    });
  }
  app.use(json({ limit: requestBodyLimit, strict: true }));
  app.use(urlencoded({ extended: false, limit: requestBodyLimit }));
  app.enableCors({
    origin: corsOrigins.length > 0 ? corsOrigins : !isProduction,
    credentials: false,
    methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Authorization",
      "Content-Type",
      "Idempotency-Key",
      "X-Request-Id",
      "X-SenderWho-Device-Id",
      "X-SenderWho-Device-Name",
    ],
    exposedHeaders: ["X-Request-Id"],
    maxAge: 600,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  if (config.get<boolean>("http.swaggerEnabled", !isProduction)) {
    const swaggerConfig = new DocumentBuilder()
      .setTitle("SenderWho API")
      .setDescription(
        "Development API documentation for sender intelligence and inbox cleanup.",
      )
      .setVersion("0.1.0")
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup(`${apiPrefix}/docs`, app, document);
  }

  const port = config.get<number>("port", 3000);
  await app.listen(port, "0.0.0.0");
  console.log(
    JSON.stringify({ event: "application.listening", host: "0.0.0.0", port }),
  );
  if (process.env.NODE_ENV === "production") {
    console.log(JSON.stringify({ event: "database.migrations.starting" }));
    await applyMysqlMigrations();
    console.log(JSON.stringify({ event: "database.migrations.completed" }));
  }
  console.log(JSON.stringify({ event: "application.ready" }));
}

void bootstrap().catch((error: unknown) => {
  const details =
    error instanceof Error
      ? { name: error.name, message: error.message, stack: error.stack }
      : { message: String(error) };
  const message = error instanceof Error ? error.message : String(error);
  if (message.includes("Authentication failed against database server")) {
    console.error(
      JSON.stringify({
        event: "database.authentication_failed",
        diagnosis:
          "MySQL was reachable but rejected the username/password. Verify the hPanel MySQL user assignment and that the deployed DB_PASSWORD is current.",
      }),
    );
  }
  console.error(
    JSON.stringify({ event: "application.startup_failed", ...details }),
  );
  process.exit(1);
});

function configureHostingerDatabaseUrl(): void {
  if (process.env.HOSTINGER_SHARED_HOSTING !== "true") return;
  const user = process.env.DB_USER?.trim();
  const password = process.env.DB_PASSWORD;
  const database = process.env.DB_NAME?.trim();
  const configuredHost = process.env.DB_HOST?.trim() || "localhost";
  const host = configuredHost === "localhost" ? "127.0.0.1" : configuredHost;
  const port = process.env.DB_PORT?.trim() || "3306";
  if (!user || password === undefined || !database) {
    console.error(
      JSON.stringify({
        event: "database.configuration.incomplete",
        hasUser: Boolean(user),
        hasPassword: password !== undefined,
        hasDatabase: Boolean(database),
      }),
    );
    return;
  }

  process.env.DATABASE_URL = `mysql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${encodeURIComponent(database)}`;
  console.log(
    JSON.stringify({
      event: "database.configuration.loaded",
      source: "separate_variables",
      host,
      port,
      user,
      database,
      passwordLength: password.length,
      passwordHasLeadingOrTrailingWhitespace: password !== password.trim(),
    }),
  );
}

async function checkDatabaseTcpConnection(): Promise<void> {
  if (process.env.MOCK_DATA_ENABLED === "true") return;
  const configuredHost = process.env.DB_HOST?.trim() || "localhost";
  const host = configuredHost === "localhost" ? "127.0.0.1" : configuredHost;
  const parsedPort = Number(process.env.DB_PORT?.trim() || "3306");
  const port = Number.isInteger(parsedPort) ? parsedPort : 3306;
  const startedAt = Date.now();

  await new Promise<void>((resolve, reject) => {
    const socket = createConnection({ host, port });
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(
        new Error(
          `Timed out connecting to MySQL TCP endpoint ${host}:${port}.`,
        ),
      );
    }, 5000);
    socket.once("connect", () => {
      clearTimeout(timeout);
      socket.destroy();
      console.log(
        JSON.stringify({
          event: "database.tcp_connection.succeeded",
          host,
          port,
          durationMs: Date.now() - startedAt,
        }),
      );
      resolve();
    });
    socket.once("error", (error) => {
      clearTimeout(timeout);
      reject(
        new Error(
          `Cannot reach MySQL TCP endpoint ${host}:${port}: ${error.message}`,
        ),
      );
    });
  });
}
