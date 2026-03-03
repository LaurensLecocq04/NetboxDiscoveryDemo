## NetBox Discovery Mode – testomgeving

Vagrant-omgeving met **NetBox Community** in Docker, inclusief:

- **Diode NetBox plugin** voor Discovery
- **Diode-server** (automatisch via provisioning)
- **Orb Agent** met voorbeeldconfig (`discovery/agent.yaml.example`)

Doel: snel een complete **Discovery-keten** opzetten in een VM, om te kunnen testen en demonstreren.

---

## Overzicht – wat zit er in deze omgeving?

- **VM**: Ubuntu 22.04 met Docker & Docker Compose
- **NetBox** (Community) in containers
  - Diode-plugin al geïnstalleerd en geconfigureerd
  - Superuser wordt automatisch aangemaakt
- **Diode-server** in containers
  - OAuth2-clients `diode-ingest` en `netbox-to-diode` worden door quickstart gemaakt
  - Secret voor `netbox-to-diode` wordt automatisch in NetBox-config gezet
- **Orb Agent** (Discovery agent)
  - Draait in de VM via `discovery/start-agent.sh`
  - Config in `discovery/agent.yaml.example` (network discovery)

Voor meer diepgang: zie **[DISCOVERY.md](DISCOVERY.md)**.

---

## Vereisten op je laptop

- **Vagrant**
- **VirtualBox** (of andere Vagrant-provider, maar dit project is getest met VirtualBox)

---

## Omgeving starten (één command)

In de root van de repo (`NetboxOmgeving`):

```bash
vagrant up
```

De provisioning doet dan automatisch:

- Ubuntu packages updaten
- Docker + Docker Compose plugin installeren
- NetBox containers starten (`docker compose up -d` in `/vagrant/netbox`)
- Diode quickstart draaien in `/opt/diode` en Diode containers starten
- Diode-secret (`netbox-to-diode`) uitlezen en in `netbox/env/netbox.generated.env` schrijven
- NetBox containers recreaten zodat de Diode-plugin de juiste secret uit de env leest

Je hoeft dus **niet** zelf `docker compose up` of Diode-quickstart te draaien.

---

## NetBox & Diode gebruiken

### NetBox UI

- **URL vanaf je laptop**:
  - `http://localhost:8000`
  - of via host-only netwerk: `http://192.168.56.10:8000`
- **Login** (testomgeving):
  - **username**: `admin`
  - **password**: `admin`

### Diode server

- **URL vanaf je laptop**:
  - `http://localhost:8080`
  - of `http://192.168.56.10:8080`
- In NetBox:
  - Ga naar **Plugins → Diode → Client Credentials**
  - Als je daar geen foutmelding ziet (geen “Missing netbox to diode client secret”) en de clients verschijnen, is de koppeling **NetBox ↔ Diode** in orde.

---

## Discovery met Orb Agent

De Orb Agent draait in de VM en stuurt discovery-resultaten naar Diode, die ze doorstuurt naar NetBox.

### 1. Agent-configuratie

- **Template**: `discovery/agent.yaml.example`
  - Bevat:
    - Diode-target (`grpc://127.0.0.1:8080/diode`)
    - Diode-client (`diode-ingest`)
    - Eén `network_discovery` policy (`lokaal_netwerk_1`)
    - Een beperkt bereik (bijv. `192.168.50.0/28`) om timeouts te vermijden
    - `ping_scan: true` → alleen host discovery (geen uitgebreide portscan)

`start-agent.sh` genereert hiervan een echte `agent.yaml` met je echte Diode-credentials.

### 2. Agent starten

In de VM:

```bash
vagrant ssh
cd /vagrant/discovery
./start-agent.sh
```

Dit doet:

- Diode-credentials ophalen uit `/opt/diode/oauth2/client/client-credentials.json`
- `agent.yaml` genereren uit `agent.yaml.example` (met `envsubst`)
- Orb Agent-container starten:
  - `docker run --network host netboxlabs/orb-agent:latest run -c /opt/orb/agent.yaml`

Laat de agent minimaal één volledige policy-run afmaken (niet direct `Ctrl+C` na “running scanner”).

### 3. Resultaten bekijken

- In **NetBox**:
  - Ga naar **IPAM → IP Addresses**
  - Zoek naar IP’s in het gescande bereik (bijv. `192.168.50.0/28`)
  - Daar verschijnen IP-adressen met status “Active” en comments met scaninformatie

- In **Diode** (VM):
  ```bash
  sudo docker logs diode-diode-ingester-1 --tail 80
  sudo docker logs diode-diode-reconciler-1 --tail 80
  ```
  - `handling ingest request` → Orb Agent stuurt data naar Diode
  - `change set applied` → Diode heeft wijzigingen in NetBox doorgevoerd

Voor meer details, probleemoplossing en uitleg over waarom thuisnetwerken vaak meer IP’s tonen dan er werkelijk devices zijn, zie **[DISCOVERY.md](DISCOVERY.md)**.

---

## Structuur van dit project

- **Vagrantfile**
  - Ubuntu 22.04 VM
  - Port forwarding:
    - 8000 → NetBox
    - 8080 → Diode
  - Host-only netwerk: `192.168.56.10`
- **scripts/provision.sh**
  - Installeert Docker + Docker Compose plugin
  - Start NetBox containers
  - Draait Diode quickstart en zet Diode-secret in NetBox-env
- **netbox/**
  - `docker-compose.yml` – NetBox, worker, PostgreSQL, Redis
  - `docker-compose.override.yml` – custom image met plugins, poort 8000
  - `Dockerfile-Plugins` – bouwt image met:
    - Diode-plugin
    - Validity-plugin
  - `configuration/` – NetBox-config (`configuration.py`, `plugins.py`)
  - `env/` – env-files:
    - `netbox.env` – basisconfig (DB, Redis, secret key, superuser)
    - `netbox.generated.env` – **automatisch** gegenereerde Diode-variabelen
- **discovery/**
  - `agent.yaml.example` – Orb Agent-config template
  - `start-agent.sh` – genereert `agent.yaml` en start de Orb Agent
  - `agent.yaml` – gegenereerd bestand (bevat echte secrets, staat in `.gitignore`)

---

## Handige commands (samenvatting)

- **VM opstarten + omgeving klaarzetten**:
  ```bash
  vagrant up
  ```

- **VM stoppen**:
  ```bash
  vagrant halt
  ```

- **NetBox-logs** (in de VM):
  ```bash
  cd /vagrant/netbox
  docker compose logs -f netbox
  ```

- **Orb Agent starten** (in de VM):
  ```bash
  cd /vagrant/discovery
  ./start-agent.sh
  ```

Voor diepere analyse van Discovery, tuning (ping-only, scan-profielen) en bekende beperkingen: lees **[DISCOVERY.md](DISCOVERY.md)**.  
Die file is geschreven als begeleidend document voor je stage/verslag.

# NetBox Discovery Mode – testomgeving

Vagrant-omgeving met **NetBox Community** in Docker, inclusief de **Diode-plugin** voor Discovery mode.

## Vereisten

- [Vagrant](https://www.vagrantup.com/) (met VirtualBox of andere provider)
- [VirtualBox](https://www.virtualbox.org/) (of VMware/Hyper-V als je die gebruikt)

## Snel starten

1. **VM starten en NetBox draaien**
   ```bash
   vagrant up
   vagrant ssh
   cd /vagrant/netbox
   docker compose build --no-cache
   docker compose up -d
   ```

2. **NetBox openen**
   - URL: **http://localhost:8000**
   - Eerste keer: aanmaken superuser:
     ```bash
     docker compose exec netbox /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py createsuperuser
     ```

3. **Stoppen**
   ```bash
   cd /vagrant/netbox && docker compose down
   exit
   vagrant halt
   ```

## Discovery mode (Diode + Orb Agent)

**→ Volledige stappen om Discovery te laten werken: [DISCOVERY.md](DISCOVERY.md)**

Deze setup bevat de **Diode NetBox plugin**. Voor volledige Discovery heb je nog nodig:

1. **Diode server** (aparte container/VM) – ontvangt data van agents en praat met NetBox.
2. **Orb Agent** – discovery-agent die het netwerk scant en naar Diode stuurt.

### Diode server (optioneel, voor echte discovery)

Na het starten van NetBox kun je de Diode server erbij zetten:

```bash
# In de VM of op een host die NetBox kan bereiken
mkdir -p /opt/diode && cd /opt/diode
curl -sSfLo quickstart.sh https://raw.githubusercontent.com/netboxlabs/diode/release/diode-server/docker/scripts/quickstart.sh
chmod +x quickstart.sh
# Vervang door het echte NetBox-URL (vanuit de VM: http://netbox:8080 of vanaf host: http://localhost:8000)
./quickstart.sh http://JOUW_NETBOX_URL
docker compose up -d
```

Daarna in NetBox de Diode-plugin configureren (URL van de Diode server) en OAuth2-client credentials aanmaken voor de Orb agent.

### Orb Agent (discovery agent)

De Orb Agent draait apart en stuurt discovered data naar de Diode server:

```bash
docker pull netboxlabs/orb-agent:latest
# Configuratie: YAML met config_manager, backends, policies
# Zie: https://netboxlabs.com/docs/discovery/getting-started/
```

Documentatie:

- [NetBox Discovery – Getting started](https://netboxlabs.com/docs/discovery/getting-started/)
- [Diode](https://netboxlabs.com/docs/diode/)
- [Orb Agent](https://netboxlabs.com/docs/orb-agent/)
- [netbox-docker](https://github.com/netbox-community/netbox-docker)

## Structuur

- **Vagrantfile** – Ubuntu 22.04 VM, poort 8000 → NetBox
- **scripts/provision.sh** – installeert Docker en Docker Compose in de VM
- **netbox/** – NetBox Docker Compose (Community + Diode plugin)
  - **docker-compose.yml** – NetBox, worker, PostgreSQL, Redis
  - **docker-compose.override.yml** – custom image met plugin, poort 8000
  - **Dockerfile-Plugins** – image met `netbox-diode-plugin`
  - **configuration/** – NetBox config + `plugins.py` (Diode)
  - **env/** – environment voor NetBox, Postgres, Redis

## Tips

- **Wachtwoord wijzigen**: pas in productie o.a. `SECRET_KEY`, `DB_PASSWORD`, Redis-wachtwoorden in `netbox/env/` aan.
- **Logs**: `docker compose logs -f netbox`
- **Shell in container**: `docker compose exec netbox bash`
#   N e t b o x D i s c o v e r y D e m o 
 
 
