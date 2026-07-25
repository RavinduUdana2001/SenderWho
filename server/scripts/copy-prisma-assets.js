const { cpSync, existsSync, mkdirSync, rmSync } = require("node:fs");
const path = require("node:path");

const projectRoot = path.resolve(__dirname, "..");
const source = path.join(projectRoot, "prisma");
const destination = path.join(projectRoot, "dist", "prisma");

if (!existsSync(path.join(source, "schema.prisma"))) {
  throw new Error("Cannot package Prisma assets: prisma/schema.prisma is missing.");
}

rmSync(destination, { recursive: true, force: true });
mkdirSync(path.dirname(destination), { recursive: true });
cpSync(source, destination, { recursive: true });
