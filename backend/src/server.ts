import { createApp } from "./app.js";
import { config } from "./config.js";

createApp().listen(config.port, () => {
  console.log(`malas backend on :${config.port} (${config.nodeEnv})`);
});
