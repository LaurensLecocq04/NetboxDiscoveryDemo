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
# NetBox Discovery Mode – testomgeving

Vagrant-omgeving met **NetBox Community** in Docker, inclusief de **Diode-plugin** voor Discovery.

Deze README is een beknopte handleiding om snel een testomgeving op te zetten met NetBox, Diode en de Orb Agent.

## Overzicht

- VM: Ubuntu 22.04 met Docker & Docker Compose
- NetBox (Community) draait in containers
- Diode-plugin is aanwezig en geconfigureerd
- Diode-server (optioneel) draait in containers via quickstart
- Orb Agent draait vanuit `discovery/start-agent.sh` in de VM

Voor uitgebreide instructies en achtergrondinformatie: zie [DISCOVERY.md](DISCOVERY.md).

## Vereisten

- Vagrant (https://www.vagrantup.com/)
- VirtualBox (of andere provider die je prefereert)

## Snelstart

1. VM starten en omgeving opbouwen

```bash
vagrant up
```

2. (Optioneel) inloggen in de VM en NetBox-containers beheren

```bash
vagrant ssh
cd /vagrant/netbox
docker compose build --no-cache
docker compose up -d
```

3. NetBox openen

- URL: http://localhost:8000 (of http://192.168.56.10:8000 via host-only netwerk)
- Standaard test-login: `admin` / `admin` (aanpassen in productie)

4. Stoppen

```bash
cd /vagrant/netbox && docker compose down
exit
vagrant halt
```

## Discovery (Diode + Orb Agent)

Deze repo bevat een Orb Agent-config templates in `discovery/agent.yaml.example` en een helper `discovery/start-agent.sh` die een `agent.yaml` genereert en de agent start.

Belangrijkste stappen:

- Zorg dat NetBox draait (`vagrant up`).
- (Optioneel) Start Diode quickstart (zie DISCOVERY.md) zodat Diode container(s) beschikbaar zijn.
- In de VM:

```bash
vagrant ssh
cd /vagrant/discovery
./start-agent.sh
```

De `start-agent.sh` haalt Diode-credentials op, genereert `agent.yaml` uit de template en start de Orb Agent (docker run).

Resultaten zijn zichtbaar in NetBox onder **IPAM → IP Addresses** en in de Diode-logs (in de VM):

```bash
sudo docker logs diode-diode-ingester-1 --tail 80
sudo docker logs diode-diode-reconciler-1 --tail 80
```

## Diode quickstart (kort)

Indien je een Diode server wilt opzetten (op dezelfde VM of een aparte host):

```bash
mkdir -p /opt/diode && cd /opt/diode
curl -sSfLo quickstart.sh https://raw.githubusercontent.com/netboxlabs/diode/release/diode-server/docker/scripts/quickstart.sh
chmod +x quickstart.sh
./quickstart.sh http://JOUW_NETBOX_URL
docker compose up -d
```

Daarna configureer je de Diode-plugin in NetBox en maak je OAuth2-client credentials voor de Orb Agent.

## Projectstructuur

- Vagrantfile — definieert de VM (poort forwarding voor 8000/8080, host-only netwerk 192.168.56.10)
- scripts/provision.sh — provisioning in de VM (Docker, Docker Compose, NetBox)
- netbox/ — NetBox docker-compose en configuratie
- discovery/ — Orb Agent template en startscript

## Handige commando's

- VM starten: `vagrant up`
- VM stoppen: `vagrant halt`
- NetBox logs (in VM):

```bash
cd /vagrant/netbox
docker compose logs -f netbox
```

- Orb Agent starten (in VM):

```bash
cd /vagrant/discovery
./start-agent.sh
```

## Resources

- DISCOVERY details: [DISCOVERY.md](DISCOVERY.md)
- NetBox Discovery docs: https://netboxlabs.com/docs/discovery/getting-started/
- Diode docs: https://netboxlabs.com/docs/diode/
- Orb Agent docs: https://netboxlabs.com/docs/orb-agent/
