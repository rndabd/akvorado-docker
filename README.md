# Akvorado - Flow Collector & Visualizer

A complete network flow monitoring solution using [Akvorado](https://github.com/akvorado/akvorado) with Docker.

## Features

- **NetFlow v5/v9/IPFIX** support
- **sFlow** support
- **SNMP** interface discovery
- **Web Dashboard** with real-time graphs
- **ClickHouse** for high-performance storage
- **Kafka** for reliable message processing
- **1000+ AS names** pre-configured (Indonesia + International)

## Quick Start

### One-Line Installation

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/akvorado-docker/main/install.sh | bash
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/akvorado-docker.git
cd akvorado-docker

# Make install script executable
chmod +x install.sh

# Run installer
./install.sh
```

### Installation on Alpine Linux

```bash
# Install dependencies
apk add docker docker-compose bash curl

# Start Docker
service docker start

# Clone and install
git clone https://github.com/YOUR_USERNAME/akvorado-docker.git
cd akvorado-docker
chmod +x install.sh
./install.sh
```

## Installation Wizard

The installer will ask for:

| Parameter | Default | Description |
|-----------|---------|-------------|
| Server IP | Auto-detected | IP address of this server |
| SNMP Community | `public` | SNMP community string for your devices |
| SNMP Port | `161` | SNMP port on your devices |
| NetFlow Port | `2055` | NetFlow listening port |
| sFlow Port | `6343` | sFlow listening port |
| Web UI Port | `8081` | Web dashboard port |
| Network CIDR | `10.0.0.0/8` | Your network range |
| Network Name | `my-network` | Name for your network |
| Region | `indonesia` | Your region |

## Manual Configuration

### 1. Copy environment file

```bash
cp .env.example .env
```

### 2. Edit configuration

```bash
nano .env
```

### 3. Edit config files

```bash
# Main configuration
nano config/akvorado.yaml

# Flow input configuration
nano config/inlet.yaml

# SNMP and metadata
nano config/outlet.yaml

# Web UI
nano config/console.yaml
```

### 4. Start services

```bash
docker compose up -d
```

## Configuration Files

### .env

Environment variables for Docker Compose:

```env
SERVER_IP=192.168.1.100
SNMP_COMMUNITY=public
SNMP_PORT=161
NETFLOW_PORT=2055
SFLOW_PORT=6343
WEBUI_PORT=8081
NETWORK_CIDR=192.168.1.0/24
NETWORK_NAME=my-network
REGION=indonesia
```

### config/akvorado.yaml

Main configuration including:
- Kafka settings
- ClickHouse connection
- AS names database
- Network definitions

### config/inlet.yaml

Flow input configuration:
- NetFlow ports
- sFlow ports
- Worker threads

### config/outlet.yaml

Metadata and classification:
- SNMP credentials
- Interface classifiers
- Exporter classifiers

### config/console.yaml

Web UI configuration:
- Redis cache
- Saved filters

## Adding AS Names

Add AS names to `config/akvorado.yaml`:

```yaml
clickhouse:
  asns:
    2906: Netflix
    15169: Google
    32934: Meta (Facebook)
    16509: Amazon
    # Add more...
```

## MikroTik Configuration

### Quick Setup

```routeros
# Enable NetFlow
/ip traffic-flow
set enabled=yes

# Add target
/ip traffic-flow target
add dst-address=AKVORADO_IP port=2055 version=9

# Enable SNMP
/snmp
set enabled=yes
```

### Full Guide

See [docs/mikrotik-guide.md](docs/mikrotik-guide.md) for detailed instructions.

## Web Dashboard

Access the dashboard at: `http://YOUR_SERVER_IP:8081`

### Features

- **Real-time** flow visualization
- **Top AS** by traffic
- **Top protocols** by traffic
- **Interface** traffic breakdown
- **Sankey diagrams** for traffic flow
- **Time-series graphs** for trends

## Docker Commands

```bash
# Check status
docker compose ps

# View logs
docker compose logs -f

# Restart services
docker compose restart

# Stop services
docker compose down

# Update images
docker compose pull
docker compose up -d
```

## Troubleshooting

### No flows appearing

1. Check if MikroTik can reach Akvorado server
2. Verify NetFlow target IP and port
3. Check firewall rules
4. View inlet logs: `docker compose logs akvorado-inlet`

### SNMP timeout

1. Verify SNMP community string
2. Check SNMP port (default: 161)
3. Ensure SNMP is enabled on device
4. View outlet logs: `docker compose logs akvorado-outlet`

### Web UI not accessible

1. Check if port is open
2. Verify console is running: `docker compose ps`
3. View console logs: `docker compose logs akvorado-console`

## Directory Structure

```
akvorado-docker/
├── .env.example          # Environment template
├── .gitignore           # Git ignore rules
├── install.sh           # Installation script
├── docker-compose.yml   # Docker Compose config
├── README.md           # This file
├── config/             # Configuration files
│   ├── akvorado.yaml   # Main config
│   ├── inlet.yaml      # Flow input config
│   ├── outlet.yaml     # SNMP/metadata config
│   └── console.yaml    # Web UI config
└── docs/               # Documentation
    └── mikrotik-guide.md
```

## Requirements

- Docker 20.10+
- Docker Compose v2
- Linux server (Debian/Ubuntu/CentOS/Alpine/Arch)
- Minimum 2GB RAM
- Minimum 10GB disk space

## Supported Devices

- MikroTik RouterOS 6.x/7.x
- Cisco IOS/IOS-XE
- Juniper JunOS
- Huawei VRP
- Any device supporting NetFlow/sFlow/IPFIX

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License.

## Credits

- [Akvorado](https://github.com/akvorado/akvorado) - Flow collector
- [ClickHouse](https://clickhouse.com/) - Analytics database
- [Apache Kafka](https://kafka.apache.org/) - Message broker
- [Valkey](https://valkey.io/) - Redis fork

## Support

- [Issues](https://github.com/YOUR_USERNAME/akvorado-docker/issues)
- [Discussions](https://github.com/YOUR_USERNAME/akvorado-docker/discussions)
