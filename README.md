# Server scripts to monitoring, Cloudflare actions and backups

## 1. CPU Monitor

### Overview

This process will allow you to monitor the CPU of your Linux server and send alerts via Telegram when CPU usage exceeds a specific percentage. You can adjust the threshold and monitoring interval according to your needs.

### Make the script run automatically.

If you want the script to run continuously, you can configure it as a `systemd` service to start automatically with the server.

Make executable the script file:

```
chmod +x cpu_monitor.sh
```

Create a service file in `/etc/systemd/system/cpu_monitor.service`:

```
[Unit]
Description=CPU Monitor with Telegram alert

[Service]
ExecStart=/path/to/script/cpu_monitor.sh
# If we have problems on service start, we can log start servive.
#ExecStart=/path/to/script/cpu_monitor.sh >> /tmp/cpu_monitor.log 2>&1
User=root
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Reload the `systemd` services and enable the service to start at boot time:

```
sudo systemctl daemon-reload
sudo systemctl enable cpu_monitor.service
sudo systemctl start cpu_monitor.service
```

Reload the `systemd` services on script changes (git updates):

```
sudo systemctl daemon-reload
sudo systemctl restart cpu_monitor.service
```

### Full porcess for update:

1. Revert executable script state to non-executable:

```
git restore cpu_monitor.sh
```

2. Check that repo is up-to-date and update local repository.

```
git status
git pull
```

3. Make script exceutable again:


```
chmod +x cpu_monitor.sh
```

4. Restart service.

```
sudo systemctl daemon-reload
sudo systemctl restart cpu_monitor.service
```

## 2. Cloudflare Firewall events

### Overview

This process will allow you to monitor the Cloudflare Firewall events of your website and send alerts via Telegram when events number in the last 24 hours exceeds a specific number. You can adjust the threshold and monitoring interval according to your needs.

### Make the script run automatically.

If you want the script to run continuously, you can configure it as a `systemd` service to start automatically with the server.

Make executable the script file:

```
chmod +x cloudflare_events.sh
```

Create a service file in `/etc/systemd/system/cloudflare_events.service`:

```
[Unit]
Description=Cloudflare Firewall Events Monitor with Telegram alert

[Service]
ExecStart=/path/to/script/cloudflare_events.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

Reload the `systemd` services and enable the service to start at boot time:

```
sudo systemctl daemon-reload
sudo systemctl enable cloudflare_events.service
sudo systemctl start cloudflare_events.service
```
### Dependencies

This script need to have installed `jq` to parse JSON response. `jq`is installed by default in GridPane instances, but not installed by default in other servers.

To install it, you need to execute:

```
sudo apt-get install jq
```
