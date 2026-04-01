import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(__dirname, "../..");
const skillsDir = path.join(pluginRoot, "skills");
const runCommand = path.join(
  pluginRoot,
  "scripts",
  process.platform === "win32" ? "run.cmd" : "run.sh",
);

export const LumenPlugin = async () => {
  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }

      config.mcp = config.mcp || {};
      if (!config.mcp.lumen) {
        config.mcp.lumen = {
          type: "local",
          command: [runCommand, "stdio"],
          enabled: true,
        };
      }
    },
  };
};

export default LumenPlugin;
