# c2tool

Fill in deploy_cosmog.toml.example, rename to deploy_cosmog.toml

Put these files in your cosmog directory, the one that contains docker-compose.yml

Run:

pm2 stop send_configs

pm2 stop houndour

Then (after filling in and renaming deploy_cosmog.toml.example)

chmod +x deploy_cosmog.sh

./deploy_cosmog.sh

chmod +x generate_pm2_processes.sh

./generate_pm2_processes.sh

**Use at your own risk.**
