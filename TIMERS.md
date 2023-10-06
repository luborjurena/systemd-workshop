## Časovač spustenia služby v stanovenom čase
Tradične sme na túto úlohu používali cron. V systemd môžeme vytvoriť "Timer unit", v ktorej špecifikujeme kedy spustiť službu. Systemd narozdiel od cronu umožňuje vytvoriť časovač aj s kratším intervalom ako 1min.

```
[~]: systemctl edit --force --full count.timer
```
```
[Unit]
Description=Moja prvá naplánovaná úloha

[Timer]
OnCalendar=*-*-* *:*:00/30

[Install]
WantedBy=timers.target
```

```
[~]: systemctl start count.timer 
[~]: watch -n1 systemctl status count.{timer,service}
```

## Monotónny časovač

Monotónny čas nie je naviazaný na systémové hodiny, ale odvíja sa od určeného času v minulosti - napr. podmienka: 5min po štarte OS alebo 5min po vypnutí služby, atp.

Následujúcim spôsobm zadefinujeme, aby sa služba opätovne spustila 15s po jej vypnutí:
```
[~]: systemctl edit --force --full count.timer
```
```
[Unit]
Description=Moja prvá naplánovaná úloha

[Timer]
OnUnitInactiveSec=15s

[Install]
WantedBy=timers.target
```

## Dočasné časovače

Systemd aj v tomto prípade umožňuje vytvoriť dočasné - jednorázové úlohy:
```
[~]: systemd-run --on-active=30 /bin/touch /tmp/test.txt
```
Takto zadefinovaná úloha vytvorí o 30s súbor /tmp/test.txt a následne zanikne.

## Náhodné oneskorenie

Každý časovač môžeme doplniť o `RandomizedDelaySec=` alebo o `FixedRandomDelay=`.

## Monitorovanie zmien

Môžeme vytvoriť časovač, ktorý bude monitorovať zmeny súboru:
```
[~]: systemctl edit --full --force ssh-config-watcher.path
```

```
[Unit]
Description=Sleduj zmeny v /etc/ssh/sshd_config

[Path]
PathChanged=/etc/ssh/sshd_config

[Install]
WantedBy=multi-user.target
```
Následne vytvoríme novú službu, ktorá bude spustená po zmene súboru a vykoná reload ssh:

```
[~]: systemctl edit --full --force ssh-config-watcher.service
```
```
[Unit]
Description=reload sshd when configuration changes
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl reload sshd.service

[Install]
WantedBy=multi-user.target
```
Teraz povolíme spúštanie ssh-config-watcher.path pri štarte systému a zároven hneď túto službu aj spustíme v jednom kroku:
```
[~]: systemctl enable --now ssh-config-watcher.path
```

## Vypísanie aktívnych časovačov
```
[~]: systemctl list-timers
```