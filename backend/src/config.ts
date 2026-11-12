export type Config = {
  databaseUrl: string;
  port: number;
  nodeEnv: "development" | "production" | "test";
  jwtSecret: string;
  gemmaApiKey: string;
};

// Read once at startup so a missing variable fails on boot rather than on the
// first request that happens to need it.
export const config: Config = loadConfig();

function loadConfig(): Config {
  return {
    databaseUrl: requireEnv("DATABASE_URL"),
    port: Number(process.env.PORT ?? 3000),
    nodeEnv: readNodeEnv(),
    jwtSecret: requireEnv("JWT_SECRET"),
    gemmaApiKey: process.env.GEMMA_API_KEY ?? "",
  };
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (value === undefined || value === "") {
    throw new Error(`${name} is not set. Copy backend/.env.example to backend/.env.`);
  }
  return value;
}

function readNodeEnv(): Config["nodeEnv"] {
  const value = process.env.NODE_ENV ?? "development";
  if (value !== "development" && value !== "production" && value !== "test") {
    throw new Error(`NODE_ENV must be development, production or test, got ${value}`);
  }
  return value;
}
