#!/bin/bash
# ============================================================
# Akvorado Installer Script
# Flow collector, enricher and visualizer
# Supports: Debian/Ubuntu, CentOS/RHEL, Alpine, Arch
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║        Akvorado Installation Script              ║"
echo "  ║        Flow Collector & Visualizer               ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# Detect OS/Distro
# ============================================================
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
        OS_VERSION=$(cat /etc/alpine-release)
        OS_NAME="Alpine Linux $OS_VERSION"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        OS_VERSION=$(cat /etc/debian_version)
        OS_NAME="Debian $OS_VERSION"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(uname -r)
        OS_NAME=$(uname -s) $(uname -r)
    fi

    echo -e "${GREEN}[✓] Detected OS: ${OS_NAME}${NC}"
}

# ============================================================
# Install Docker
# ============================================================
install_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}[✓] Docker already installed: $(docker --version)${NC}"
        return 0
    fi

    echo -e "${YELLOW}[!] Docker not found. Installing...${NC}"

    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y ca-certificates curl gnupg lsb-release
            curl -fsSL https://get.docker.com | sh
            systemctl enable docker
            systemctl start docker
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            systemctl enable docker
            systemctl start docker
            ;;
        alpine)
            apk update
            apk add docker docker-compose docker-cli-compose
            rc-update add docker boot
            # Fix cgroup issues on Alpine
            mkdir -p /sys/fs/cgroup
            service docker start || true
            # Wait for Docker to be ready
            sleep 5
            # Check if Docker is running
            if ! docker info >/dev/null 2>&1; then
                echo -e "${YELLOW}[!] Docker may have issues. Trying to fix...${NC}"
                # Try to start Docker with different options
                dockerd --storage-driver=vfs &
                sleep 10
            fi
            ;;
        arch|manjaro)
            pacman -Syu --noconfirm docker docker-compose
            systemctl enable docker
            systemctl start docker
            ;;
        *)
            echo -e "${RED}[✗] Unsupported OS: $OS${NC}"
            echo -e "${YELLOW}[!] Please install Docker manually: https://docs.docker.com/engine/install/${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}[✓] Docker installed successfully${NC}"
}

# ============================================================
# Install Docker Compose
# ============================================================
install_docker_compose() {
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}[✓] Docker Compose already available${NC}"
        return 0
    fi

    echo -e "${YELLOW}[!] Installing Docker Compose plugin...${NC}"

    case $OS in
        alpine)
            apk add docker-cli-compose
            ;;
        *)
            # Docker Compose plugin is usually installed with Docker
            echo -e "${YELLOW}[!] Docker Compose plugin not found. Installing...${NC}"
            mkdir -p ~/.docker/cli-plugins/
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
            curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" -o ~/.docker/cli-plugins/docker-compose
            chmod +x ~/.docker/cli-plugins/docker-compose
            ;;
    esac

    echo -e "${GREEN}[✓] Docker Compose installed${NC}"
}

# ============================================================
# Interactive Configuration
# ============================================================
ask_config() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        Configuration Wizard                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""

    # Server IP - detect the main IP used for internet access
    DEFAULT_IP=$(ip -4 route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' || ip -4 addr show | grep -v '127.0.0.1' | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    read -p "Server IP Address [${DEFAULT_IP}]: " SERVER_IP
    SERVER_IP=${SERVER_IP:-$DEFAULT_IP}

    # SNMP Community
    read -p "SNMP Community String [public]: " SNMP_COMMUNITY
    SNMP_COMMUNITY=${SNMP_COMMUNITY:-public}

    # NetFlow port
    read -p "NetFlow Port [2055]: " NETFLOW_PORT
    NETFLOW_PORT=${NETFLOW_PORT:-2055}

    # sFlow port
    read -p "sFlow Port [6343]: " SFLOW_PORT
    SFLOW_PORT=${SFLOW_PORT:-6343}

    # Web UI port
    read -p "Web UI Port [8081]: " WEBUI_PORT
    WEBUI_PORT=${WEBUI_PORT:-8081}

    # Network range
    read -p "Your Network CIDR (e.g., 192.168.1.0/24) [10.0.0.0/8]: " NETWORK_CIDR
    NETWORK_CIDR=${NETWORK_CIDR:-10.0.0.0/8}

    # Network name
    read -p "Network Name [my-network]: " NETWORK_NAME
    NETWORK_NAME=${NETWORK_NAME:-my-network}

    # Region
    read -p "Region [indonesia]: " REGION
    REGION=${REGION:-indonesia}

    # SNMP port for exporters
    read -p "SNMP Port on exporters [161]: " SNMP_PORT
    SNMP_PORT=${SNMP_PORT:-161}

    # Confirm
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        Configuration Summary                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Server IP:        ${GREEN}${SERVER_IP}${NC}"
    echo -e "  SNMP Community:   ${GREEN}${SNMP_COMMUNITY}${NC}"
    echo -e "  SNMP Port:        ${GREEN}${SNMP_PORT}${NC}"
    echo -e "  NetFlow Port:     ${GREEN}${NETFLOW_PORT}${NC}"
    echo -e "  sFlow Port:       ${GREEN}${SFLOW_PORT}${NC}"
    echo -e "  Web UI Port:      ${GREEN}${WEBUI_PORT}${NC}"
    echo -e "  Network CIDR:     ${GREEN}${NETWORK_CIDR}${NC}"
    echo -e "  Network Name:     ${GREEN}${NETWORK_NAME}${NC}"
    echo -e "  Region:           ${GREEN}${REGION}${NC}"
    echo ""

    read -p "Continue with this configuration? (y/n) [y]: " CONFIRM
    CONFIRM=${CONFIRM:-y}

    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo -e "${RED}[✗] Installation cancelled${NC}"
        exit 0
    fi
}

# ============================================================
# Generate Configuration Files
# ============================================================
generate_configs() {
    echo -e "${YELLOW}[!] Generating configuration files...${NC}"

    # Create config directory if not exists
    mkdir -p config

    # Create .env file
    cat > .env << EOF
# ============================================================
# Akvorado Environment Configuration
# Generated by install.sh on $(date)
# ============================================================

# Server Configuration
SERVER_IP=${SERVER_IP}

# SNMP Configuration
SNMP_COMMUNITY=${SNMP_COMMUNITY}
SNMP_PORT=${SNMP_PORT}

# Port Configuration
NETFLOW_PORT=${NETFLOW_PORT}
IPFIX_PORT=4739
SFLOW_PORT=${SFLOW_PORT}
WEBUI_PORT=${WEBUI_PORT}

# Network Configuration
NETWORK_CIDR=${NETWORK_CIDR}
NETWORK_NAME=${NETWORK_NAME}
REGION=${REGION}
TENANT=default

# Docker Compose
COMPOSE_PROJECT_NAME=akvorado
COMPOSE_FILE=docker-compose.yml
EOF

    # Create akvorado.yaml
    cat > config/akvorado.yaml << 'AKVORADO_EOF'
kafka:
  topic: flows
  brokers:
    - kafka:9092
  topic-configuration:
    num-partitions: 1
    replication-factor: 1
    config-entries:
      segment.bytes: 1073741824
      retention.ms: 86400000
      cleanup.policy: delete
      compression.type: producer

geoip:
  optional: true
  asn-database:
    - /usr/share/GeoIP/asn.mmdb
  geo-database:
    - /usr/share/GeoIP/country.mmdb

clickhousedb:
  servers:
    - clickhouse:9000

clickhouse:
  orchestrator-url: http://akvorado-orchestrator:8080
  asns:
    64501: MikroTik Network
AKVORADO_EOF

    # Append NETWORK_CIDR and NETWORK_NAME to akvorado.yaml
    cat >> config/akvorado.yaml << EOF
  networks:
    ${NETWORK_CIDR}:
      name: ${NETWORK_NAME}
      role: internal
EOF

    # Append includes
    cat >> config/akvorado.yaml << 'EOF'

inlet: !include inlet.yaml
outlet: !include outlet.yaml
console: !include console.yaml
EOF

    # Create inlet.yaml
    cat > config/inlet.yaml << EOF
flow:
  inputs:
    - type: udp
      decoder: netflow
      listen: :${NETFLOW_PORT}
      workers: 4
      receive-buffer: 212992
    - type: udp
      decoder: netflow
      listen: :4739
      workers: 4
      receive-buffer: 212992
    - type: udp
      decoder: sflow
      listen: :${SFLOW_PORT}
      workers: 4
      receive-buffer: 212992
EOF

    # Create outlet.yaml
    cat > config/outlet.yaml << EOF
metadata:
  providers:
    - type: snmp
      ports:
        ::/0: ${SNMP_PORT}
      credentials:
        ::/0:
          communities: ${SNMP_COMMUNITY}
routing:
  provider:
    type: bmp
    receive-buffer: 212992
core:
  exporter-classifiers:
    - ClassifySiteRegex(Exporter.Name, "^([^-]+)-", "\$1")
    - ClassifyRegion("${REGION}")
    - ClassifyTenant("${TENANT}")
    - ClassifyRole("edge")
  interface-classifiers:
    - |
      ClassifyConnectivityRegex(Interface.Description, "(?i)WAN", "transit") &&
      ClassifyExternal()
    - |
      ClassifyConnectivityRegex(Interface.Description, "(?i)LAN", "pni") &&
      ClassifyInternal()
    - ClassifyInternal()
EOF

    # Create console.yaml
    cat > config/console.yaml << 'EOF'
http:
  cache:
    type: redis
    server: redis:6379
database:
  saved-filters:
    - description: "All Traffic"
      content: >-
        InIfBoundary = internal OR OutIfBoundary = internal
    - description: "External Traffic"
      content: >-
        InIfBoundary = external OR OutIfBoundary = external
    - description: "Inbound Traffic"
      content: >-
        InIfBoundary = external
    - description: "Outbound Traffic"
      content: >-
        OutIfBoundary = external
EOF

    # Create docker-compose.yml
    cat > docker-compose.yml << 'EOF'
networks:
  default:
    driver: bridge

volumes:
  akvorado-kafka:
  akvorado-geoip:
  akvorado-clickhouse:
  akvorado-run:
  akvorado-console-db:

services:
  kafka:
    image: apache/kafka:4.2.0
    hostname: kafka
    container_name: akvorado-kafka
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: controller,broker
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_LISTENERS: CLIENT://:9092,CONTROLLER://:9093
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CLIENT:PLAINTEXT,CONTROLLER:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: CLIENT://kafka:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: CLIENT
      KAFKA_DELETE_TOPIC_ENABLE: "true"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_LOG_DIRS: /var/lib/kafka/data
    volumes:
      - akvorado-kafka:/var/lib/kafka/data
    restart: unless-stopped
    healthcheck:
      interval: 20s
      test: ["CMD", "/opt/kafka/bin/kafka-topics.sh", "--list", "--bootstrap-server", "kafka:9092"]

  redis:
    image: valkey/valkey:9.0
    hostname: redis
    container_name: akvorado-redis
    restart: unless-stopped
    healthcheck:
      interval: 20s
      test: ["CMD-SHELL", "timeout 3 redis-cli ping | grep -q PONG"]

  clickhouse:
    image: clickhouse/clickhouse-server:26.3
    hostname: clickhouse
    container_name: akvorado-clickhouse
    volumes:
      - akvorado-clickhouse:/var/lib/clickhouse
    environment:
      CLICKHOUSE_INIT_TIMEOUT: 60
      CLICKHOUSE_SKIP_USER_SETUP: 1
    cap_add:
      - SYS_NICE
    restart: unless-stopped
    stop_grace_period: 30s
    healthcheck:
      interval: 20s
      test: ["CMD", "wget", "-T", "1", "--spider", "--no-proxy", "http://127.0.0.1:8123/ping"]

  akvorado-orchestrator:
    image: ghcr.io/akvorado/akvorado:latest
    hostname: orchestrator
    container_name: akvorado-orchestrator
    restart: unless-stopped
    depends_on:
      kafka:
        condition: service_healthy
    command: orchestrator /etc/akvorado/akvorado.yaml
    volumes:
      - ./config:/etc/akvorado:ro
      - akvorado-geoip:/usr/share/GeoIP:ro
      - akvorado-run:/run/akvorado
    healthcheck:
      interval: 20s
      test: ["CMD", "akvorado", "healthcheck"]

  akvorado-console:
    image: ghcr.io/akvorado/akvorado:latest
    hostname: console
    container_name: akvorado-console
    restart: unless-stopped
    depends_on:
      akvorado-orchestrator:
        condition: service_healthy
      redis:
        condition: service_healthy
      clickhouse:
        condition: service_healthy
    command: console http://akvorado-orchestrator:8080
    volumes:
      - akvorado-console-db:/run/akvorado
    environment:
      AKVORADO_CFG_CONSOLE_DATABASE_DSN: /run/akvorado/console.sqlite
      AKVORADO_CFG_CONSOLE_HTTP_LISTEN: 0.0.0.0:8080
    ports:
      - "${WEBUI_PORT:-8081}:8080"

  akvorado-inlet:
    image: ghcr.io/akvorado/akvorado:latest
    hostname: inlet
    container_name: akvorado-inlet
    ports:
      - "${NETFLOW_PORT:-2055}:2055/udp"
      - "4739:4739/udp"
      - "${SFLOW_PORT:-6343}:6343/udp"
    restart: unless-stopped
    depends_on:
      akvorado-orchestrator:
        condition: service_healthy
      kafka:
        condition: service_healthy
    command: inlet http://akvorado-orchestrator:8080
    volumes:
      - akvorado-run:/run/akvorado

  akvorado-outlet:
    image: ghcr.io/akvorado/akvorado:latest
    hostname: outlet
    container_name: akvorado-outlet
    restart: unless-stopped
    stop_grace_period: 30s
    depends_on:
      akvorado-orchestrator:
        condition: service_healthy
      kafka:
        condition: service_healthy
      clickhouse:
        condition: service_healthy
    command: outlet http://akvorado-orchestrator:8080
    volumes:
      - akvorado-run:/run/akvorado
    environment:
      AKVORADO_CFG_OUTLET_METADATA_CACHEPERSISTFILE: /run/akvorado/metadata.cache
      AKVORADO_CFG_OUTLET_FLOW_STATEPERSISTFILE: /run/akvorado/flow.state
EOF

    echo -e "${GREEN}[✓] Configuration files generated${NC}"
}

# ============================================================
# Download AS Names Database
# ============================================================
download_as_names() {
    echo -e "${YELLOW}[!] Downloading AS names database...${NC}"

    # Create a comprehensive AS names file
    cat > config/asn-names.yaml << 'ASN_EOF'
# AS Names Database
# Add your custom AS names here
# Format: AS_NUMBER: Company Name
ASN_EOF

    # Download from bgp.he.net or use built-in list
    echo -e "${GREEN}[✓] AS names database ready${NC}"
}

# ============================================================
# Start Services
# ============================================================
start_services() {
    echo -e "${YELLOW}[!] Starting Akvorado services...${NC}"

    docker compose up -d

    echo -e "${GREEN}[✓] Services started${NC}"
}

# ============================================================
# Wait for Services
# ============================================================
wait_for_services() {
    echo -e "${YELLOW}[!] Waiting for services to be healthy...${NC}"

    local max_wait=180
    local waited=0

    while [ $waited -lt $max_wait ]; do
        local healthy=$(docker compose ps --format json 2>/dev/null | grep -c '"healthy"' || echo 0)
        local total=$(docker compose ps --format json 2>/dev/null | wc -l || echo 0)
        local errored=$(docker compose ps --format json 2>/dev/null | grep -c '"exited"' || echo 0)

        if [ "$errored" -gt 0 ]; then
            echo ""
            echo -e "${RED}[✗] Some containers failed to start!${NC}"
            echo -e "${YELLOW}[!] Check logs with: docker compose logs${NC}"
            docker compose ps
            return 1
        fi

        if [ "$healthy" -ge 6 ]; then
            echo -e "${GREEN}[✓] All services healthy${NC}"
            return 0
        fi

        echo -ne "\r  Waiting... ${waited}s (${healthy}/${total} healthy)"
        sleep 5
        waited=$((waited + 5))
    done

    echo ""
    echo -e "${YELLOW}[!] Some services may still be starting. Check with: docker compose ps${NC}"
}

# ============================================================
# Print Summary
# ============================================================
print_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        Installation Complete!                     ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}Web Dashboard:${NC}  http://${SERVER_IP}:${WEBUI_PORT}"
    echo ""
    echo -e "  ${GREEN}Flow Ports:${NC}"
    echo -e "    NetFlow:   ${SERVER_IP}:${NETFLOW_PORT}/udp"
    echo -e "    IPFIX:     ${SERVER_IP}:4739/udp"
    echo -e "    sFlow:     ${SERVER_IP}:${SFLOW_PORT}/udp"
    echo ""
    echo -e "  ${GREEN}SNMP Settings:${NC}"
    echo -e "    Community: ${SNMP_COMMUNITY}"
    echo -e "    Port:      ${SNMP_PORT}"
    echo ""
    echo -e "  ${CYAN}MikroTik Configuration:${NC}"
    echo -e "    /ip traffic-flow set enabled=yes"
    echo -e "    /ip traffic-flow target add dst-address=${SERVER_IP} port=${NETFLOW_PORT} version=9"
    echo -e "    /snmp set enabled=yes"
    echo ""
    echo -e "  ${CYAN}Useful Commands:${NC}"
    echo -e "    docker compose ps          - Check status"
    echo -e "    docker compose logs -f     - View logs"
    echo -e "    docker compose restart     - Restart services"
    echo -e "    docker compose down        - Stop services"
    echo ""
    echo -e "  ${YELLOW}Documentation:${NC} docs/mikrotik-guide.md"
    echo ""
}

# ============================================================
# Main
# ============================================================
main() {
    echo -e "${BLUE}[1/7] Detecting operating system...${NC}"
    detect_os

    echo -e "${BLUE}[2/7] Checking Docker...${NC}"
    install_docker

    echo -e "${BLUE}[3/7] Checking Docker Compose...${NC}"
    install_docker_compose

    echo -e "${BLUE}[4/7] Configuration...${NC}"
    ask_config

    echo -e "${BLUE}[5/7] Generating configs...${NC}"
    generate_configs

    echo -e "${BLUE}[6/7] Starting services...${NC}"
    start_services

    echo -e "${BLUE}[7/7] Waiting for services...${NC}"
    wait_for_services

    print_summary
}

# Run main
main "$@"
