module.exports = {
  apps: [
    {
      name: "lingoy-api",
      cwd: "/srv/lingoy/current/server",
      script: "src/index.js",
      node_args: "--env-file=/srv/lingoy/shared/.env",
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      kill_timeout: 15000,
      max_memory_restart: "450M",
      time: true,
      out_file: "/srv/lingoy/shared/logs/api.out.log",
      error_file: "/srv/lingoy/shared/logs/api.error.log",
      env: {
        NODE_ENV: "production",
        RELEASE_ID: require("node:path").basename(
          require("node:fs").realpathSync("/srv/lingoy/current"),
        ),
      },
    },
  ],
};
