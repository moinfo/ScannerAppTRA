module.exports = {
  apps: [
    {
      name: 'server',
      script: './server.js',
      instances: 1,
      exec_mode: 'fork',
      node_args: '--no-deprecation',
      max_memory_restart: '1G',
      error_file: '~/.pm2/logs/server-error.log',
      out_file: '~/.pm2/logs/server-out.log',
      merge_logs: true,
      time: true,
      env: {
        NODE_ENV: 'production',
        PMX_DISABLED: true
      }
    }
  ]
};