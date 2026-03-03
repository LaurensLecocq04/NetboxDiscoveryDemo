# NetBox Discovery gebruiken (Community)

Discovery werkt in drie stappen: **Diode-server** draaien, **NetBox-plugin** koppelen aan Diode, en de **Orb Agent** configureren en starten.

---

## Overzicht

```
[Orb Agent]  ---(gRPC + OAuth)--->  [Diode Server]  ---(API)--->  [NetBox]
     │                                    │
     │  scant netwerk/apparaten           │  verzoekt data met NetBox
     └───────────────────────────────────┘
```

- **Diode server**: ontvangt data van de Orb Agent en praat met NetBox (API + plugin).
- **NetBox + Diode-plugin**: kent Diode (target + secret) en verwerkt binnenkomende data.
- **Orb Agent**: voert discovery uit (netwerk-scans en/of device discovery) en stuurt naar Diode.

---

## Stap 1: Diode-server deployen (in de VM)

NetBox draait al (bijv. op poort 8000). De Diode-server moet **NetBox kunnen bereiken**. Als Diode in Docker op dezelfde VM draait, gebruik dan het **Docker-hostadres** voor NetBox (niet `localhost`).

**In de Vagrant-VM:**

```bash
# jq is nodig voor het quickstart-script
sudo apt-get update && sudo apt-get install -y jq

# Werkmap voor Diode (gebruik een map waar je schrijfrechten hebt, bv. /vagrant of home)
mkdir -p /vagrant/diode
cd /vagrant/diode

# Quickstart-script ophalen
curl -sSfLo quickstart.sh https://raw.githubusercontent.com/netboxlabs/diode/release/diode-server/docker/scripts/quickstart.sh
chmod +x quickstart.sh
```

**NetBox-URL voor Diode:**  
Vanuit andere Docker-containers op dezelfde host is de host zelf bereikbaar als `172.17.0.1` (Linux Docker bridge). Gebruik dus:

```bash
# NetBox bereikbaar voor Diode-containers (zelfde host)
./quickstart.sh http://172.17.0.1:8000
```

Als NetBox op een andere machine staat, gebruik dan het echte hostnaam of IP (bijv. `http://192.168.1.10:8000`).

**Diode starten:**

```bash
docker compose up -d
docker compose ps
```

Je zou vier containers moeten zien: o.a. `diode-ingester`, `diode-reconciler`, `nginx`. Standaard luistert Diode (via nginx) op **poort 8080**.

**Credentials bewaren:**  
Het script toont iets als:

```
DIODE_CLIENT_ID: diode-ingest
DIODE_CLIENT_SECRET: W3ofHVeGSfG0uEWP5idT6nI7UQc9Sy5kNfTPbMIWBk=
```

En het maakt `oauth2/client/client-credentials.json` aan. Daar haal je later vandaan:

- **Voor de Orb Agent:** `diode-ingest` client id + secret (zoals hierboven getoond).
- **Voor de NetBox-plugin:** het **netbox-to-diode** geheim (pas het pad aan als je een andere map gebruikte):

```bash

# Als je quickstart in /opt/diode deed (bijv. met sudo):
sudo jq -r '.[] | select(.client_id == "netbox-to-diode") | .client_secret' /opt/diode/oauth2/client/client-credentials.json
```

Bewaar dat geheim; dat komt in Stap 2.
lnd2OvXjAHI1eMoQDX8hh7VS17+INI8YxY3T54AY=
---

## Stap 2: NetBox koppelen aan Diode

De Diode-plugin in NetBox moet weten **waar Diode draait** en welk **netbox-to-diode** geheim te gebruiken.

### 2a. Diode-target en secret in NetBox

**Optie A – Via configuratiebestand (aan te raden voor test)**

In je NetBox-configuratie (bijv. `netbox/configuration/plugins.py` of een `extra.py` die door `configuration.py` wordt geladen) zet je:

```python
PLUGINS_CONFIG = {
    "netbox_diode_plugin": {
        "diode_target_override": "grpc://172.17.0.1:8080/diode",
        "netbox_to_diode_client_secret": "HIER_HET_NETBOX_TO_DIODE_SECRET",
    }
}
```

- `diode_target_override`: het adres waar de **Orb Agent** en **NetBox** de Diode gRPC-service bereiken.  
  - Als NetBox in Docker op dezelfde host draait als Diode: `grpc://172.17.0.1:8080/diode`.  
  - Als Diode op een andere host draait: `grpc://<diode-host>:8080/diode`.
- `netbox_to_diode_client_secret`: de waarde uit Stap 1 (`netbox-to-diode` uit `client-credentials.json`).

**Optie B – Via omgevingsvariabelen (als je plugin dat ondersteunt)**  
Als je geen secrets in config wilt, kun je in `netbox.env` iets toevoegen als (als de plugin het leest):

```bash
# Alleen als de plugin env vars ondersteunt; anders Optie A
# DIODE_TARGET_OVERRIDE=grpc://172.17.0.1:8080/diode
# NETBOX_TO_DIODE_CLIENT_SECRET=...
```

Daarna NetBox (en eventueel worker) herstarten zodat de plugin de nieuwe instellingen laadt.

### 2b. Client credentials voor de Orb Agent (Community)

Bij Community worden er **geen** credentials in de NetBox-UI aangemaakt voor Discovery. De Orb Agent gebruikt de **diode-ingest** credentials die het quickstart-script heeft gegenereerd (zie uitvoer van `./quickstart.sh` en `oauth2/client/client-credentials.json`).  
Zorg dat je die **Client ID** en **Client Secret** ergens veilig noteert; die gebruik je in Stap 3 in `agent.yaml`.

---

## Stap 3: Orb Agent configureren en draaien

De Orb Agent doet de echte discovery (netwerk-scans, eventueel device discovery) en stuurt de resultaten naar Diode.

### 3a. Voorbeeldconfiguratie

Maak een bestand `agent.yaml` (bijv. in `discovery/agent.yaml` of thuis):

```yaml
orb:
  config_manager:
    active: local
  backends:
    common:
      diode:
        target: grpc://127.0.0.1:8080/diode
        client_id: ${DIODE_CLIENT_ID}
        client_secret: ${DIODE_CLIENT_SECRET}
        agent_name: discovery_agent_01
    network_discovery: {}
    device_discovery: {}     # Zie 3c voor policy en credentials
  policies:
    network_discovery:
      thuis_netwerk:
        config:
          schedule: "*/15 * * * *"   # Elke 15 min (cron)
          timeout: 5
        scope:
          targets:
            - "192.168.129.0/24"
```

- **target**: hetzelfde Diode-adres als in NetBox (`grpc://<host>:8080/diode`). Op de VM: `grpc://172.17.0.1:8080/diode`; vanaf je eigen PC: het IP van de VM + poort 8080 als die gemapped is.
- **client_id** / **client_secret**: de **diode-ingest** credentials uit Stap 1.
- **scope.targets**: de netwerken die je wilt laten scannen (pas aan op je eigen netwerk).

### 3b. Agent starten (Docker)

**Op de Vagrant-VM** (zelfde host als Diode):

```bash
cd /pad/naar/discovery   # map waar agent.yaml staat

export DIODE_CLIENT_ID="diode-ingest"
export DIODE_CLIENT_SECRET="<diode-ingest-secret-uit-quickstart>"

docker run --rm -it --network host \
  -v "$(pwd):/opt/orb" \
  -e DIODE_CLIENT_ID \
  -e DIODE_CLIENT_SECRET \
  netboxlabs/orb-agent:latest run -c /opt/orb/agent.yaml
```

`--network host` zorgt ervoor dat de agent je netwerk kan scannen. Als je geen host-netwerk wilt, moet je in ieder geval de **target** in `agent.yaml` zo zetten dat hij Diode kan bereiken (bijv. IP van de VM).

**Op je eigen machine (buiten de VM):**  
Zet in `agent.yaml` bij `diode.target` het adres waar Diode bereikbaar is (bijv. `grpc://<VM-IP>:8080/diode` als je poort 8080 naar de VM forwarded). Dezelfde `DIODE_CLIENT_ID` en `DIODE_CLIENT_SECRET` gebruiken.

### 3c. Device discovery (optioneel)

Naast **network discovery** (IP-scans) kan de agent **device discovery** doen: via SSH (of SNMP) inloggen op switches/routers en daar informatie ophalen (interfaces, LLDP, enz.). Die data komt in NetBox onder DCIM.

In `discovery/agent.yaml.example` staat een voorbeeld:

- **Backend:** `device_discovery: {}`
- **Policy** `mijn_switch`: driver `ios` (Cisco IOS), hostname `192.168.129.1`, credentials via `${DEVICE_USERNAME}` en `${DEVICE_PASSWORD}`.

**Gebruik:**

1. Pas in `agent.yaml.example` (of in gegenereerde `agent.yaml`) de **hostname** aan naar het IP of de hostname van je switch.
2. Zet **site** onder `defaults` op een bestaande site in NetBox (bv. "Main Site").
3. Voor credentials:
   - **Via env:** `export DEVICE_USERNAME="admin"` en `export DEVICE_PASSWORD="wachtwoord"`, daarna `./start-agent.sh` (die vult ze in via envsubst).
   - **Handmatig:** na `./start-agent.sh` het bestand `agent.yaml` openen en bij `device_discovery.mijn_switch.scope` de echte username/password invullen.
4. Ondersteunde **drivers** o.a.: `ios` (Cisco IOS), `eos` (Arista), `junos` (Juniper). Meerdere apparaten: extra `- driver: ... hostname: ...` blokken toevoegen onder `scope`.

Device discovery draait volgens het schema in de policy (standaard elke 6 uur). De agent moet het apparaat kunnen bereiken (netwerk + SSH-poort 22).

---

## Samenvatting volgorde

1. **Diode-server:** `quickstart.sh` met NetBox-URL (bijv. `http://172.17.0.1:8000`) → `docker compose up -d`.
2. **NetBox:** `diode_target_override` + `netbox_to_diode_client_secret` in plugin-config → herstart NetBox.
3. **Orb Agent:** `agent.yaml` met `target`, `client_id`, `client_secret` en gewenste `scope` → `docker run ... orb-agent run -c /opt/orb/agent.yaml`.

Daarna zou Discovery moeten “werken”: de agent scant volgens schema, stuurt naar Diode, en Diode werkt samen met de NetBox-plugin om data in NetBox bij te werken. Voor meer opties (device discovery, SNMP, meerdere policies) zie de [Orb Agent configuratie](https://netboxlabs.com/docs/orb-agent/) en [Discovery getting started](https://netboxlabs.com/docs/discovery/getting-started/).

---

## Resultaten bekijken (Community)

Onder **Plugins → Diode** zie je bij Community vaak alleen **Settings** en **Client Credentials**. Een uitgebreid "ingestion logs"-dashboard is soms alleen in Cloud/Enterprise beschikbaar.

**Waar je wél ziet of er iets is ontdekt:**

1. **DCIM → Devices** – nieuw aangemaakte of bijgewerkte apparaten.
2. **IPAM → IP Addresses** – toegevoegde IP-adressen uit de scan (bv. uit 192.168.129.0/24).
3. **IPAM → Prefixes** – prefix 192.168.129.0/24 en eventueel andere ontdekte prefixen.

Na een geslaagde scan verschijnen daar de ontdekte objecten. De agent scant volgens schema (bv. elke 15 min); even wachten en dan deze pagina's vernieuwen.

**Controleren of data bij Diode aankomt (in de VM):**

```bash
sudo docker logs diode-diode-ingester-1 --tail 50
```

---

## Geen apparaten / geen data in NetBox

**1. Kijk ook in IPAM**  
Network discovery vult vaak eerst **IPAM → IP Addresses** en **IPAM → Prefixes** in. Kijk daar; echte **DCIM → Devices** komen soms pas na device discovery of reconcilie.

**2. Kan de VM het netwerk bereiken?**  
De Orb Agent draait in de VM. Als de VM op VirtualBox NAT staat (bijv. 10.0.2.15), kan ze **192.168.129.0/24** niet bereiken. Dan vindt de scan niets.

In de VM:
```bash
ping -c 1 192.168.129.1
# of een IP dat in dat netwerk zou moeten bestaan
```
Als dat faalt: VM in VirtualBox op **Bridged adapter** zetten (netwerk: jouw LAN 192.168.129.x) of de agent op je **eigen machine** draaien (niet in de VM) met `target: grpc://<VM-IP>:8080/diode`.

**3. Heeft de scan iets gevonden?**  
In de terminal waar de Orb Agent draait: na een scan zou je geen "timed out" of "error running scanner" moeten zien. Als de scan slaagt, zie je geen error voor die policy.

**4. Komt data bij Diode?**
```bash
sudo docker logs diode-diode-ingester-1 --tail 100
sudo docker logs diode-diode-reconciler-1 --tail 100
```
- **Reconciler:** zoek naar `"handling ingest request"` (data ontvangen) en `"change set applied"` (succesvol naar NetBox). Geen errors = goed.
- **Network discovery** maakt **geen** Devices aan, wel **IPAM → IP Addresses** en **IPAM → Prefixes**. Kijk daar dus voor ontdekte IP’s (bv. 192.168.129.7, hostname deco-m9plus).

**4b. Diode: “connection refused” / “database system is starting up” in de reconciler**  
De reconciler start soms vóór Postgres klaar is. Oplossingen:
- **Simpel:** na `docker compose up -d` in de Diode-map even wachten (10–15 s) voordat je de agent start; de reconciler herstart zichzelf tot de DB bereikbaar is.
- **Structureel (in de VM):** in de Diode-map (bv. `/opt/diode`) in `docker-compose.yml` bij de reconciler-service `depends_on` uitbreiden met een healthcheck op postgres, of `restart: on-failure` gebruiken zodat de reconciler opnieuw probeert. Daarna `docker compose up -d` opnieuw draaien.

**5. Klein bereik testen**  
Zet tijdelijk in `agent.yaml` een klein bereik dat de VM wél kan bereiken (bijv. het VM-netwerk zelf), herstart de agent en kijk of er dan wel IP’s in NetBox verschijnen.

**6. Discovery vindt minder dan handmatige nmap**  
De Orb Agent gebruikt vaak alleen **host discovery** (ping/ICMP). Hosts die **geen ICMP** beantwoorden (firewall, sommige toestellen) worden dan niet gevonden. Handmatige `nmap 192.168.129.0/24` doet standaard host discovery + port scan en vindt soms meer.  
- Geef de agent voldoende **timeout** (bv. 15 min voor /24) zodat de scan niet halverwege stopt.  
- Controleer in **IPAM → IP Addresses** of er meer IP’s zijn toegevoegd dan je in DCIM ziet.  
- Nieuwere agent-versies hebben soms extra scan-opties (niet alleen ping); zie de [Orb Agent-docs](https://netboxlabs.com/docs/orb-agent/) voor `network_discovery`-configuratie.

**7. Scan handmatig testen (in de VM)**  
Controleer of nmap hosts vindt op het netwerk (zonder Diode):
```bash
nmap -sn 192.168.129.1-20
```
Als hier hosts verschijnen maar er komt niets in NetBox, zit het probleem in de keten Orb Agent → Diode → NetBox (logs ingester/reconciler).

**8. Agent op de host draaien (als de VM-container het netwerk niet bereikt)**  
Als de Orb Agent **in de VM** steeds timeout geeft (ook voor 192.168.129.0/28), kan de container het netwerk 192.168.129.x vaak niet goed bereiken. **Workaround:** agent op je eigen pc draaien (als die op 192.168.129.x zit):

- In de **Vagrantfile** staat nu ook **port 8080** geforward (Diode). Na `vagrant reload` is Diode vanaf je pc bereikbaar als `localhost:8080`.
- Op je **Windows-pc** (PowerShell of WSL, met Docker): maak een map met `agent.yaml` (target: `grpc://127.0.0.1:8080/diode` of `grpc://host.docker.internal:8080/diode`), zet er dezelfde `diode-ingest` credentials in (via envsubst of handmatig), en start:
  `docker run --rm -it -v "%cd%":/opt/orb -e DIODE_CLIENT_ID -e DIODE_CLIENT_SECRET netboxlabs/orb-agent:latest run -c /opt/orb/agent.yaml`
- De agent scant dan vanaf je pc het netwerk 192.168.129.x en stuurt naar Diode op de VM via localhost:8080.

**9. Zeker weten dat de agent wél naar Diode stuurt**  
- Gebruik een **klein bereik** in `agent.yaml` (bv. `192.168.129.0/28`) en **schedule elke minuut** (`* * * * *`), hergenereer met `./start-agent.sh`.  
- Start de agent en **laat hem min. 2 minuten** draaien; kijk in de agent-log of je `"running scanner"` ziet en **geen** `"error"` of `"timed out"` daarna.  
- Direct daarna: `sudo docker logs diode-diode-ingester-1 --tail 50`. Zie je nog steeds alleen startup, dan komt de agent niet tot zenden of Diode ontvangt niet (verbinding/poort).
