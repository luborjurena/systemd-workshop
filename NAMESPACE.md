## Namespace izolácia

Linux namespace je funkcia jadra, pre vytvorenie izolovaného prostredia v ktorom spúšťame procesy a systémove prostriedky. Najčastejšie sa s nimi môžeme stretnúť v kontajnerých virtualizáciach (napr. LXC). V systemd je táto izolácia zabezpečená vytvorením izolovaného pohľadu na súborový systém.

Vytvoríme si novú službu `/etc/systemd/system/ns.service`:
```
[Service]
ProtectHome=yes
ProtectSystem=full
PrivateTmp=true
BindPaths=/usr/lib/systemd
ExecStart=sleep infinity
```
Následne ju spustíme:
```
[~]: systemctl start ns
```
Zistime si aký ma PID:
```
[~]: systemctl status ns
```
Pripojíme sa do spusteného namespace:
```
[~]: nsenter --target PID --all
```
Prvé čo si môžeme všimnúť je, že adresáre `/root/, /home, /run/user` v novo vytvorenom namespace sú prázdne a nemôžeme do nich zapisovať:
```
[~]: ls -la /root/ /home/ /run/user/
```
- `ProtectHome=yes` pripojí prázdne a len na čítanie adresáre /home, /root, a /run/user 
- `ProtectSystem=Full` pripojí adresáre /usr, /boot, /efi, /etc v režime read-only. Namiesto `Full` môžeme použiť hodnotu `Strict`, ktorá pripojí všetko v režime read-only okrem: /dev, /proc, / a /sys .
- `PrivateTmp=true` vytvorí adresáre /tmp a /var/tmp, do ktorých bude možné zapisovať.
- `BindPaths=` môžeme použiť, ak chceme pripojiť adresár do namespace.

Teraz si skúsme vytvoriť niekoľko súborov vo vnútri namespace:
```
[~]: touch ~/test.txt
[~]: touch /boot/test.txt
[~]: touch /tmp/test.txt
```

## Chroot

Chroot zmení koreňový adresár v ktorom pracujeme a môže obsahovať odlišný operačný systém. V takomto oddelenom prostredí sú procesy izolované na úrovni daného adresára a majú prístup len k súborom v rámci určeného adresára. Neizoluje zdroje ako je napr. sieť alebo procesy.

Vytvoríme si nové chroot prostredie:
```
[~]: apt-get install debootstrap
[~]: debootstrap --variant=minbase stable /opt/stable http://ftp.sk.debian.org/debian
[~]: chroot /opt/debian
[~]: cat /etc/debian_version
[~]: touch /test.txt
```

Takto spustený chroot má svoje obmedzenia, pretože nemáme informácie o pripojených zariadeniach (/dev) alebo ďalších systémových prostriedkoch (/proc).

V systemd môžeme vytvoriť službu, ktorá nám automaticky spustí chroot a pripojí /proc/, /sys/, /dev/ a /run/

Vytvoríme si `/etc/systemd/system/chroot.service`:
```
[Service]
RootDirectory=/opt/debian
MountAPIVFS=true
ExecStart=sleep infinity
```

Spustíme chroot:
```
[~]: systemctl start chroot
```
Prostredníctvom príkazu `nsenter` sa prepneme do chrootu:
```
[~]: nsenter -t $(systemctl show --value -p MainPID chroot.service) --all
```

## Dynamický užívatelia

systemd umožňuje definovať pod akým užívateľom chceme službu spúštať. Už sme si ukázali parameter `User=`, v ktorom staticky zadefinujeme užívateľa pod ktorým sa má služba spustiť. Takýto užívateľ v systéme ale musí vopred existovať.

systemd prichádza s parametrom `DynamicUser=`, ktorý vytvorí užívateľa na požiadanie pri spustení služby. Po zastavení služby sa užívateľ odstráni. UID sa prideľuje z rozsahu, ktorý je nastavený v systemd. systemd to robí pomocou mount namespaces, čo znamená, že použitie DynamicUser= implicitne zapína aj ProtectSystem=strict a ProtectHome=read-only spolu s množstvom ďalších vlastností, ktoré slúžia na bezpečné oddelenie užívateľa.

Upravíme si službu `count.service`:
```
DynamicUser=yes
```
Zmeny aplikujme a spravme reštart služby. Skript `count.sh` nám na začiatku vypíše pod akým užívateľom sa spúšta:
```
[~]: systemctl status count
```
Deatailnejší výpis:
```
[~]: ps -p $(systemctl show --value -p MainPID count) -o user,uid,pid,command,cgroup
```
Všimnite si, že nový užívateľ sa nezapísal do `/etc/passwd`.

Kam sa zapísali informácie o užívateľovi?

systemd implementuje túto funkciu cez `nss-systemd`, ktorý používa knižnicu Name Service Switch (NSS). Pre čítanie z tejto databázy je potrebné použiť príkaz `getent passwd`.

## Izolácia siete

Izoláciu siete môžete poznať skôr z kontajnerov alebo virtualizácie. Ukážeme si dva spôsoby ktoré sú implementované v systemd.

Prvý spôsob je použitie `PrivateNetwork=true`, ktorý využíva namespace. Takto spustený proces povolí iba komunikáciu voči loopbacku.

```
[~]: systemd-run --pty -p PrivateNetwork=true /bin/bash
```

Takto spustený namespace zdedí všetky príkazy, avšak sieť je nefunkčná. Rovnako do tohoto prostredia vieme pristupovať cez `nsenter`, spustiť 
```
[~]: ip a
[~]: ping 1.1.1.1
```

Druhým spôsobom je povolenie/obmedzenie vybraných sietí:
```
[~]: systemd-run --pty -p IPAddressAllow=8.8.8.8 -p IPAddressDeny=8.8.0.0/8 /bin/bash
```
Skontrolujme teraz dostupné sieťové zariadenia:
```
[~]: ip a
```
ping na 8.8.8.8 bude úspešný:
```
[~]: ping 8.8.8.8 -c 3
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=122 time=7.44 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=122 time=7.46 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=122 time=7.43 ms

--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 7.433/7.444/7.459/0.010 ms
```
Naopak, na ostatné ciele v sieti 8.8.0.0/8 sa neodstaneme. Napr.
```
ping 8.8.4.4 -c 3
PING 8.8.4.4 (8.8.4.4) 56(84) bytes of data.

--- 8.8.4.4 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2033ms
```
