`systemd-networkd` je démon ktorý spravuje sieťovú konfiguráciu, detekuje a nastavuje sieťové rozhrania. Môže pracovať s virtuálnymi rozhraniami 

## Zapnutie systemd-networkd

Systemd zapneme a povolíme príkazom
```
[~]: systemctl enable --now systemd-networkd
```

## systemd-networkd-wait-online

Spolu so `systemd-networkd` sa automaticky zapne aj služba `systemd-networkd-wait-online`, ktorá čaká na nastavenie siete pri zavádzaní OS. Služba má štandardný timeout 2min, počas ktorých čaká na nastavenie siete.

Odporúča sa vypnúť globálne `systemd-networkd-wait-online` a povoliť len na rozhraní, kde očakávame prítomnosť konektivity

```
[~]: systemctl disable systemd-networkd-wait-online
[~]: systemctl enable systemd-networkd-wait-online@enp1s0.service
```

## Konfigurácia

Konfigurácia `systemd-networkd` je uložené v `/etc/systemd/network`.

### Nastavenie rozhrania eth0

`/etc/systemd/network/eth0.network`

```
[Match]
Name=eth0

[Network]
DHCP=yes
```

Ak by sme mali viac rozhraní, Systemd povoľuje zápis aj wildcardom - `eth*`.

Nastavenie statickej IP:
```
[Match]
Name=eth0

[Network]
Address=192.168.1.10/24
Address=192.168.1.11/24
Gateway=192.168.1.1
DNS=1.1.1.1
```

Ak nastavujeme DNS v `systemd-networkd`, je vyžadované mať zapnuté `systemd-resolved`.

# Vytvorenie virtuálneho rozhrania

Virtuálne rozhranie vytvoríme konfiguračným súborom s príponou `.netdev`, napr. `/etc/systemd/network/dummy0.netdev`.

Dummy rozhranie potrebuje načítanie modulu dummy v jadre (`modprobe dummy`).

```
[Netdev]
Name=dummy0
Kind=dummy
```

Virtuálnym rozhraním môže byť napr. bridge, VRF, VLAN, atp.

Následne virtuálne rozhranie nakonfigurujeme štandardným spôsobom:

```
[Match]
Name=dummy0

[Network]
Address=192.168.0.101/24
```

## Overenie sieťovej konfigurácie

Overenie robíme bežnou sadou príkazou - `ip`, `ifconfig`.
