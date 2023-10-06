# systemd workshop



## Vytvorenie vlastnej služby / jednotky
Pre vytvorenie systemd jednotky je potrebné vytvoriť súbor s príponou .service v priečinku `/etc/systemd/system`. Ako príklad si vytvoríme nový súbor `/etc/systemd/system/count.service` s následujúcim obsahom:
```
[Unit]
Description=Toto je moja prvá systemd služba

[Service]
ExecStart=/opt/count.sh 10
Restart=always

[Install]
WantedBy=multi-user.target
```

V tejto ukážke sme vytvorili službu, ktorá bude spúštať bash skript umiestnený v `/opt/count.sh` .

Súbor sa skladá z troch sekcií:
- `[Unit]` obsahuje len popis 
- `[Service]` sa nachádza parameter `ExecStart` ktorý sa zavolá pri štarte služby a druhý parameter `Restart` ( https://www.freedesktop.org/software/systemd/man/systemd.service.html ), ktorým môžeme ovplyvniť neočakávané správanie
- `[Install]` definuje, že naša služba sa bude spúštať ako časť `multi-user.target`

Po uložení súboru môžeme našu službu zapnúť:
```
[~]: systemctl start count.service
```
Po tomto príkaze nedostaneme žiaden výstup. Aby sme videli, čo sa po spustení stalo, je potrebné spustiť príkaz:
```
[~]: systemctl status count.service
```
Status nám zobrazí komplexný výstup, vr. času odkedy je služba spustená, PID, informácií o spotrebe pamäte, CPU, atď.

Službu môžeme vypnúť spustením stop príkazu:
```
[~]: systemctl stop count.service
```
Štandardne sa pošle `SIGTERM` a po 90 sekundách `SIGKILL`. Pridaním parametru `ExecStop=` môžeme zadefinovať vlastný spôsob vypnutia našej služby.

Teraz môžeme overiť, či vypnutie služby prebehlo korektne:
```
[~]: systemctl status count.service
```

Aby sme zabezpečili spúštanie služby pri štarte operačného systému na úrovni, ktorý definujeme parametrom `[Install]`, je potrebné povoliť spúšťanie našej služby:
```
[~]: systemctl enable count.service
```
Teraz sa už služba zapne automaticky pri štarte operačného systému.
Ďalšími parametrami ako sú `After` alebo `Requires`, môžeme vytvorit závislosť na inej službe a docieliť tak, aby sa naša služba spustila až po štartej inej služby.

## Upravenie vytvorenej služby
Upravenie vytvorenej služby `count.service` služby môžeme vykonať dvomi spôsobmi:
- úpravením pôvodného súboru `/etc/systemd/system/count.service`
- pridaním špeciálneho súboru `override.conf`

Ukážme si najprv prvý spôsob, editujme súbor `/etc/systemd/system/count.service` a pridajme nový parameter `User=nobody`:
```
[Unit]
Description=Toto je moja prvá systemd služba

[Service]
ExecStart=/opt/count.sh 10
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
```
Ak sa teraz pokúsime službu reštartovať, systemd nás upozorní, že v súbore nastala zmena:
```
[~]: systemctl restart count.service
Warning: The unit file, source configuration file or drop-ins of count.service changed on disk. Run 'systemctl daemon-reload' to reload units.
```
Služba sa reštartuje ale zmeny ktoré sme uskutočnili sa neprejavia. Je preto potrebné spustiť príkaz, ktorým načítame uskutočnené zmeny:
```
[~]: systemctl daemon-reload
```
Službu teraz musíme ešte raz reštartovať:
```
[~]: systemctl restart count.service
```

### Upravenie vytvorenej služby - override.conf

Druhý spôsob ako upraviť službu je použitím súboru `override.conf`. 

override.conf je špeciálny súbor, ktorého hodnoty sa načítavajú ako prvé, ešte pred `/etc/systemd/system/count.service` a majú prednosť.

Zmeny ktoré by sme urobili v štandardnom súbore `.service` môžu byť prepísané napr. po aktualizácií balíkov. Preto ak chceme zmeny uchovať, je odporúčaným spôsobom modifikovania služby použitie súboru `override.conf` .

Ak chceme upraviť našu službu `count.service` týmto spôsobom, tak musíme vytvoriť súbor `/etc/systemd/system/count.service.d/override.conf` a pre aplikovanie zmien následne spustiť `systemctl daemon-reload`.

Celý tento postup je možné vykonať aj jednoduchšie - príkazom:
```
[~]: systemctl edit count.service
```

Pridáme nasledujúce riadky:
```
[Service]
Environment=MY_ENV=testvalue
```
Súbor následne uložíme a reštartujeme `count.service`
```
[~]: systemctl restart count.service
```

Nie všetky zmeny parametrov vyžadujú reštart. Reštartovanie služby pre aplikovanie nových parametrov vyžadujú len parametre, ktoré su inicializované pri `exec()` - celý zoznám nájdete v dokumentácii [systemd.exec](https://www.freedesktop.org/software/systemd/man/systemd.exec.html) .

Ak do našej služby pridáme obmedzenie pamäte, tak sa zmeny prejavia okamžite. Túto zmenu môžeme vykonať opäť dvomi spôsobmi:
- manuálnou úpravou `/etc/systemd/system/count.service.d/override.conf`
- spustením:
```
[~]: systemctl edit count.service
```

Súbor upravíme následovne:
```
[Service]
Environment=MY_ENV=testvalue
MemoryMax=10M
```

Následne ak sa pozrieme na výstup z príkazu `systemctl status`:
```
[~]: systemctl status count.service
● count.service - My first systemd service
     Loaded: loaded (/etc/systemd/system/count.service; disabled; preset: disabled)
    Drop-In: /usr/lib/systemd/system/service.d
             └─10-timeout-abort.conf
             /etc/systemd/system/count.service.d
             └─override.conf
             /run/systemd/system/service.d
             └─zzz-lxc-service.conf
     Active: active (running) since Thu 2023-10-05 23:59:02 CEST; 5s ago
   Main PID: 293487 (count.sh)
      Tasks: 2 (limit: 309353)
     Memory: 600.0K (max: 10.0M available: 9.4M)
     CGroup: /system.slice/count.service
             ├─293487 /bin/bash /opt/count.sh 10
             └─293493 sleep 1
```

Môžeme vidieť, že vo výstupe sa naše limity aplikovali okamžite a bez reštartu: `Memory: 600.0K (max: 10.0M available: 9.4M)`.

# Zhrnutie základných príkazov systemctl

`systemctl list-units` - vypíše všetky jednotky v systéme
`systemctl list-units --type=service`

`systemctl status count.service` alebo `systemctl status PID` - zobrazí stav služby

`systemctl start/stop/restart count.service` - vykoná zapnutie/vypnutie/reštartovanie služby

`systemctl cat count.service` - zobrazí obsah služby vr. všetkých overrides.conf

`systemctl show count.service` - vypíše obsah súbor, tak ako je načítaný v pamäti

`systemctl show -p MainPID -p ExecStart myfirstservice` - vypíše obsah súbor, tak ako je načítaný v pamäti, môžeme použiť parameter `-p` alebo `--value` pre vypísanie špecifických hodnôť

`systemctl kill --signal 9 count.service` - používa sa na poslanie signálu voči spustenej službe, predvolená hodnota je SIGTERM. Môžeme použiť čokoľvek od SIGKILL po SIGWINCH.

# ad-hoc služby

Systemd má možnosť spustenia aj ad-hoc služby prostredníctvom príkazu `systemd-run`.
Náš script môžeme spustiť následovne:
```
[~]: systemd-run /opt/count.sh
```

Systemd následne vytvorí jednorázovú službu, ktorej vygeneruje názov a vráti nám tuto hodnotu na výstupe z predchádzajúceho príkazu - `Running as unit: run-r78c0768061d147daa122f04d76fa4943.service`. So službou môžeme následne štandardne pracovať.

```
[~]: systemctl  status run-r78c0768061d147daa122f04d76fa4943.service
● run-r78c0768061d147daa122f04d76fa4943.service - /opt/count.sh 3000
     Loaded: loaded (/run/systemd/transient/run-r78c0768061d147daa122f04d76fa4943.service; transient)
  Transient: yes
    Drop-In: /usr/lib/systemd/system/service.d
             └─10-timeout-abort.conf
             /run/systemd/system/service.d
             └─zzz-lxc-service.conf
     Active: active (running) since Fri 2023-10-06 00:17:50 CEST; 4s ago
   Main PID: 296328 (count.sh)
      Tasks: 2 (limit: 309353)
     Memory: 584.0K
     CGroup: /system.slice/run-r78c0768061d147daa122f04d76fa4943.service
             ├─296328 /bin/bash /opt/count.sh 3000
             └─296340 sleep 1

okt 06 00:17:50 jurena systemd[1]: Started run-r78c0768061d147daa122f04d76fa4943.service - /opt/count.sh 3000.
okt 06 00:17:50 jurena count.sh[296328]: Count: 0
okt 06 00:17:51 jurena count.sh[296328]: Count: 1
okt 06 00:17:52 jurena count.sh[296328]: Count: 2
okt 06 00:17:53 jurena count.sh[296328]: Count: 3
okt 06 00:17:54 jurena count.sh[296328]: Count: 4
```

Po vypnutí sa služba odstráni zo systému:
```
[~]: systemctl  stop run-r78c0768061d147daa122f04d76fa4943.service
[~]: systemctl  status run-r78c0768061d147daa122f04d76fa4943.service
Unit run-r78c0768061d147daa122f04d76fa4943.service could not be found.
```

Všetky takto spustené služby sú označené za "prechodné" a súbory sú dočasne vytvárané v  `/run/systemd/transient/`.


## Interaktívny shell

Pre spustenie shellu, používame `systemd-run` s parametrom `--shell` pre alokovanie psedo-terminálu.

```
[~]: systemd-run --shell
Running as unit: run-u827.service
Press ^] three times within 1s to disconnect TTY.
[/root]:
```
Teraz môžete spúštať príkazy vo vnútri služby, reálne sa jedná o kontajner.

Podobne môžeme spustiť napr. python konzolu:
```
[~]: systemd-run --pty python
Running as unit: run-u921.service
Press ^] three times within 1s to disconnect TTY.
Python 3.11.5 (main, Aug 28 2023, 00:00:00) [GCC 13.2.1 20230728 (Red Hat 13.2.1-1)] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>>
```

## Spustenie interaktívneho procesu

Ďaľšou vlastnosťou ktorú nám systemd poskytuje je spustenie procesu pomocou `systemd-run` s možnosťou nastavenia ďaľších parametrov prepínačom `-p` a pripojením stdin, stdout and stderr naspäť na náš výstup pomocou parametra `--pty`

```
[~]: systemd-run -p DynamicUser=true --pty /opt/count.sh
```
```
[~]: systemd-run -p DynamicUser=true --pty python
```